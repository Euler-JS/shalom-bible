import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/bible_database.dart';
import '../../data/models/bible_verse.dart';
import '../../data/remote/openai_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/settings_provider.dart';
import '../../core/constants/app_constants.dart';

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key});

  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  List<String> _books = [];
  String? _selectedBook;
  int _selectedChapter = 1;
  int _totalChapters = 1;
  List<BibleVerse> _verses = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final settings = ref.read(settingsProvider);
    final books = await BibleDatabase.instance.getBooks(settings.translation);
    if (books.isEmpty) {
      // Fallback to constants if DB not loaded
      setState(() {
        _books = settings.translation == 'ARC'
            ? AppConstants.allBooksARC()
            : AppConstants.allBooksKJV();
        _selectedBook = _books.first;
      });
    } else {
      setState(() {
        _books = books;
        _selectedBook = books.first;
      });
    }
    await _loadChapter();
  }

  Future<void> _loadChapter() async {
    if (_selectedBook == null) return;
    final settings = ref.read(settingsProvider);
    setState(() => _loading = true);

    final count = await BibleDatabase.instance.getChapterCount(
      translation: settings.translation,
      book: _selectedBook!,
    );

    final verses = await BibleDatabase.instance.getChapter(
      translation: settings.translation,
      book: _selectedBook!,
      chapter: _selectedChapter,
    );

    setState(() {
      _totalChapters = count > 0 ? count : 150;
      _verses = verses;
      _loading = false;
    });
  }

  void _previousChapter() {
    if (_selectedChapter > 1) {
      setState(() => _selectedChapter--);
      _loadChapter();
    } else {
      // Go to previous book
      final idx = _books.indexOf(_selectedBook!);
      if (idx > 0) {
        setState(() {
          _selectedBook = _books[idx - 1];
          _selectedChapter = 1;
        });
        _loadChapter();
      }
    }
  }

  void _nextChapter() {
    if (_selectedChapter < _totalChapters) {
      setState(() => _selectedChapter++);
      _loadChapter();
    } else {
      // Go to next book
      final idx = _books.indexOf(_selectedBook!);
      if (idx < _books.length - 1) {
        setState(() {
          _selectedBook = _books[idx + 1];
          _selectedChapter = 1;
        });
        _loadChapter();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isPT ? 'Leitura' : 'Reading'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_edu_rounded),
            tooltip: isPT ? 'Contexto Histórico' : 'Historical Context',
            onPressed: _selectedBook != null ? _showHistoricalContext : null,
          ),
          // Translation toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ARC', label: Text('ARC')),
                ButtonSegment(value: 'KJV', label: Text('KJV')),
              ],
              selected: {settings.translation},
              onSelectionChanged: (val) {
                ref.read(settingsProvider.notifier).setTranslation(val.first);
                _loadChapter();
              },
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Book + Chapter selector
          _BookChapterSelector(
            books: _books,
            selectedBook: _selectedBook ?? '',
            selectedChapter: _selectedChapter,
            totalChapters: _totalChapters,
            onBookChanged: (book) {
              setState(() {
                _selectedBook = book;
                _selectedChapter = 1;
              });
              _loadChapter();
            },
            onChapterChanged: (ch) {
              setState(() => _selectedChapter = ch);
              _loadChapter();
            },
          ),

          const Divider(height: 1),

          // Verses
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _verses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.menu_book_outlined,
                                size: 48, color: AppColors.primary),
                            const SizedBox(height: 12),
                            Text(
                              isPT
                                  ? 'Base de dados da Bíblia não encontrada.\nAdiciona os arquivos .db em assets/bible/'
                                  : 'Bible database not found.\nAdd .db files to assets/bible/',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                        itemCount: _verses.length,
                        itemBuilder: (context, index) {
                          return _VerseRow(
                            verse: _verses[index],
                            fontSize: settings.fontSize,
                          );
                        },
                      ),
          ),

          // Chapter navigation
          _ChapterNavigation(
            chapter: _selectedChapter,
            total: _totalChapters,
            onPrevious: _previousChapter,
            onNext: _nextChapter,
          ),
        ],
      ),
    );
  }

  void _showHistoricalContext() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HistoricalContextBottomSheet(
        book: _selectedBook!,
        chapter: _selectedChapter,
      ),
    );
  }
}

