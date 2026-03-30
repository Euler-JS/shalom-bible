import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import '../models/bible_verse.dart';
import '../models/sermon_model.dart';

class OpenAIService {
  static OpenAIService? _instance;
  final _storage = const FlutterSecureStorage();
  late final Dio _dio;

  OpenAIService._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.openAiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  static OpenAIService get instance {
    _instance ??= OpenAIService._();
    return _instance!;
  }

  Future<String> _getApiKey() async {
    final key = await _storage.read(key: AppConstants.openAiKeyStorage);
    if (key == null || key.isEmpty) {
      throw Exception('OpenAI API key not configured.');
    }
    return key;
  }

  Future<void> saveApiKey(String key) async {
    await _storage.write(key: AppConstants.openAiKeyStorage, value: key);
  }

  Future<bool> hasApiKey() async {
    final key = await _storage.read(key: AppConstants.openAiKeyStorage);
    return key != null && key.isNotEmpty;
  }

  String _chooseModel(bool isPremium) =>
      isPremium ? AppConstants.modelPremium : AppConstants.modelFree;

  Future<String> _chat({
    required List<Map<String, String>> messages,
    required bool isPremium,
    double temperature = 0.7,
  }) async {
    final apiKey = await _getApiKey();
    final res = await _dio.post(
      '/chat/completions',
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      data: {
        'model': _chooseModel(isPremium),
        'messages': messages,
        'temperature': temperature,
        'response_format': {'type': 'json_object'},
      },
    );
    final content =
        (res.data['choices'] as List)[0]['message']['content'] as String;
    return content;
  }

  // --- Scenario Search ---
  Future<List<ScenarioPassage>> searchByScenario({
    required String scenario,
    required String language,
    required bool isPremium,
  }) async {
    final langInstruction =
        language == 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';

    final messages = [
      {
        'role': 'system',
        'content': '''You are a biblical scholar assistant. The user will describe a life situation or emotional state.
Your task is to find 3 to 5 Bible passages that are most relevant to that situation.
For each passage, provide:
1. The Bible reference (book, chapter, verse) in the format "Book Chapter:Verse" e.g. "João 3:16" or "John 3:16"
2. A brief explanation (2-3 sentences) of why this passage applies to the user\'s situation
$langInstruction
Respond ONLY with valid JSON in this exact structure:
{
  "passages": [
    {
      "reference": "João 3:16",
      "explanation": "..."
    }
  ]
}''',
      },
      {'role': 'user', 'content': scenario},
    ];

    final raw = await _chat(messages: messages, isPremium: isPremium);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final passages = (json['passages'] as List<dynamic>? ?? [])
        .map((p) => ScenarioPassage(
              reference: p['reference']?.toString() ?? '',
              explanation: p['explanation']?.toString() ?? '',
            ))
        .toList();
    return passages;
  }

  // --- Historical Context ---
  Future<String> getHistoricalContext({
    required String book,
    required int chapter,
    required String language,
    required bool isPremium,
  }) async {
    final langInstruction =
        language == 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';

    final messages = [
      {
        'role': 'system',
        'content': '''You are a biblical scholar. Provide a concise historical and cultural context.
$langInstruction
Respond ONLY with valid JSON in this structure:
{
  "timePeriod": "...",
  "author": "...",
  "audience": "...",
  "geographicContext": "...",
  "purpose": "...",
  "summary": "..."
}''',
      },
      {
        'role': 'user',
        'content':
            'Provide historical context for $book chapter $chapter.',
      },
    ];

    final raw = await _chat(messages: messages, isPremium: isPremium);
    return raw;
  }

  // --- Verse Explanation ---
  Future<String> explainVerse({
    required String reference,
    required String verseText,
    required String language,
    required bool isPremium,
  }) async {
    final langInstruction =
        language == 'pt' ? 'Responde em Português.' : 'Respond in English.';

    final messages = [
      {
        'role': 'system',
        'content': '''És um explicador bíblico acessível e honesto.
O teu objectivo é ajudar qualquer pessoa — independente do nível educacional ou tradição religiosa — a compreender o que a Bíblia diz.
Regras:
- Linguagem simples e directa, sem jargão religioso
- Explica o que o texto diz de facto, com contexto histórico e cultural quando relevante
- Se há interpretações diferentes entre denominações, menciona isso com honestidade
- Nunca inventes ou especules — se não há certeza, diz isso
- Máximo de 4-5 frases
$langInstruction
Responde APENAS com JSON válido:
{
  "explanation": "explicação simples aqui",
  "context": "contexto histórico/cultural breve (opcional, pode ser null)"
}''',
      },
      {
        'role': 'user',
        'content': 'Explica $reference: "$verseText"',
      },
    ];

    return _chat(messages: messages, isPremium: isPremium, temperature: 0.5);
  }

