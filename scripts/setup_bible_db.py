#!/usr/bin/env python3
"""
Shalom Bible — Bible Database Setup Script
==========================================
Downloads KJV and ARC (Portuguese) Bible data from scrollmapper/bible_databases
and creates SQLite databases for the Flutter app.

Usage:
    python3 scripts/setup_bible_db.py

Requirements:
    pip install requests
"""

import os
import sqlite3
import json
import zipfile
import io
import sys
import urllib.request
import urllib.error

# ─────────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FLUTTER_ASSETS = os.path.join(SCRIPT_DIR, '..', 'flutter_app', 'assets')
BIBLE_DIR = os.path.join(FLUTTER_ASSETS, 'bible')
STRONGS_DIR = os.path.join(FLUTTER_ASSETS, 'strongs')

os.makedirs(BIBLE_DIR, exist_ok=True)
os.makedirs(STRONGS_DIR, exist_ok=True)

# ─────────────────────────────────────────────────
# Download helpers
# ─────────────────────────────────────────────────
def download_bytes(url: str, label: str) -> bytes:
    print(f"  A descarregar {label}...")
    req = urllib.request.Request(url, headers={'User-Agent': 'ShalomBible/1.0'})
    with urllib.request.urlopen(req, timeout=120) as resp:
        total = int(resp.headers.get('Content-Length') or 0)
        data = b''
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            data += chunk
            if total:
                pct = int(len(data) * 100 / total)
                print(f"\r  {pct}% ({len(data) // 1024} KB)", end='', flush=True)
    print(f"\r  Concluído ({len(data) // 1024} KB)        ")
    return data


def download_json(url: str, label: str) -> 'dict | list':
    data = download_bytes(url, label)
    # Handle UTF-8 BOM
    text = data.decode('utf-8-sig')
    return json.loads(text)


