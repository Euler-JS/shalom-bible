class AppConstants {
  // API
  static const String backendBaseUrl = 'http://o8w0k4w04w80wc0cwwg8k0cw.194.163.145.253.sslip.io/api';

  // Secure storage keys
  static const String jwtTokenKey = 'shalom_jwt_token';
  static const String userDataKey = 'shalom_user_data';
  static const String deviceIdKey = 'shalom_device_id';

  // SharedPreferences keys
  static const String selectedTranslationKey = 'selected_translation';
  static const String selectedLanguageKey = 'selected_language';
  static const String onboardingDoneKey = 'onboarding_done';
  static const String fontSizeKey = 'bible_font_size';

  // Bible translations
  static const String translationARC = 'ARC';
  static const String translationKJV = 'KJV';

  // Bible asset paths
  static const String arcDbPath = 'assets/bible/arc.db';
  static const String kjvDbPath = 'assets/bible/kjv.db';
  static const String strongsHebrewDbPath = 'assets/strongs/strongs_hebrew.db';
  static const String strongsGreekDbPath = 'assets/strongs/strongs_greek.db';

  // Free plan limits
  static const int freeScenarioSearchPerWeek = 3;
  static const int freeSermonGeneratorPerMonth = 2;
  static const int freeSermonLibraryLimit = 5;

  // Bible books
  static const List<String> oldTestamentBooks = [
    'Gênesis',
    'Êxodo',
    'Levítico',
    'Números',
    'Deuteronômio',
    'Josué',
    'Juízes',
    'Rute',
    '1 Samuel',
    '2 Samuel',
    '1 Reis',
    '2 Reis',
    '1 Crônicas',
    '2 Crônicas',
    'Esdras',
    'Neemias',
    'Ester',
    'Jó',
    'Salmos',
    'Provérbios',
    'Eclesiastes',
    'Cantares',
    'Isaías',
    'Jeremias',
    'Lamentações',
    'Ezequiel',
    'Daniel',
    'Oséias',
    'Joel',
    'Amós',
    'Obadias',
    'Jonas',
    'Miquéias',
    'Naum',
    'Habacuque',
    'Sofonias',
    'Ageu',
    'Zacarias',
    'Malaquias',
  ];

  static const List<String> newTestamentBooks = [
    'Mateus',
    'Marcos',
    'Lucas',
    'João',
    'Atos',
    'Romanos',
    '1 Coríntios',
    '2 Coríntios',
    'Gálatas',
    'Efésios',
    'Filipenses',
    'Colossenses',
    '1 Tessalonicenses',
    '2 Tessalonicenses',
    '1 Timóteo',
    '2 Timóteo',
    'Tito',
    'Filemon',
    'Hebreus',
    'Tiago',
    '1 Pedro',
    '2 Pedro',
    '1 João',
    '2 João',
    '3 João',
    'Judas',
    'Apocalipse',
  ];

  static const List<String> oldTestamentBooksKJV = [
    'Genesis',
    'Exodus',
    'Leviticus',
    'Numbers',
    'Deuteronomy',
    'Joshua',
    'Judges',
    'Ruth',
    '1 Samuel',
    '2 Samuel',
    '1 Kings',
    '2 Kings',
    '1 Chronicles',
    '2 Chronicles',
    'Ezra',
    'Nehemiah',
    'Esther',
    'Job',
    'Psalms',
    'Proverbs',
    'Ecclesiastes',
    'Song of Solomon',
    'Isaiah',
    'Jeremiah',
    'Lamentations',
    'Ezekiel',
    'Daniel',
    'Hosea',
    'Joel',
    'Amos',
    'Obadiah',
    'Jonah',
    'Micah',
    'Nahum',
    'Habakkuk',
    'Zephaniah',
    'Haggai',
    'Zechariah',
    'Malachi',
  ];

  static const List<String> newTestamentBooksKJV = [
    'Matthew',
    'Mark',
    'Luke',
    'John',
    'Acts',
    'Romans',
    '1 Corinthians',
    '2 Corinthians',
    'Galatians',
    'Ephesians',
    'Philippians',
    'Colossians',
    '1 Thessalonians',
    '2 Thessalonians',
    '1 Timothy',
    '2 Timothy',
    'Titus',
    'Philemon',
    'Hebrews',
    'James',
    '1 Peter',
    '2 Peter',
    '1 John',
    '2 John',
    '3 John',
    'Jude',
    'Revelation',
  ];

  static List<String> allBooksARC() => [
    ...oldTestamentBooks,
    ...newTestamentBooks,
  ];
  static List<String> allBooksKJV() => [
    ...oldTestamentBooksKJV,
    ...newTestamentBooksKJV,
  ];
}