class _BookChapterSelector extends StatelessWidget {
  final List<String> books;
  final String selectedBook;
  final int selectedChapter;
  final int totalChapters;
  final ValueChanged<String> onBookChanged;
  final ValueChanged<int> onChapterChanged;

  const _BookChapterSelector({
    required this.books,
    required this.selectedBook,
    required this.selectedChapter,
    required this.totalChapters,
    required this.onBookChanged,
    required this.onChapterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Book dropdown
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: books.contains(selectedBook) ? selectedBook : null,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: books
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) onBookChanged(val);
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Chapter dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: selectedChapter,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                items: List.generate(
                  totalChapters,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Cap. ${i + 1}'),
                  ),
                ),
                onChanged: (val) {
                  if (val != null) onChapterChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseRow extends StatefulWidget {
  final BibleVerse verse;
  final double fontSize;

  const _VerseRow({required this.verse, required this.fontSize});

  @override
  State<_VerseRow> createState() => _VerseRowState();
}

class _VerseRowState extends State<_VerseRow> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _highlighted = !_highlighted),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: _highlighted
              ? AppColors.secondary.withAlpha(30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${widget.verse.verse}  ',
                style: GoogleFonts.inter(
                  fontSize: widget.fontSize - 4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              TextSpan(
                text: widget.verse.text,
                style: GoogleFonts.merriweather(
                  fontSize: widget.fontSize,
                  height: 1.8,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterNavigation extends StatelessWidget {
  final int chapter;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _ChapterNavigation({
    required this.chapter,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filled(
            onPressed: chapter > 1 ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
            ),
          ),
          Text(
            'Capítulo $chapter de $total',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton.filled(
            onPressed: chapter < total ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoricalContextBottomSheet extends ConsumerStatefulWidget {
  final String book;
  final int chapter;

  const _HistoricalContextBottomSheet({
    required this.book,
    required this.chapter,
  });

  @override
  ConsumerState<_HistoricalContextBottomSheet> createState() =>
      _HistoricalContextBottomSheetState();
}

class _HistoricalContextBottomSheetState
    extends ConsumerState<_HistoricalContextBottomSheet> {
  Map<String, dynamic>? _context;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    final auth = ref.read(authProvider);
    try {
      final raw = await OpenAIService.instance.getHistoricalContext(
        book: widget.book,
        chapter: widget.chapter,
        language: settings.language,
        isPremium: auth.user?.isPremium ?? false,
      );
      setState(() {
        _context = jsonDecode(raw) as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar. Verifica a tua ligação.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.history_edu_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Contexto — ${widget.book} ${widget.chapter}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? Center(child: Text(_error!))
                      : SingleChildScrollView(
                          controller: scroll,
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_context!['timePeriod'] != null)
                                _ContextTile(
                                  icon: Icons.schedule,
                                  label: 'Período Histórico',
                                  text: _context!['timePeriod'].toString(),
                                ),
                              if (_context!['author'] != null)
                                _ContextTile(
                                  icon: Icons.person_outline,
                                  label: 'Autor',
                                  text: _context!['author'].toString(),
                                ),
                              if (_context!['audience'] != null)
                                _ContextTile(
                                  icon: Icons.groups_outlined,
                                  label: 'Destinatários',
                                  text: _context!['audience'].toString(),
                                ),
                              if (_context!['geographicContext'] != null)
                                _ContextTile(
                                  icon: Icons.location_on_outlined,
                                  label: 'Contexto Geográfico',
                                  text: _context!['geographicContext'].toString(),
                                ),
                              if (_context!['purpose'] != null)
                                _ContextTile(
                                  icon: Icons.lightbulb_outline,
                                  label: 'Propósito',
                                  text: _context!['purpose'].toString(),
                                ),
                              if (_context!['summary'] != null)
                                _ContextTile(
                                  icon: Icons.notes_rounded,
                                  label: 'Resumo',
                                  text: _context!['summary'].toString(),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _ContextTile({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