# ─────────────────────────────────────────────────
# SQLite schema
# ─────────────────────────────────────────────────
def create_bible_db(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS verses (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            book         TEXT    NOT NULL,
            book_number  INTEGER NOT NULL,
            chapter      INTEGER NOT NULL,
            verse        INTEGER NOT NULL,
            text         TEXT    NOT NULL
        )
    ''')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_bk_ch ON verses(book, chapter)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_bk_ch_v ON verses(book, chapter, verse)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_bknum ON verses(book_number)')
    conn.commit()
    return conn


# ─────────────────────────────────────────────────
# Book name maps (book_id → Portuguese / English name)
# ─────────────────────────────────────────────────
BOOKS_PT = {
    "GEN": ("Gênesis", 1), "EXO": ("Êxodo", 2), "LEV": ("Levítico", 3),
    "NUM": ("Números", 4), "DEU": ("Deuteronômio", 5), "JOS": ("Josué", 6),
    "JDG": ("Juízes", 7), "RUT": ("Rute", 8), "1SA": ("1 Samuel", 9),
    "2SA": ("2 Samuel", 10), "1KI": ("1 Reis", 11), "2KI": ("2 Reis", 12),
    "1CH": ("1 Crônicas", 13), "2CH": ("2 Crônicas", 14), "EZR": ("Esdras", 15),
    "NEH": ("Neemias", 16), "EST": ("Ester", 17), "JOB": ("Jó", 18),
    "PSA": ("Salmos", 19), "PRO": ("Provérbios", 20), "ECC": ("Eclesiastes", 21),
    "SNG": ("Cantares", 22), "ISA": ("Isaías", 23), "JER": ("Jeremias", 24),
    "LAM": ("Lamentações", 25), "EZK": ("Ezequiel", 26), "DAN": ("Daniel", 27),
    "HOS": ("Oséias", 28), "JOL": ("Joel", 29), "AMO": ("Amós", 30),
    "OBA": ("Obadias", 31), "JON": ("Jonas", 32), "MIC": ("Miquéias", 33),
    "NAM": ("Naum", 34), "HAB": ("Habacuque", 35), "ZEP": ("Sofonias", 36),
    "HAG": ("Ageu", 37), "ZEC": ("Zacarias", 38), "MAL": ("Malaquias", 39),
    "MAT": ("Mateus", 40), "MRK": ("Marcos", 41), "LUK": ("Lucas", 42),
    "JHN": ("João", 43), "ACT": ("Atos", 44), "ROM": ("Romanos", 45),
    "1CO": ("1 Coríntios", 46), "2CO": ("2 Coríntios", 47), "GAL": ("Gálatas", 48),
    "EPH": ("Efésios", 49), "PHP": ("Filipenses", 50), "COL": ("Colossenses", 51),
    "1TH": ("1 Tessalonicenses", 52), "2TH": ("2 Tessalonicenses", 53),
    "1TI": ("1 Timóteo", 54), "2TI": ("2 Timóteo", 55), "TIT": ("Tito", 56),
    "PHM": ("Filemon", 57), "HEB": ("Hebreus", 58), "JAS": ("Tiago", 59),
    "1PE": ("1 Pedro", 60), "2PE": ("2 Pedro", 61), "1JN": ("1 João", 62),
    "2JN": ("2 João", 63), "3JN": ("3 João", 64), "JUD": ("Judas", 65),
    "REV": ("Apocalipse", 66),
}

BOOKS_EN = {
    "GEN": ("Genesis", 1), "EXO": ("Exodus", 2), "LEV": ("Leviticus", 3),
    "NUM": ("Numbers", 4), "DEU": ("Deuteronomy", 5), "JOS": ("Joshua", 6),
    "JDG": ("Judges", 7), "RUT": ("Ruth", 8), "1SA": ("1 Samuel", 9),
    "2SA": ("2 Samuel", 10), "1KI": ("1 Kings", 11), "2KI": ("2 Kings", 12),
    "1CH": ("1 Chronicles", 13), "2CH": ("2 Chronicles", 14), "EZR": ("Ezra", 15),
    "NEH": ("Nehemiah", 16), "EST": ("Esther", 17), "JOB": ("Job", 18),
    "PSA": ("Psalms", 19), "PRO": ("Proverbs", 20), "ECC": ("Ecclesiastes", 21),
    "SNG": ("Song of Solomon", 22), "ISA": ("Isaiah", 23), "JER": ("Jeremiah", 24),
    "LAM": ("Lamentations", 25), "EZK": ("Ezekiel", 26), "DAN": ("Daniel", 27),
    "HOS": ("Hosea", 28), "JOL": ("Joel", 29), "AMO": ("Amos", 30),
    "OBA": ("Obadiah", 31), "JON": ("Jonah", 32), "MIC": ("Micah", 33),
    "NAM": ("Nahum", 34), "HAB": ("Habakkuk", 35), "ZEP": ("Zephaniah", 36),
    "HAG": ("Haggai", 37), "ZEC": ("Zechariah", 38), "MAL": ("Malachi", 39),
    "MAT": ("Matthew", 40), "MRK": ("Mark", 41), "LUK": ("Luke", 42),
    "JHN": ("John", 43), "ACT": ("Acts", 44), "ROM": ("Romans", 45),
    "1CO": ("1 Corinthians", 46), "2CO": ("2 Corinthians", 47), "GAL": ("Galatians", 48),
    "EPH": ("Ephesians", 49), "PHP": ("Philippians", 50), "COL": ("Colossians", 51),
    "1TH": ("1 Thessalonians", 52), "2TH": ("2 Thessalonians", 53),
    "1TI": ("1 Timothy", 54), "2TI": ("2 Timothy", 55), "TIT": ("Titus", 56),
    "PHM": ("Philemon", 57), "HEB": ("Hebrews", 58), "JAS": ("James", 59),
    "1PE": ("1 Peter", 60), "2PE": ("2 Peter", 61), "1JN": ("1 John", 62),
    "2JN": ("2 John", 63), "3JN": ("3 John", 64), "JUD": ("Jude", 65),
    "REV": ("Revelation", 66),
}

# Alternative book ID mappings used by some sources
BOOK_ID_ALT = {
    "SOS": "SNG", "EZE": "EZK", "JOE": "JOL", "NAH": "NAM",
    "JAS": "JAS", "PHLM": "PHM", "PHIL": "PHP",
    "1KGS": "1KI", "2KGS": "2KI", "1CHR": "1CH", "2CHR": "2CH",
    "1COR": "1CO", "2COR": "2CO", "1TIM": "1TI", "2TIM": "2TI",
    "1THS": "1TH", "2THS": "2TH", "1PET": "1PE", "2PET": "2PE",
    "1JOH": "1JN", "2JOH": "2JN", "3JOH": "3JN",
}


def normalize_book_id(raw: str) -> str:
    raw = raw.upper().strip()
    return BOOK_ID_ALT.get(raw, raw)


# ─────────────────────────────────────────────────
# Parse scrollmapper JSON format
# scrollmapper JSON: array of objects with keys:
#   book_id, book_name, chapter, verse, text
# OR nested: {"verses": [...]}
# ─────────────────────────────────────────────────
def parse_scrollmapper_json(data) -> list[dict]:
    if isinstance(data, dict):
        data = data.get('verses', data.get('bible', data.get('data', [])))
    if not isinstance(data, list):
        return []
    return data


def insert_verses(conn: sqlite3.Connection, verses_raw: list, book_map: dict):
    rows = []
    skipped = 0
    for v in verses_raw:
        # Accept both 'book_id' and 'book' keys
        raw_id = str(v.get('book_id') or v.get('book') or '').upper().strip()
        book_id = normalize_book_id(raw_id)

        if book_id not in book_map:
            skipped += 1
            continue

        book_name, book_number = book_map[book_id]
        chapter = int(v.get('chapter') or 0)
        verse = int(v.get('verse') or 0)
        text = str(v.get('text') or '').strip()

        if chapter and verse and text:
            rows.append((book_name, book_number, chapter, verse, text))

    conn.executemany(
        'INSERT INTO verses (book, book_number, chapter, verse, text) VALUES (?,?,?,?,?)',
        rows,
    )
    conn.commit()
    if skipped:
        print(f"    (ignorados {skipped} versículos com book_id desconhecido)")
    return len(rows)


# ─────────────────────────────────────────────────
# KJV — download from scrollmapper GitHub (JSON release)
# ─────────────────────────────────────────────────
# KJV from scrollmapper/bible_databases (formats/json)
# Format: {"translation": "...", "books": [{"name": "Genesis", "chapters": [{"chapter": 1, "verses": [{"verse": 1, "text": "..."}]}]}]}
KJV_JSON_URL = (
    "https://raw.githubusercontent.com/scrollmapper/"
    "bible_databases/master/formats/json/KJV.json"
)

# Portuguese Almeida (thiagobodruk/biblia)
ARC_JSON_URL = (
    "https://raw.githubusercontent.com/thiagobodruk/"
    "biblia/master/json/aa.json"
)

# Fallback: Portuguese Almeida from scrollmapper
ARC_FALLBACK_URL = (
    "https://raw.githubusercontent.com/scrollmapper/"
    "bible_databases/master/formats/json/PorNVA.json"
)


def setup_kjv():
    out = os.path.join(BIBLE_DIR, 'kjv.db')
    if os.path.exists(out):
        size = os.path.getsize(out)
        if size > 100_000:
            print(f"\n[KJV] Já existe ({size // 1024} KB). A saltar.")
            return
        os.remove(out)

    print("\n═══ KJV (King James Version) ═══")

    # scrollmapper format: {"books": [{"name": "Genesis", "chapters": [{"chapter": 1, "verses": [{"verse": 1, "text": "..."}]}]}]}
    try:
        data = download_json(KJV_JSON_URL, "KJV.json")
        conn = create_bible_db(out)
        count = _parse_scrollmapper_books_format(conn, data, BOOKS_EN)
        conn.close()
        if count > 20000:
            print(f"  ✓ KJV criado: {count} versículos → {out}")
            return
        os.remove(out)
    except Exception as e:
        print(f"  ✗ Fonte 1 falhou: {e}")

    _setup_kjv_fallback(out)


def _setup_kjv_fallback(out: str):
    """KJV fallback using jadenzaleski/BibleAPI format."""
    print("  Tentando fonte alternativa para KJV...")
    try:
        data = download_json(KJV_FALLBACK2_URL, "kjv-fallback.json")
        conn = create_bible_db(out)
        rows = []

        # Try flat list format: [{"book": "Genesis", "chapter": 1, "verse": 1, "text": "..."}]
        if isinstance(data, list):
            for v in data:
                bname_raw = str(v.get('book') or v.get('book_name') or '')
                book_entry = None
                for bid, (bname, bnum) in BOOKS_EN.items():
                    if bname.lower() == bname_raw.lower():
                        book_entry = (bname, bnum)
                        break
                if not book_entry:
                    continue
                bname, bnum = book_entry
                ch = int(v.get('chapter') or 0)
                vs = int(v.get('verse') or 0)
                text = str(v.get('text') or '').strip()
                if ch and vs and text:
                    rows.append((bname, bnum, ch, vs, text))

        if rows:
            conn.executemany(
                'INSERT INTO verses (book, book_number, chapter, verse, text) VALUES (?,?,?,?,?)',
                rows,
            )
            conn.commit()
            conn.close()
            print(f"  ✓ KJV criado (fallback): {len(rows)} versículos")
            return

        conn.close()
        os.remove(out)
    except Exception as e2:
        print(f"  ✗ Fallback KJV também falhou: {e2}")

    # Last resort: create a minimal sample
    _create_sample_kjv(out)


def _create_sample_kjv(out: str):
    print("  Criando base de dados de amostra para KJV...")
    conn = create_bible_db(out)
    sample = [
        ("Genesis", 1, 1, 1, "In the beginning God created the heaven and the earth."),
        ("Genesis", 1, 1, 2, "And the earth was without form, and void; and darkness was upon the face of the deep."),
        ("John", 43, 3, 16, "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."),
        ("Psalms", 19, 23, 1, "The LORD is my shepherd; I shall not want."),
        ("Romans", 45, 8, 28, "And we know that all things work together for good to them that love God."),
    ]
    conn.executemany(
        'INSERT INTO verses (book, book_number, chapter, verse, text) VALUES (?,?,?,?,?)',
        sample,
    )
    conn.commit()
    conn.close()
    print("  ⚠ Base de dados de amostra KJV criada.")


def setup_arc():
    out = os.path.join(BIBLE_DIR, 'arc.db')
    if os.path.exists(out):
        size = os.path.getsize(out)
        if size > 100_000:
            print(f"\n[ARC] Já existe ({size // 1024} KB). A saltar.")
            return
        os.remove(out)

    print("\n═══ ARC (Almeida Revista e Corrigida) ═══")

    try:
        data = download_json(ARC_JSON_URL, "aa.json (Almeida)")
        conn = create_bible_db(out)
        count = _parse_thiago_format(conn, data)
        conn.close()
        if count > 20000:
            print(f"  ✓ ARC criado: {count} versículos → {out}")
            return
        os.remove(out)
    except Exception as e:
        print(f"  ✗ Fonte falhou: {e}")

    _setup_arc_fallback(out)


def _parse_thiago_format(conn: sqlite3.Connection, data: list) -> int:
    """
    Format from thiagobodruk/biblia:
    [
      {
        "abbrev": "gn",
        "chapters": [
          ["No princípio criou Deus..."],  <- chapter 1, verse 1
          ...
        ]
      },
      ...
    ]
    """
    ABBREV_MAP = {
        "gn": "GEN", "ex": "EXO", "lv": "LEV", "nm": "NUM", "dt": "DEU",
        "js": "JOS", "jz": "JDG", "rt": "RUT", "1sm": "1SA", "2sm": "2SA",
        "1rs": "1KI", "2rs": "2KI", "1cr": "1CH", "2cr": "2CH", "ed": "EZR",
        "ne": "NEH", "et": "EST", "jó": "JOB", "jo": "JOB", "sl": "PSA",
        "pv": "PRO", "ec": "ECC", "ct": "SNG", "is": "ISA", "jr": "JER",
        "lm": "LAM", "ez": "EZK", "dn": "DAN", "os": "HOS", "jl": "JOL",
        "am": "AMO", "ob": "OBA", "jn": "JON", "mq": "MIC", "na": "NAM",
        "hc": "HAB", "sf": "ZEP", "ag": "HAG", "zc": "ZEC", "ml": "MAL",
        "mt": "MAT", "mc": "MRK", "lc": "LUK", "jo": "JHN", "at": "ACT",
        "rm": "ROM", "1co": "1CO", "2co": "2CO", "gl": "GAL", "ef": "EPH",
        "fp": "PHP", "cl": "COL", "1ts": "1TH", "2ts": "2TH", "1tm": "1TI",
        "2tm": "2TI", "tt": "TIT", "fm": "PHM", "hb": "HEB", "tg": "JAS",
        "1pe": "1PE", "2pe": "2PE", "1jo": "1JN", "2jo": "2JN", "3jo": "3JN",
        "jd": "JUD", "ap": "REV",
    }

    rows = []
    for book_data in data:
        abbrev = str(book_data.get('abbrev') or '').lower().strip()
        book_id = ABBREV_MAP.get(abbrev)
        if not book_id:
            # Try to find by name
            name = str(book_data.get('name') or '').strip()
            for bid, (bname, _) in BOOKS_PT.items():
                if bname.lower() == name.lower():
                    book_id = bid
                    break
        if not book_id or book_id not in BOOKS_PT:
            continue

        book_name, book_number = BOOKS_PT[book_id]
        chapters = book_data.get('chapters') or []
        for ch_idx, chapter_verses in enumerate(chapters):
            chapter = ch_idx + 1
            if isinstance(chapter_verses, list):
                for v_idx, text in enumerate(chapter_verses):
                    verse = v_idx + 1
                    text = str(text).strip()
                    if text:
                        rows.append((book_name, book_number, chapter, verse, text))

    conn.executemany(
        'INSERT INTO verses (book, book_number, chapter, verse, text) VALUES (?,?,?,?,?)',
        rows,
    )
    conn.commit()
    return len(rows)


def _parse_scrollmapper_books_format(
    conn: sqlite3.Connection, data: dict, book_map: dict
) -> int:
    """
    Parse scrollmapper formats/json structure:
    {"books": [{"name": "Genesis", "chapters": [{"chapter": 1, "verses": [{"verse": 1, "text": "..."}]}]}]}
    """
    books = data.get('books') or []
    rows = []
    for book_data in books:
        name = str(book_data.get('name') or '').strip()
        # Find matching book by English name
        book_entry = None
        for bid, (bname, bnum) in book_map.items():
            if bname.lower() == name.lower():
                book_entry = (bname, bnum)
                break
        if not book_entry:
            continue
        bname, bnum = book_entry
        for ch_data in (book_data.get('chapters') or []):
            chapter = int(ch_data.get('chapter') or 0)
            for v_data in (ch_data.get('verses') or []):
                verse = int(v_data.get('verse') or 0)
                text = str(v_data.get('text') or '').strip()
                if chapter and verse and text:
                    rows.append((bname, bnum, chapter, verse, text))

    conn.executemany(
        'INSERT INTO verses (book, book_number, chapter, verse, text) VALUES (?,?,?,?,?)',
        rows,
    )
    conn.commit()
    return len(rows)


def _parse_thiago_format_en(conn: sqlite3.Connection, data: list) -> int:
    """
    Parse thiagobodruk/biblia English KJV format.
    Same structure as PT but with English abbreviations.
    """
    ABBREV_MAP_EN = {
        "gn": "GEN", "gen": "GEN", "ex": "EXO", "exo": "EXO", "lv": "LEV",
        "lev": "LEV", "nm": "NUM", "num": "NUM", "dt": "DEU", "deu": "DEU",
        "js": "JOS", "jos": "JOS", "jdg": "JDG", "jz": "JDG", "ru": "RUT",
        "rut": "RUT", "1sm": "1SA", "1sa": "1SA", "2sm": "2SA", "2sa": "2SA",
        "1ki": "1KI", "1rs": "1KI", "2ki": "2KI", "2rs": "2KI",
        "1ch": "1CH", "1cr": "1CH", "2ch": "2CH", "2cr": "2CH",
        "ezr": "EZR", "ed": "EZR", "ne": "NEH", "neh": "NEH",
        "est": "EST", "et": "EST", "job": "JOB", "jo": "JOB",
        "ps": "PSA", "psa": "PSA", "sl": "PSA", "pr": "PRO", "pro": "PRO",
        "ec": "ECC", "ecc": "ECC", "ss": "SNG", "sng": "SNG", "ct": "SNG",
        "is": "ISA", "isa": "ISA", "jr": "JER", "jer": "JER",
        "la": "LAM", "lam": "LAM", "ez": "EZK", "ezk": "EZK", "eze": "EZK",
        "dn": "DAN", "dan": "DAN", "ho": "HOS", "hos": "HOS",
        "jl": "JOL", "joe": "JOL", "am": "AMO", "amo": "AMO",
        "ob": "OBA", "oba": "OBA", "jnh": "JON", "jn": "JON", "jon": "JON",
        "mi": "MIC", "mic": "MIC", "na": "NAM", "nah": "NAM",
        "hab": "HAB", "hc": "HAB", "zep": "ZEP", "sf": "ZEP",
        "hag": "HAG", "ag": "HAG", "zec": "ZEC", "zc": "ZEC",
        "mal": "MAL", "ml": "MAL",
        "mt": "MAT", "mat": "MAT", "mk": "MRK", "mrk": "MRK", "mc": "MRK",
        "lk": "LUK", "luk": "LUK", "lc": "LUK", "jn": "JHN", "jhn": "JHN",
        "ac": "ACT", "act": "ACT", "at": "ACT",
        "ro": "ROM", "rom": "ROM", "rm": "ROM",
        "1co": "1CO", "2co": "2CO", "gal": "GAL", "gl": "GAL",
        "eph": "EPH", "ef": "EPH", "php": "PHP", "fp": "PHP",
        "col": "COL", "cl": "COL", "1th": "1TH", "1ts": "1TH",
        "2th": "2TH", "2ts": "2TH", "1ti": "1TI", "1tm": "1TI",
        "2ti": "2TI", "2tm": "2TI", "tit": "TIT", "tt": "TIT",
        "phm": "PHM", "fm": "PHM", "heb": "HEB", "hb": "HEB",
        "jas": "JAS", "tg": "JAS", "1pe": "1PE", "2pe": "2PE",
        "1jn": "1JN", "1jo": "1JN", "2jn": "2JN", "2jo": "2JN",
        "3jn": "3JN", "3jo": "3JN", "jud": "JUD", "jd": "JUD",
        "rev": "REV", "ap": "REV",
    }

    rows = []
    for book_data in data:
        abbrev = str(book_data.get('abbrev') or '').lower().strip()
        book_id = ABBREV_MAP_EN.get(abbrev)
        if not book_id:
            name = str(book_data.get('name') or '').strip()
            for bid, (bname, _) in BOOKS_EN.items():
                if bname.lower() == name.lower():
                    book_id = bid
                    break
        if not book_id or book_id not in BOOKS_EN:
            continue

        book_name, book_number = BOOKS_EN[book_id]
        chapters = book_data.get('chapters') or []
        for ch_idx, chapter_verses in enumerate(chapters):
            chapter = ch_idx + 1
            if isinstance(chapter_verses, list):
                for v_idx, text in enumerate(chapter_verses):
                    verse = v_idx + 1
                    text = str(text).strip()
                    if text:
                        rows.append((book_name, book_number, chapter, verse, text))

    conn.executemany(
        'INSERT INTO verses (book, book_number, chapter, verse, text) VALUES (?,?,?,?,?)',
        rows,
    )
    conn.commit()
    return len(rows)


def _setup_arc_fallback(out: str):
    """Use another open source Portuguese Bible."""
    print("  Tentando fonte alternativa (jag/bible)...")
    url = (
        "https://raw.githubusercontent.com/robertoentringer/"
        "bible/master/download/pt/almeida-revised-updated-arc.json"
    )
    try:
        data = download_json(url, "arc-fallback.json")
        conn = create_bible_db(out)
        verses_raw = parse_scrollmapper_json(data)
        count = insert_verses(conn, verses_raw, BOOKS_PT)
        conn.close()
        if count > 1000:
            print(f"  ✓ ARC criado (fallback): {count} versículos")
        else:
            print("  ✗ Dados insuficientes no fallback.")
            os.remove(out)
            _create_sample_arc(out)
    except Exception as e:
        print(f"  ✗ Fallback falhou: {e}")
        _create_sample_arc(out)


def _create_sample_arc(out: str):
    """Create a minimal sample database so the app doesn't crash."""
    print("  Criando base de dados de amostra para ARC (apenas Gênesis 1)...")
    conn = create_bible_db(out)
    sample = [
        ("Gênesis", 1, 1, 1, "No princípio criou Deus os céus e a terra."),
        ("Gênesis", 1, 1, 2, "A terra era sem forma e vazia; e havia trevas sobre a face do abismo; e o Espírito de Deus se movia sobre a face das águas."),
        ("Gênesis", 1, 1, 3, "E disse Deus: haja luz; e houve luz."),
        ("João", 43, 3, 16, "Porque Deus amou o mundo de tal maneira que deu o seu Filho unigênito, para que todo aquele que nele crê não pereça, mas tenha a vida eterna."),
        ("Salmos", 19, 23, 1, "O Senhor é o meu pastor; nada me faltará."),
    ]
    conn.executemany(
        'INSERT INTO verses (book, book_number, chapter, verse, text) VALUES (?,?,?,?,?)',
        sample,
    )
    conn.commit()
    conn.close()
    print("  ⚠ Base de dados de amostra criada. Recomenda-se obter dados completos.")


# ─────────────────────────────────────────────────
# Strong's Concordance (minimal offline data)
# ─────────────────────────────────────────────────
# openscriptures/strongs — JS files with JSON data embedded after "var strongsX = "
STRONGS_GREEK_JS_URL = (
    "https://raw.githubusercontent.com/openscriptures/"
    "strongs/master/greek/strongs-greek-dictionary.js"
)
STRONGS_HEBREW_JS_URL = (
    "https://raw.githubusercontent.com/openscriptures/"
    "strongs/master/hebrew/strongs-hebrew-dictionary.js"
)


def create_strongs_db(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.execute('''
        CREATE TABLE IF NOT EXISTS strongs (
            number          TEXT PRIMARY KEY,
            original_word   TEXT,
            transliteration TEXT,
            meaning         TEXT,
            language        TEXT
        )
    ''')
    conn.commit()
    return conn


def _parse_strongs_js(text: str, language: str) -> list:
    """
    Parse openscriptures strongs JS file.
    Format: var strongsGreekDictionary = {"G1": {...}, ...};
    or:     var strongsHebrewDictionary = {"H1": {...}, ...};
    """
    import re
    # Find the JSON object — everything after the first '= ' and before last ';'
    match = re.search(r'=\s*(\{.*\})\s*;?\s*$', text, re.DOTALL)
    if not match:
        # Try module.exports format
        match = re.search(r'=\s*(\{.*\})', text, re.DOTALL)
    if not match:
        return []

    data = json.loads(match.group(1))
    rows = []
    for number, entry in data.items():
        if not isinstance(entry, dict):
            continue
        original = entry.get('lemma') or entry.get('unicode') or ''
        translit = entry.get('xlit') or entry.get('translit') or ''
        meaning = entry.get('strongs_def') or entry.get('kjv_def') or ''
        if isinstance(meaning, dict):
            meaning = str(meaning)
        rows.append((str(number), str(original), str(translit), str(meaning)[:1000], language))
    return rows


def setup_strongs(language: str):
    filename = f'strongs_{language}.db'
    out = os.path.join(STRONGS_DIR, filename)

    if os.path.exists(out) and os.path.getsize(out) > 50_000:
        print(f"\n[Strong's {language}] Já existe. A saltar.")
        return

    lang_label = 'Grego' if language == 'greek' else 'Hebraico'
    print(f"\n═══ Strong's {lang_label} ═══")

    js_url = STRONGS_GREEK_JS_URL if language == 'greek' else STRONGS_HEBREW_JS_URL

    try:
        raw = download_bytes(js_url, f'strongs-{language}-dictionary.js')
        text = raw.decode('utf-8-sig')
        rows = _parse_strongs_js(text, language)
        if rows:
            conn = create_strongs_db(out)
            conn.executemany('INSERT OR REPLACE INTO strongs VALUES (?,?,?,?,?)', rows)
            conn.commit()
            conn.close()
            print(f"  ✓ Strong's {lang_label}: {len(rows)} entradas → {out}")
            return
    except Exception as e:
        print(f"  ✗ {e}")

    conn = create_strongs_db(out)
    conn.close()
    print(f"  ⚠ Strong's {lang_label}: base de dados vazia criada.")


# ─────────────────────────────────────────────────
# Update pubspec.yaml to enable assets
# ─────────────────────────────────────────────────
def update_pubspec():
    pubspec = os.path.join(SCRIPT_DIR, '..', 'flutter_app', 'pubspec.yaml')
    if not os.path.exists(pubspec):
        return

    with open(pubspec, 'r', encoding='utf-8') as f:
        content = f.read()

    if 'assets/bible/' in content and '# assets' not in content:
        return  # already enabled

    new_assets = '''  assets:
    - assets/bible/
    - assets/strongs/'''

    # Replace commented-out assets section
    import re
    content = re.sub(
        r'  # assets:.*?# Add Strong.*?setup\)',
        new_assets,
        content,
        flags=re.DOTALL,
    )

    # If not found, add before the fonts section or at end of flutter:
    if '- assets/bible/' not in content:
        content = content.replace(
            'flutter:\n  uses-material-design: true',
            f'flutter:\n  uses-material-design: true\n\n{new_assets}',
        )

    with open(pubspec, 'w', encoding='utf-8') as f:
        f.write(content)

    print("\n  ✓ pubspec.yaml actualizado com os caminhos de assets.")


# ─────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────
def main():
    print("╔══════════════════════════════════════════╗")
    print("║  Shalom Bible — Database Setup           ║")
    print("╚══════════════════════════════════════════╝")

    setup_kjv()
    setup_arc()
    setup_strongs('greek')
    setup_strongs('hebrew')
    update_pubspec()

    print("\n╔══════════════════════════════════════════╗")
    print("║  Verificação final                       ║")
    print("╚══════════════════════════════════════════╝")

    files = [
        (os.path.join(BIBLE_DIR, 'kjv.db'), 'KJV'),
        (os.path.join(BIBLE_DIR, 'arc.db'), 'ARC'),
        (os.path.join(STRONGS_DIR, 'strongs_greek.db'), 'Strong\'s Grego'),
        (os.path.join(STRONGS_DIR, 'strongs_hebrew.db'), 'Strong\'s Hebraico'),
    ]

    all_ok = True
    for path, label in files:
        if os.path.exists(path):
            size_kb = os.path.getsize(path) // 1024
            status = "✓" if size_kb > 50 else "⚠ (muito pequeno)"
            print(f"  {status} {label}: {size_kb} KB")
            if size_kb <= 50:
                all_ok = False
        else:
            print(f"  ✗ {label}: NÃO ENCONTRADO")
            all_ok = False

    if all_ok:
        print("\n✓ Tudo pronto! Agora executa:")
        print("  cd flutter_app && flutter pub get && flutter run")
    else:
        print("\n⚠ Alguns ficheiros estão em falta ou são muito pequenos.")
        print("  Verifica a tua ligação à internet e tenta novamente.")


if __name__ == '__main__':
    main()
