#!/usr/bin/env python3
"""
Script to create SQLite databases for Bible translations.

Usage:
  python3 create_bible_db.py

This script creates:
  - arc.db  (Almeida Revista e Corrigida - Portuguese)
  - kjv.db  (King James Version - English)
  - strongs_hebrew.db
  - strongs_greek.db

Place the resulting .db files in:
  flutter_app/assets/bible/arc.db
  flutter_app/assets/bible/kjv.db
  flutter_app/assets/strongs/strongs_hebrew.db
  flutter_app/assets/strongs/strongs_greek.db

Data sources (public domain):
  - ARC: can be obtained from openbible.info or similar public domain sources
  - KJV: public domain, available from many sources
  - Strong's: public domain concordance data

Database schema:
  CREATE TABLE verses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    book TEXT NOT NULL,
    book_number INTEGER NOT NULL,
    chapter INTEGER NOT NULL,
    verse INTEGER NOT NULL,
    text TEXT NOT NULL
  );
  CREATE INDEX idx_book_chapter ON verses(book, chapter);
  CREATE INDEX idx_book_number ON verses(book_number);

Strong's schema:
  CREATE TABLE strongs (
    number TEXT PRIMARY KEY,
    original_word TEXT,
    transliteration TEXT,
    meaning TEXT,
    language TEXT
  );
"""

import sqlite3
import os
import json

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'flutter_app', 'assets')


def create_bible_db(filename: str, translation: str):
    """Create an empty Bible database with the correct schema."""
    path = os.path.join(OUTPUT_DIR, 'bible', filename)
    os.makedirs(os.path.dirname(path), exist_ok=True)

    conn = sqlite3.connect(path)
    c = conn.cursor()

    c.execute('''
        CREATE TABLE IF NOT EXISTS verses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book TEXT NOT NULL,
            book_number INTEGER NOT NULL,
            chapter INTEGER NOT NULL,
            verse INTEGER NOT NULL,
            text TEXT NOT NULL
        )
    ''')

    c.execute('CREATE INDEX IF NOT EXISTS idx_book_chapter ON verses(book, chapter)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_book_number ON verses(book_number)')
    c.execute('CREATE INDEX IF NOT EXISTS idx_full ON verses(book, chapter, verse)')

    conn.commit()
    conn.close()
    print(f'Created empty {filename} at {path}')
    print(f'  => Populate it with {translation} Bible data')


def create_strongs_db(filename: str, language: str):
    """Create an empty Strong's Concordance database."""
    path = os.path.join(OUTPUT_DIR, 'strongs', filename)
    os.makedirs(os.path.dirname(path), exist_ok=True)

    conn = sqlite3.connect(path)
    c = conn.cursor()

    c.execute('''
        CREATE TABLE IF NOT EXISTS strongs (
            number TEXT PRIMARY KEY,
            original_word TEXT,
            transliteration TEXT,
            meaning TEXT,
            language TEXT
        )
    ''')

    conn.commit()
    conn.close()
    print(f'Created empty {filename} at {path}')


def import_from_json(db_path: str, json_path: str):
    """
    Import Bible data from a JSON file.

    Expected JSON format:
    [
      {
        "book": "Gênesis",
        "book_number": 1,
        "chapter": 1,
        "verse": 1,
        "text": "No princípio criou Deus os céus e a terra."
      },
      ...
    ]
    """
    if not os.path.exists(json_path):
        print(f'JSON file not found: {json_path}')
        return

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    c.executemany(
        'INSERT OR REPLACE INTO verses (book, book_number, chapter, verse, text) VALUES (?, ?, ?, ?, ?)',
        [(v['book'], v['book_number'], v['chapter'], v['verse'], v['text']) for v in data]
    )

    conn.commit()
    count = c.execute('SELECT COUNT(*) FROM verses').fetchone()[0]
    conn.close()
    print(f'Imported {count} verses into {db_path}')


if __name__ == '__main__':
    print('=== Shalom Bible — Database Creator ===\n')
    create_bible_db('arc.db', 'ARC (Almeida Revista e Corrigida)')
    create_bible_db('kjv.db', 'KJV (King James Version)')
    create_strongs_db('strongs_hebrew.db', 'hebrew')
    create_strongs_db('strongs_greek.db', 'greek')

    print('\n=== Next Steps ===')
    print('1. Obtain ARC Bible data (public domain) and import using import_from_json()')
    print('2. Obtain KJV Bible data (public domain) and import using import_from_json()')
    print('3. Obtain Strong\'s Concordance data and import into strongs_*.db files')
    print('\nRecommended data sources:')
    print('  - https://github.com/scrollmapper/bible_databases (open source Bible DBs)')
    print('  - https://openscriptures.org (Strong\'s data)')
    print('  - Biblia.com API (for ARC text)')
