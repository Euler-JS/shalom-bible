import 'dart:convert';

import 'api_client.dart';
import '../models/bible_verse.dart';
import '../models/sermon_model.dart';

class OpenAIService {
  static OpenAIService? _instance;

  OpenAIService._();

  static OpenAIService get instance {
    _instance ??= OpenAIService._();
    return _instance!;
  }

  Future<bool> hasApiKey() async {
    return true;
  }

  Future<List<ScenarioPassage>> searchByScenario({
    required String scenario,
    required String language,
    required bool isPremium,
  }) async {
    final res = await ApiClient.instance.dio.post(
      '/ai/scenario-search',
      data: {'scenario': scenario, 'language': language},
    );

    final json = res.data as Map<String, dynamic>;
    return (json['passages'] as List<dynamic>? ?? [])
        .map(
          (p) => ScenarioPassage(
            reference: p['reference']?.toString() ?? '',
            explanation: p['explanation']?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<String> getHistoricalContext({
    required String book,
    required int chapter,
    required String language,
    required bool isPremium,
  }) async {
    final res = await ApiClient.instance.dio.post(
      '/ai/historical-context',
      data: {'book': book, 'chapter': chapter, 'language': language},
    );
    return jsonEncode(res.data);
  }

  Future<String> explainVerse({
    required String reference,
    required String verseText,
    required String language,
    required bool isPremium,
  }) async {
    final res = await ApiClient.instance.dio.post(
      '/ai/explain-verse',
      data: {
        'reference': reference,
        'verseText': verseText,
        'language': language,
      },
    );
    return jsonEncode(res.data);
  }

  Future<String> chatBibleQuestion({
    required String question,
    required String book,
    required int chapter,
    required List<Map<String, String>> history,
    required String language,
    required bool isPremium,
  }) async {
    final res = await ApiClient.instance.dio.post(
      '/ai/bible-chat',
      data: {
        'question': question,
        'book': book,
        'chapter': chapter,
        'history': history,
        'language': language,
      },
    );
    return jsonEncode(res.data);
  }

  Future<List<WordStudyEntry>> getVerseWordStudy({
    required String reference,
    required String verseText,
    required String language,
    required bool isPremium,
  }) async {
    final res = await ApiClient.instance.dio.post(
      '/ai/word-study',
      data: {
        'reference': reference,
        'verseText': verseText,
        'language': language,
      },
    );

    final json = res.data as Map<String, dynamic>;
    return (json['words'] as List<dynamic>? ?? [])
        .map((w) => WordStudyEntry.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  Future<SermonContent> generateSermonOutline({
    required String input,
    required String language,
    required bool isPremium,
  }) async {
    final res = await ApiClient.instance.dio.post(
      '/ai/sermon-outline',
      data: {'input': input, 'language': language},
    );

    return SermonContent.fromJson(res.data as Map<String, dynamic>);
  }

  Future<String> getSermonTitle(Map<String, dynamic> json) async {
    return json['title']?.toString() ?? '';
  }

  Future<String> getSermonBasePassage(Map<String, dynamic> json) async {
    return json['basePassage']?.toString() ?? '';
  }
}
