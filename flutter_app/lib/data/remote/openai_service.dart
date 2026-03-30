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

  // --- Word Meaning ---
  Future<String> getWordMeaning({
    required String word,
    required String strongsNumber,
    required String originalWord,
    required String verseReference,
    required String language,
    required bool isPremium,
  }) async {
    final langInstruction =
        language == 'pt' ? 'Respond in Portuguese.' : 'Respond in English.';

    final messages = [
      {
        'role': 'system',
        'content': '''You are a biblical language scholar specializing in Hebrew and Greek.
$langInstruction
Respond ONLY with valid JSON:
{
  "contextualMeaning": "...",
  "nuances": "...",
  "usageInBible": "..."
}''',
      },
      {
        'role': 'user',
        'content':
            'Explain the meaning of the word "$originalWord" (Strong\'s $strongsNumber) in $verseReference. The translated word is "$word".',
      },
    ];

    final raw = await _chat(messages: messages, isPremium: isPremium);
    return raw;
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
