import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
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
  Database? _arcDb;
  Database? _kjvDb;
  Database? _strongsHebDb;
  Database? _strongsGrkDb;

  BibleDatabase._();

  static BibleDatabase get instance {
    _instance ??= BibleDatabase._();
    return _instance!;
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
      _arcDb = await _openAssetDb('assets/bible/arc.db', 'arc.db');
      _kjvDb = await _openAssetDb('assets/bible/kjv.db', 'kjv.db');
      _strongsHebDb = await _openAssetDb(
          'assets/strongs/strongs_hebrew.db', 'strongs_hebrew.db');
      _strongsGrkDb = await _openAssetDb(
          'assets/strongs/strongs_greek.db', 'strongs_greek.db');
    } catch (e) {
      // Databases may not exist yet during development — handled gracefully
    }
  }

  Database? _getTranslationDb(String translation) {
    if (translation == 'ARA' || translation == 'ARC') return _arcDb;
    if (translation == 'KJV') return _kjvDb;
    return null;
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
