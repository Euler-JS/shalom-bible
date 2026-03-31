const express = require('express');
const { optionalProtect } = require('../middleware/authMiddleware');
const { consumeAiUsage } = require('../services/aiUsageService');
const { chatWithFallback } = require('../services/aiProviderService');

const router = express.Router();

router.use(optionalProtect);

const buildErrorMessage = (language) =>
  language === 'pt'
    ? 'Erro ao processar pedido de IA.'
    : 'Error processing AI request.';

const isOldTestament = (reference) => {
  const books = [
    'Gênesis', 'Genesis', 'Êxodo', 'Exodus', 'Levítico', 'Leviticus',
    'Números', 'Numbers', 'Deuteronômio', 'Deuteronomy', 'Josué', 'Joshua',
    'Juízes', 'Judges', 'Rute', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Reis', '1 Kings', '2 Reis', '2 Kings', '1 Crônicas', '1 Chronicles',
    '2 Crônicas', '2 Chronicles', 'Esdras', 'Ezra', 'Neemias', 'Nehemiah',
    'Ester', 'Esther', 'Jó', 'Job', 'Salmos', 'Psalms', 'Provérbios',
    'Proverbs', 'Eclesiastes', 'Ecclesiastes', 'Cantares', 'Song of Solomon',
    'Isaías', 'Isaiah', 'Jeremias', 'Jeremiah', 'Lamentações', 'Lamentations',
    'Ezequiel', 'Ezekiel', 'Daniel', 'Oseias', 'Hosea', 'Joel', 'Amós',
    'Amos', 'Obadias', 'Obadiah', 'Jonas', 'Jonah', 'Miquéias', 'Micah',
    'Naum', 'Nahum', 'Habacuque', 'Habakkuk', 'Sofonias', 'Zephaniah',
    'Ageu', 'Haggai', 'Zacarias', 'Zechariah', 'Malaquias', 'Malachi',
  ];
  return books.some((book) => reference.startsWith(book));
};

const runAiFeature = async ({
  req,
  res,
  feature,
  language,
  isPremium,
  messages,
  temperature,
  transform = (raw) => JSON.parse(raw),
}) => {
  try {
    const usage = await consumeAiUsage({ req, feature, language });
    if (!usage.allowed) {
      return res
        .status(usage.status || 403)
        .json({ message: usage.message, code: 'AI_LIMIT_REACHED' });
    }

    const raw = await chatWithFallback({
      messages,
      isPremium,
      temperature,
    });

    return res.json(transform(raw));
  } catch (error) {
    console.error(`AI feature ${feature} failed:`, error.message);
    return res.status(500).json({
      message: buildErrorMessage(language),
      error: error.message,
    });
  }
};

router.post('/scenario-search', async (req, res) => {
  const { scenario, language = 'pt' } = req.body;
  const isPremium = req.user?.plan === 'premium';
  const langInstruction =
    language === 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';

  if (!scenario) {
    return res.status(400).json({ message: 'scenario is required.' });
  }

  return runAiFeature({
    req,
    res,
    feature: 'scenarioSearch',
    language,
    isPremium,
    temperature: 0.7,
    messages: [
      {
        role: 'system',
        content: `You are a biblical scholar assistant. The user will describe a life situation or emotional state.
Your task is to find 3 to 5 Bible passages that are most relevant to that situation.
For each passage, provide:
1. The Bible reference (book, chapter, verse) in the format "Book Chapter:Verse" e.g. "João 3:16" or "John 3:16"
2. A brief explanation (2-3 sentences) of why this passage applies to the user's situation
${langInstruction}
Respond ONLY with valid JSON in this exact structure:
{
  "passages": [
    {
      "reference": "João 3:16",
      "explanation": "..."
    }
  ]
}`,
      },
      { role: 'user', content: scenario },
    ],
  });
});

router.post('/historical-context', async (req, res) => {
  const { book, chapter, language = 'pt' } = req.body;
  const isPremium = req.user?.plan === 'premium';
  const langInstruction =
    language === 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';

  if (!book || !chapter) {
    return res.status(400).json({ message: 'book and chapter are required.' });
  }

  return runAiFeature({
    req,
    res,
    feature: 'historicalContext',
    language,
    isPremium,
    temperature: 0.7,
    messages: [
      {
        role: 'system',
        content: `You are a biblical scholar. Provide a concise historical and cultural context.
${langInstruction}
Respond ONLY with valid JSON in this structure:
{
  "timePeriod": "...",
  "author": "...",
  "audience": "...",
  "geographicContext": "...",
  "purpose": "...",
  "summary": "..."
}`,
      },
      {
        role: 'user',
        content: `Provide historical context for ${book} chapter ${chapter}.`,
      },
    ],
  });
});

