const AiUsage = require('../models/AiUsage');

const FEATURE_RULES = {
  scenarioSearch: {
    freeLimit: 3,
    periodType: 'week',
    labelPt: 'busca por cenário',
    labelEn: 'scenario search',
  },
  sermonGenerator: {
    freeLimit: 2,
    periodType: 'month',
    labelPt: 'geração de esboço',
    labelEn: 'sermon outline generation',
  },
  verseExplanation: {
    freeLimit: 20,
    periodType: 'day',
    labelPt: 'explicação de versículos',
    labelEn: 'verse explanation',
  },
  wordStudy: {
    freeLimit: 10,
    periodType: 'day',
    labelPt: 'estudo de palavras',
    labelEn: 'word study',
  },
  historicalContext: {
    freeLimit: 15,
    periodType: 'day',
    labelPt: 'contexto histórico',
    labelEn: 'historical context',
  },
  bibleChat: {
    freeLimit: 30,
    periodType: 'day',
    labelPt: 'tutor bíblico',
    labelEn: 'Bible tutor',
  },
};

const startOfPeriod = (now, periodType) => {
  const date = new Date(now);
  date.setHours(0, 0, 0, 0);

  if (periodType === 'week') {
    const day = date.getDay();
    const diff = day === 0 ? 6 : day - 1;
    date.setDate(date.getDate() - diff);
    return date;
  }

  if (periodType === 'month') {
    date.setDate(1);
  }

  return date;
};

const sameInstant = (a, b) => a.getTime() === b.getTime();

const buildLimitMessage = (rule, language) => {
  const isPT = language === 'pt';
  const periodLabel =
    rule.periodType === 'day'
      ? isPT
        ? 'diário'
        : 'daily'
      : rule.periodType === 'week'
      ? isPT
        ? 'semanal'
        : 'weekly'
      : isPT
      ? 'mensal'
      : 'monthly';

  if (isPT) {
    return `Limite ${periodLabel} atingido para ${rule.labelPt} (${rule.freeLimit} pedidos). Actualiza para Premium.`;
  }

  return `${periodLabel} request limit reached for ${rule.labelEn} (${rule.freeLimit} requests). Upgrade to Premium.`;
};

const getSubject = (req) => {
  if (req.user) {
    return {
      subjectType: 'user',
      subjectId: req.user._id.toString(),
      isPremium: req.user.plan === 'premium',
    };
  }

  const deviceId = req.headers['x-device-id'];
  if (!deviceId || typeof deviceId !== 'string') {
    return null;
  }

  return {
    subjectType: 'device',
    subjectId: deviceId,
    isPremium: false,
  };
};

const consumeAiUsage = async ({ req, feature, language }) => {
  const rule = FEATURE_RULES[feature];
  if (!rule) {
    throw new Error(`Unknown AI feature: ${feature}`);
  }

  const subject = getSubject(req);
  if (!subject) {
    return {
      allowed: false,
      status: 400,
      message:
        language === 'pt'
          ? 'Identificador do dispositivo ausente.'
          : 'Missing device identifier.',
    };
  }

  if (subject.isPremium) {
    return { allowed: true };
  }

  const now = new Date();
  const periodStart = startOfPeriod(now, rule.periodType);

  let usage = await AiUsage.findOne({
    subjectType: subject.subjectType,
    subjectId: subject.subjectId,
    feature,
  });

  if (!usage) {
    usage = await AiUsage.create({
      subjectType: subject.subjectType,
      subjectId: subject.subjectId,
      feature,
      periodType: rule.periodType,
      periodStart,
      count: 0,
    });
  } else if (
    usage.periodType !== rule.periodType ||
    !sameInstant(new Date(usage.periodStart), periodStart)
  ) {
    usage.periodType = rule.periodType;
    usage.periodStart = periodStart;
    usage.count = 0;
  }

  if (usage.count >= rule.freeLimit) {
    return {
      allowed: false,
      status: 403,
      message: buildLimitMessage(rule, language),
    };
  }

  usage.count += 1;
  await usage.save();
  return { allowed: true };
};

module.exports = {
  FEATURE_RULES,
  consumeAiUsage,
};
