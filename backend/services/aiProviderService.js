const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com/v1beta';
const OPENAI_BASE_URL = 'https://api.openai.com/v1';

const GEMINI_MODEL_FREE = process.env.GEMINI_MODEL_FREE || 'gemini-2.5-flash';
const GEMINI_MODEL_PREMIUM =
  process.env.GEMINI_MODEL_PREMIUM || 'gemini-2.5-pro';
const OPENAI_MODEL_FREE =
  process.env.OPENAI_MODEL_FREE || 'gpt-4.1-mini';
const OPENAI_MODEL_PREMIUM =
  process.env.OPENAI_MODEL_PREMIUM || 'gpt-4.1';

const normalizeModelText = (text) => {
  const trimmed = String(text || '').trim();
  if (!trimmed.startsWith('```')) {
    return trimmed;
  }

  const lines = trimmed.split('\n');
  if (lines.length < 3) {
    return trimmed;
  }

  return lines.slice(1, -1).join('\n').trim();
};

const chooseGeminiModel = (isPremium) =>
  isPremium ? GEMINI_MODEL_PREMIUM : GEMINI_MODEL_FREE;

const chooseOpenAiModel = (isPremium) =>
  isPremium ? OPENAI_MODEL_PREMIUM : OPENAI_MODEL_FREE;

const parseErrorResponse = async (response) => {
  try {
    const data = await response.json();
    return data.error?.message || data.message || JSON.stringify(data);
  } catch (_) {
    return response.statusText || 'Unknown provider error.';
  }
};

const chatWithGemini = async ({ messages, isPremium, temperature }) => {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('Gemini API key is not configured on the server.');
  }

  const systemInstruction = messages
    .filter((message) => message.role === 'system')
    .map((message) => message.content || '')
    .filter(Boolean)
    .join('\n\n');

  const contents = messages
    .filter((message) => message.role !== 'system')
    .map((message) => ({
      role: message.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: message.content || '' }],
    }));

  const response = await fetch(
    `${GEMINI_BASE_URL}/models/${chooseGeminiModel(
      isPremium
    )}:generateContent?key=${encodeURIComponent(apiKey)}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        ...(systemInstruction
          ? {
              systemInstruction: {
                parts: [{ text: systemInstruction }],
              },
            }
          : {}),
        contents,
        generationConfig: {
          temperature,
          responseMimeType: 'application/json',
        },
      }),
    }
  );

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }

  const data = await response.json();
  const parts = data.candidates?.[0]?.content?.parts || [];
  const text = parts.map((part) => part.text || '').join('').trim();
  if (!text) {
    throw new Error('Gemini returned empty content.');
  }

  return normalizeModelText(text);
};

const chatWithOpenAi = async ({ messages, isPremium, temperature }) => {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) {
    throw new Error('OpenAI API key is not configured on the server.');
  }

  const response = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: chooseOpenAiModel(isPremium),
      messages,
      temperature,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    throw new Error(await parseErrorResponse(response));
  }

  const data = await response.json();
  const text = data.choices?.[0]?.message?.content;
  if (!text) {
    throw new Error('OpenAI returned empty content.');
  }

  return normalizeModelText(text);
};

const chatWithFallback = async ({ messages, isPremium, temperature = 0.7 }) => {
  const hasGemini = Boolean(process.env.GEMINI_API_KEY);
  const hasOpenAi = Boolean(process.env.OPENAI_API_KEY);

  if (!hasGemini && !hasOpenAi) {
    throw new Error('No AI provider is configured on the server.');
  }

  if (hasGemini) {
    try {
      return await chatWithGemini({ messages, isPremium, temperature });
    } catch (error) {
      if (!hasOpenAi) {
        throw error;
      }
      console.error('Gemini failed, falling back to OpenAI:', error.message);
    }
  }

  return chatWithOpenAi({ messages, isPremium, temperature });
};

module.exports = {
  chatWithFallback,
};