  // --- Bible Chat ---
  Future<String> chatBibleQuestion({
    required String question,
    required String book,
    required int chapter,
    required List<Map<String, String>> history,
    required String language,
    required bool isPremium,
  }) async {
    final langInstruction =
        language == 'pt' ? 'Responde em Português.' : 'Respond in English.';

    final systemMessage = {
      'role': 'system',
      'content': '''És um tutor bíblico pessoal — acessível, honesto e respeitoso.
O utilizador está actualmente a ler $book capítulo $chapter.
O teu papel é facilitar o conhecimento da Bíblia para qualquer pessoa, de forma simples e verdadeira.
Regras:
- Linguagem clara, como um amigo culto que conhece a Bíblia — não como um pregador
- Baseia as respostas no texto bíblico e no contexto histórico real
- Quando há diferentes interpretações entre tradições (católica, protestante, etc.), apresenta-as com honestidade em vez de impor uma visão
- Nunca inventes factos — se não sabes, diz claramente
- Respostas concisas (3-6 frases) mas completas — se o utilizador quiser mais, ele pergunta
$langInstruction
Responde APENAS com JSON válido:
{
  "answer": "a tua resposta aqui",
  "relatedVerses": ["Referência 1", "Referência 2"]
}
O campo relatedVerses pode ser uma lista vazia [] se não houver versículos relevantes.''',
    };

    final allMessages = [
      systemMessage,
      ...history,
      {'role': 'user', 'content': question},
    ];

    return _chat(messages: allMessages, isPremium: isPremium, temperature: 0.6);
  }

  // --- Verse Word Study ---
  /// Returns Hebrew/Greek roots for key words in a verse.
  Future<List<WordStudyEntry>> getVerseWordStudy({
    required String reference,
    required String verseText,
    required String language,
    required bool isPremium,
  }) async {
    final langInstruction =
        language == 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';
    final isOT = _isOldTestament(reference);
    final originalLang = isOT ? 'Hebrew' : 'Greek';

    final messages = [
      {
        'role': 'system',
        'content': '''You are a biblical language scholar specializing in Hebrew and Greek.
Analyze the key theological words in the given Bible verse and explain their original $originalLang roots.
Select 3 to 5 of the most meaningful words (nouns, verbs, and adjectives — skip conjunctions, articles, prepositions).
$langInstruction
Respond ONLY with valid JSON:
{
  "words": [
    {
      "translatedWord": "the translated word from the verse",
      "originalWord": "original $originalLang word",
      "transliteration": "phonetic pronunciation",
      "strongsNumber": "H123 or G456",
      "meaning": "concise meaning in 1-2 sentences",
      "insight": "theological or cultural insight in 1-2 sentences"
    }
  ]
}''',
      },
      {
        'role': 'user',
        'content': 'Analyze the key words in $reference: "$verseText"',
      },
    ];

    final raw = await _chat(messages: messages, isPremium: isPremium);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final list = (json['words'] as List<dynamic>? ?? [])
        .map((w) => WordStudyEntry.fromJson(w as Map<String, dynamic>))
        .toList();
    return list;
  }

  bool _isOldTestament(String reference) {
    const otBooks = [
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
    return otBooks.any((b) => reference.startsWith(b));
  }

  // --- Sermon Generator ---
  Future<SermonContent> generateSermonOutline({
    required String input,
    required String language,
    required bool isPremium,
  }) async {
    final langInstruction =
        language == 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';

    final messages = [
      {
        'role': 'system',
        'content': '''You are an expert preacher and biblical theologian. Create a complete sermon outline.
$langInstruction
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
}''',
      },
      {
        'role': 'user',
        'content': 'Create a complete sermon outline based on: $input',
      },
    ];

    final raw = await _chat(
      messages: messages,
      isPremium: isPremium,
      temperature: 0.8,
    );

    final json = jsonDecode(raw) as Map<String, dynamic>;
    return SermonContent.fromJson(json);
  }

  Future<String> getSermonTitle(Map<String, dynamic> json) async {
    return json['title']?.toString() ?? '';
  }

  Future<String> getSermonBasePassage(Map<String, dynamic> json) async {
    return json['basePassage']?.toString() ?? '';
  }
}
