class BibleVerse {
  final int id;
  final String book;
  final int bookNumber;
  final int chapter;
  final int verse;
  final String text;
  final String translation;

  const BibleVerse({
    required this.id,
    required this.book,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.translation,
  });

  String get reference => '$book $chapter:$verse';

  factory BibleVerse.fromMap(Map<String, dynamic> map, String translation) {
    return BibleVerse(
      id: (map['id'] as num?)?.toInt() ?? 0,
      book: map['book']?.toString() ?? '',
      bookNumber: (map['book_number'] as num?)?.toInt() ?? 0,
      chapter: (map['chapter'] as num?)?.toInt() ?? 0,
      verse: (map['verse'] as num?)?.toInt() ?? 0,
      text: map['text']?.toString() ?? '',
      translation: translation,
    );
  }
}

class ScenarioPassage {
  final String reference;
  final String explanation;
  final BibleVerse? verseData;

  const ScenarioPassage({
    required this.reference,
    required this.explanation,
    this.verseData,
  });
}

class StrongsEntry {
  final String number;
  final String originalWord;
  final String transliteration;
  final String meaning;
  final String language; // 'hebrew' or 'greek'

  const StrongsEntry({
    required this.number,
    required this.originalWord,
    required this.transliteration,
    required this.meaning,
    required this.language,
  });

  factory StrongsEntry.fromMap(Map<String, dynamic> map) {
    return StrongsEntry(
      number: map['number']?.toString() ?? '',
      originalWord: map['original_word']?.toString() ?? '',
      transliteration: map['transliteration']?.toString() ?? '',
      meaning: map['meaning']?.toString() ?? '',
      language: map['language']?.toString() ?? 'greek',
    );
  }
}