router.post('/explain-verse', async (req, res) => {
  const { reference, verseText, language = 'pt' } = req.body;
  const isPremium = req.user?.plan === 'premium';
  const langInstruction =
    language === 'pt' ? 'Responde em Português.' : 'Respond in English.';

  if (!reference || !verseText) {
    return res
      .status(400)
      .json({ message: 'reference and verseText are required.' });
  }

  return runAiFeature({
    req,
    res,
    feature: 'verseExplanation',
    language,
    isPremium,
    temperature: 0.5,
    messages: [
      {
        role: 'system',
        content: `És um explicador bíblico acessível e honesto.
O teu objectivo é ajudar qualquer pessoa — independente do nível educacional ou tradição religiosa — a compreender o que a Bíblia diz.
Regras:
- Linguagem simples e directa, sem jargão religioso
- Explica o que o texto diz de facto, com contexto histórico e cultural quando relevante
- Se há interpretações diferentes entre denominações, menciona isso com honestidade
- Nunca inventes ou especules — se não há certeza, diz isso
- Máximo de 4-5 frases
${langInstruction}
Responde APENAS com JSON válido:
{
  "explanation": "explicação simples aqui",
  "context": "contexto histórico/cultural breve (opcional, pode ser null)"
}`,
      },
      {
        role: 'user',
        content: `Explica ${reference}: "${verseText}"`,
      },
    ],
  });
});

router.post('/bible-chat', async (req, res) => {
  const {
    question,
    book,
    chapter,
    history = [],
    language = 'pt',
  } = req.body;
  const isPremium = req.user?.plan === 'premium';
  const langInstruction =
    language === 'pt' ? 'Responde em Português.' : 'Respond in English.';

  if (!question || !book || !chapter) {
    return res
      .status(400)
      .json({ message: 'question, book and chapter are required.' });
  }

  return runAiFeature({
    req,
    res,
    feature: 'bibleChat',
    language,
    isPremium,
    temperature: 0.6,
    messages: [
      {
        role: 'system',
        content: `És um tutor bíblico pessoal — acessível, honesto e respeitoso.
O utilizador está actualmente a ler ${book} capítulo ${chapter}.
O teu papel é facilitar o conhecimento da Bíblia para qualquer pessoa, de forma simples e verdadeira.
Regras:
- Linguagem clara, como um amigo culto que conhece a Bíblia — não como um pregador
- Baseia as respostas no texto bíblico e no contexto histórico real
- Quando há diferentes interpretações entre tradições (católica, protestante, etc.), apresenta-as com honestidade em vez de impor uma visão
- Nunca inventes factos — se não sabes, diz claramente
- Respostas concisas (3-6 frases) mas completas — se o utilizador quiser mais, ele pergunta
${langInstruction}
Responde APENAS com JSON válido:
{
  "answer": "a tua resposta aqui",
  "relatedVerses": ["Referência 1", "Referência 2"]
}
O campo relatedVerses pode ser uma lista vazia [] se não houver versículos relevantes.`,
      },
      ...history,
      { role: 'user', content: question },
    ],
  });
});

router.post('/word-study', async (req, res) => {
  const { reference, verseText, language = 'pt' } = req.body;
  const isPremium = req.user?.plan === 'premium';
  const langInstruction =
    language === 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';
  const originalLang = isOldTestament(reference || '') ? 'Hebrew' : 'Greek';

  if (!reference || !verseText) {
    return res
      .status(400)
      .json({ message: 'reference and verseText are required.' });
  }

  return runAiFeature({
    req,
    res,
    feature: 'wordStudy',
    language,
    isPremium,
    temperature: 0.7,
    messages: [
      {
        role: 'system',
        content: `You are a biblical language scholar specializing in Hebrew and Greek.
Analyze the key theological words in the given Bible verse and explain their original ${originalLang} roots.
Select 3 to 5 of the most meaningful words (nouns, verbs, and adjectives — skip conjunctions, articles, prepositions).
${langInstruction}
Respond ONLY with valid JSON:
{
  "words": [
    {
      "translatedWord": "the translated word from the verse",
      "originalWord": "original ${originalLang} word",
      "transliteration": "phonetic pronunciation",
      "strongsNumber": "H123 or G456",
      "meaning": "concise meaning in 1-2 sentences",
      "insight": "theological or cultural insight in 1-2 sentences"
    }
  ]
}`,
      },
      {
        role: 'user',
        content: `Analyze the key words in ${reference}: "${verseText}"`,
      },
    ],
  });
});

router.post('/sermon-outline', async (req, res) => {
  const { input, language = 'pt' } = req.body;
  const isPremium = req.user?.plan === 'premium';
  const langInstruction =
    language === 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';

  if (!input) {
    return res.status(400).json({ message: 'input is required.' });
  }

  return runAiFeature({
    req,
    res,
    feature: 'sermonGenerator',
    language,
    isPremium,
    temperature: 0.8,
    messages: [
      {
        role: 'system',
        content: `You are an expert preacher and biblical theologian. Create a complete sermon outline.
${langInstruction}
Respond ONLY with valid JSON in this exact structure:
{
  "title": "Sermon Title",
  "basePassage": "Book Chapter:Verse",
  "introduction": "Engaging hook paragraph...",
  "points": [
    {
      "title": "Point title",
      "development": "Development paragraph...",
      "supportingVerses": ["Reference 1", "Reference 2"]
    },
    {
      "title": "Point 2 title",
      "development": "Development paragraph...",
      "supportingVerses": ["Reference 1", "Reference 2"]
    },
    {
      "title": "Point 3 title",
      "development": "Development paragraph...",
      "supportingVerses": ["Reference 1", "Reference 2"]
    }
  ],
  "illustrations": [
    "Story or illustration 1...",
    "Story or illustration 2...",
    "Story or illustration 3..."
  ],
  "conclusion": "Call to action paragraph...",
  "closingPrayer": "Suggested prayer text..."
}`,
      },
      {
        role: 'user',
        content: `Create a complete sermon outline based on: ${input}`,
      },
    ],
  });
});

module.exports = router;
