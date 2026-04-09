import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../models/bible_verse.dart';

/// BibleDatabase manages SQLite databases for Bible translations and Strong's Concordance.
///
/// Database schema expected (bible):
/// CREATE TABLE verses (
///   id INTEGER PRIMARY KEY,
///   book TEXT,
///   book_number INTEGER,
///   chapter INTEGER,
///   verse INTEGER,
///   text TEXT
/// );
///
/// Database schema expected (strongs):
/// CREATE TABLE strongs (
///   number TEXT PRIMARY KEY,
///   original_word TEXT,
///   transliteration TEXT,
///   meaning TEXT,
///   language TEXT  -- 'hebrew' or 'greek'
/// );
class BibleDatabase {
  static BibleDatabase? _instance;
  final Map<String, Database> _translationDbs = {};
  final Map<String, List<String>> _translationsByLanguage = {};
  Database? _strongsHebDb;
  Database? _strongsGrkDb;

  BibleDatabase._();

  static BibleDatabase get instance {
    _instance ??= BibleDatabase._();
    return _instance!;
  }

  Future<void> _ensureBibleSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS verses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book TEXT NOT NULL,
        book_number INTEGER NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER NOT NULL,
        text TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bk_ch ON verses(book, chapter)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bk_ch_v ON verses(book, chapter, verse)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_bknum ON verses(book_number)',
    );
  }

  Future<void> _importJsonBible({
    required Database db,
    required String assetPath,
    required String language,
  }) async {
    final rawText = await rootBundle.loadString(assetPath);
    final text = rawText.replaceFirst('\uFEFF', '');
    final data = jsonDecode(text) as List<dynamic>;
    final books = AppConstants.allBooksForLanguage(language);

    await db.transaction((txn) async {
      await txn.delete('verses');

      var batch = txn.batch();
      var pending = 0;

      Future<void> flush() async {
        if (pending == 0) return;
        await batch.commit(noResult: true);
        batch = txn.batch();
        pending = 0;
      }

      for (var bookIndex = 0; bookIndex < data.length; bookIndex++) {
        final bookData = data[bookIndex] as Map<String, dynamic>;
        final chapters = (bookData['chapters'] as List<dynamic>? ?? const []);
        final bookName = bookIndex < books.length
            ? books[bookIndex]
            : 'Book ${bookIndex + 1}';

        for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
          final verses = chapters[chapterIndex] as List<dynamic>? ?? const [];
          for (var verseIndex = 0; verseIndex < verses.length; verseIndex++) {
            final textValue = verses[verseIndex].toString().trim();
            if (textValue.isEmpty) continue;

            batch.insert('verses', {
              'book': bookName,
              'book_number': bookIndex + 1,
              'chapter': chapterIndex + 1,
              'verse': verseIndex + 1,
              'text': textValue,
            });
            pending++;

            if (pending >= 1000) {
              await flush();
            }
          }
        }
      }

      await flush();
    });
  }

  Future<Database> _openOrCreateJsonDb({
    required String assetPath,
    required String translation,
    required String language,
  }) async {
    final dbsPath = await getDatabasesPath();
    final path = join(dbsPath, '$translation.db');
    final db = await openDatabase(path);
    await _ensureBibleSchema(db);

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM verses'),
    ) ?? 0;

    if (count == 0) {
      await _importJsonBible(db: db, assetPath: assetPath, language: language);
    }

    return db;
  }

  Future<void> _initTranslationDbs() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bibleJsonAssets = manifest.listAssets()
        .where(
          (path) => path.startsWith('bibles_json/') && path.endsWith('.json'),
        )
        .toList()
      ..sort();

    _translationDbs.clear();
    _translationsByLanguage.clear();

    for (final assetPath in bibleJsonAssets) {
      final translation = basenameWithoutExtension(assetPath).toLowerCase();
      final language = AppConstants.languageForTranslation(translation);
      final db = await _openOrCreateJsonDb(
        assetPath: assetPath,
        translation: translation,
        language: language,
      );
      _translationDbs[translation] = db;
      _translationsByLanguage.putIfAbsent(language, () => []).add(translation);
    }
  }

  Future<Database> _openAssetDb(String assetPath, String fileName) async {
    final dbsPath = await getDatabasesPath();
    final path = join(dbsPath, fileName);

    if (!File(path).existsSync()) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
    }

    return openDatabase(path, readOnly: true);
  }

  Future<void> init() async {
    try {
      await _initTranslationDbs();
      _strongsHebDb = await _openAssetDb(
          'assets/strongs/strongs_hebrew.db', 'strongs_hebrew.db');
      _strongsGrkDb = await _openAssetDb(
          'assets/strongs/strongs_greek.db', 'strongs_greek.db');
    } catch (e) {
      debugPrint('BibleDatabase.init failed: $e');
    }
  }

  Database? _getTranslationDb(String translation) {
    return _translationDbs[translation.toLowerCase()];
  }

  List<String> getAvailableTranslations(String language) {
    final translations = _translationsByLanguage[language] ?? const [];
    return List.unmodifiable(
      translations.isNotEmpty
          ? translations
          : [AppConstants.defaultTranslationForLanguage(language)],
    );
  }

  Future<List<BibleVerse>> getChapter({
    required String translation,
    required String book,
    required int chapter,
  }) async {
    final db = _getTranslationDb(translation);
    if (db == null) return [];

    final rows = await db.query(
      'verses',
      where: 'book = ? AND chapter = ?',
      whereArgs: [book, chapter],
      orderBy: 'verse ASC',
    );

    return rows.map((r) => BibleVerse.fromMap(r, translation)).toList();
  }

  Future<BibleVerse?> getVerse({
    required String translation,
    required String book,
    required int chapter,
    required int verse,
  }) async {
    final db = _getTranslationDb(translation);
    if (db == null) return null;

    final rows = await db.query(
      'verses',
      where: 'book = ? AND chapter = ? AND verse = ?',
      whereArgs: [book, chapter, verse],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return BibleVerse.fromMap(rows.first, translation);
  }

  /// Parse a reference like "João 3:16" or "John 3:16" and fetch the verse
  Future<BibleVerse?> getVerseByReference({
    required String translation,
    required String reference,
  }) async {
    try {
      // Parse "Book Chapter:Verse"
      final colonIdx = reference.lastIndexOf(':');
      if (colonIdx == -1) return null;

      final verse = int.tryParse(reference.substring(colonIdx + 1).trim());
      if (verse == null) return null;

      final beforeColon = reference.substring(0, colonIdx).trim();
      final spaceIdx = beforeColon.lastIndexOf(' ');
      if (spaceIdx == -1) return null;

      final chapter = int.tryParse(beforeColon.substring(spaceIdx + 1));
      if (chapter == null) return null;

      final book = beforeColon.substring(0, spaceIdx).trim();

      return getVerse(
        translation: translation,
        book: book,
        chapter: chapter,
        verse: verse,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> getBooks(String translation) async {
    final db = _getTranslationDb(translation);
    if (db == null) return [];

    final rows = await db.rawQuery(
      'SELECT DISTINCT book, book_number FROM verses ORDER BY book_number ASC',
    );
    return rows.map((r) => r['book'].toString()).toList();
  }

  Future<int> getChapterCount({
    required String translation,
    required String book,
  }) async {
    final db = _getTranslationDb(translation);
    if (db == null) return 0;

    final rows = await db.rawQuery(
      'SELECT MAX(chapter) as max_chapter FROM verses WHERE book = ?',
      [book],
    );
    return (rows.first['max_chapter'] as num?)?.toInt() ?? 0;
  }

  Future<StrongsEntry?> lookupStrongs({
    required String number,
    required String language, // 'hebrew' or 'greek'
  }) async {
    final db = language == 'hebrew' ? _strongsHebDb : _strongsGrkDb;
    if (db == null) return null;

    final rows = await db.query(
      'strongs',
      where: 'number = ?',
      whereArgs: [number],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return StrongsEntry.fromMap({...rows.first, 'language': language});
  }

  Future<List<BibleVerse>> searchVerses({
    required String translation,
    required String query,
    int limit = 30,
  }) async {
    final db = _getTranslationDb(translation);
    if (db == null) return [];

    final rows = await db.query(
      'verses',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      limit: limit,
      orderBy: 'book_number ASC, chapter ASC, verse ASC',
    );

    return rows.map((r) => BibleVerse.fromMap(r, translation)).toList();
  }
}
