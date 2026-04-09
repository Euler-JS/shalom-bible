import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
  List<BibleVerse> _compareVerses = [];
  bool _loading = false;
  String? _currentTranslation;
  String? _compareTranslation;

  // Multi-verse selection
  bool _selectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    // Defer initial load so provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _currentTranslation = ref.read(settingsProvider).translation;
      _loadBooks(_currentTranslation!);
    });
  }

  Future<void> _loadBooks(String translation) async {
    final books = await BibleDatabase.instance.getBooks(translation);
    if (!mounted) return;

    // Try to keep same book position when switching translations
    final currentIdx = _books.indexOf(_selectedBook ?? '');
    final newBooks = books.isNotEmpty
        ? books
        : AppConstants.allBooksForLanguage(
            AppConstants.languageForTranslation(translation),
          );

    final newBook = (currentIdx > 0 && currentIdx < newBooks.length)
        ? newBooks[currentIdx]
        : newBooks.first;

    setState(() {
      _books = newBooks;
      _selectedBook = newBook;
    });
    await _loadChapter(translation);
  }

  Future<void> _loadChapter(String translation) async {
    if (_selectedBook == null) return;
    if (!mounted) return;
    setState(() => _loading = true);

    final selectedBookNumber = (_books.indexOf(_selectedBook!) + 1).clamp(1, 66);

    final count = await BibleDatabase.instance.getChapterCount(
      translation: translation,
      book: _selectedBook!,
    );
    final verses = await BibleDatabase.instance.getChapter(
      translation: translation,
      book: _selectedBook!,
      chapter: _selectedChapter,
    );
    final compareTranslation = _compareTranslation;
    final compareVerses = compareTranslation != null
        ? await BibleDatabase.instance.getChapterByBookNumber(
            translation: compareTranslation,
            bookNumber: selectedBookNumber,
            chapter: _selectedChapter,
          )
        : <BibleVerse>[];

    if (!mounted) return;
    setState(() {
      _totalChapters = count > 0 ? count : 150;
      _verses = verses;
      _compareVerses = compareVerses;
      _loading = false;
    });
  }

  Future<void> _setCompareTranslation(String? translation) async {
    if (_compareTranslation == translation) return;
    _exitSelectionMode();
    setState(() {
      _compareTranslation = translation;
      if (translation == null) {
        _compareVerses = [];
      }
    });
    await _loadChapter(ref.read(settingsProvider).translation);
  }

  void _showComparePicker(List<String> availableTranslations) {
    final options = availableTranslations
        .where((item) => item != ref.read(settingsProvider).translation)
        .toList();
    final isPT = ref.read(settingsProvider).language == 'pt';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CompareTranslationSheet(
        options: options,
        selectedTranslation: _compareTranslation,
        isPT: isPT,
        onSelected: (translation) {
          Navigator.of(ctx).pop();
          _setCompareTranslation(translation);
        },
      ),
    );
  }

  void _enterSelectionMode(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIndices.add(index);
    });
  }

  void _toggleSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) _selectionMode = false;
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIndices.clear();
    });
  }

  String _buildSelectedText(String language) {
    final sorted = _selectedIndices.toList()..sort();
    final lines = sorted.map((i) {
      final v = _verses[i];
      return '«${v.text}»\n— ${v.book} ${v.chapter}:${v.verse}';
    });
    return lines.join('\n\n');
  }

  void _copySelected(String language) {
    final text = _buildSelectedText(language);
    final n = _selectedIndices.length;
    Clipboard.setData(ClipboardData(text: text));
    _exitSelectionMode();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          language == 'pt'
              ? (n > 1 ? '$n versículos copiados' : 'Versículo copiado')
              : (n > 1 ? '$n verses copied' : 'Verse copied'),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareSelected(String language) {
    final text = _buildSelectedText(language);
    _exitSelectionMode();
    Share.share(text);
  }

  void _previousChapter() {
    _exitSelectionMode();
    final translation = ref.read(settingsProvider).translation;
    if (_selectedChapter > 1) {
      setState(() => _selectedChapter--);
      _loadChapter(translation);
    } else {
      final idx = _books.indexOf(_selectedBook!);
      if (idx > 0) {
        setState(() {
          _selectedBook = _books[idx - 1];
          _selectedChapter = 1;
        });
        _loadChapter(translation);
      }
    }
  }

  void _nextChapter() {
    _exitSelectionMode();
    final translation = ref.read(settingsProvider).translation;
    if (_selectedChapter < _totalChapters) {
      setState(() => _selectedChapter++);
      _loadChapter(translation);
    } else {
      final idx = _books.indexOf(_selectedBook!);
      if (idx < _books.length - 1) {
        setState(() {
          _selectedBook = _books[idx + 1];
          _selectedChapter = 1;
        });
        _loadChapter(translation);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';
    final theme = Theme.of(context);
    final availableTranslations =
      BibleDatabase.instance.getAvailableTranslations(settings.language);
    final compareTranslations = BibleDatabase.instance.getAllAvailableTranslations();

    // React to translation changes (e.g. from settings screen or prefs load)
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      if (prev?.translation != next.translation) {
        if (_compareTranslation == next.translation) {
          _compareTranslation = null;
          _compareVerses = [];
        }
        _currentTranslation = next.translation;
        _loadBooks(next.translation);
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Custom header (replaces AppBar + BookChapterSelector)
          _BibleHeader(
            books: _books,
            selectedBook: _selectedBook ?? '',
            selectedChapter: _selectedChapter,
            totalChapters: _totalChapters,
            availableTranslations: availableTranslations,
            translation: settings.translation,
            isPT: isPT,
            canInteract: _selectedBook != null,
            onBookChanged: (book) {
              final translation = ref.read(settingsProvider).translation;
              setState(() {
                _selectedBook = book;
                _selectedChapter = 1;
              });
              _loadChapter(translation);
            },
            onChapterChanged: (ch) {
              final translation = ref.read(settingsProvider).translation;
              setState(() => _selectedChapter = ch);
              _loadChapter(translation);
            },
            onTranslationChanged: (val) {
              ref.read(settingsProvider.notifier).setTranslation(val);
            },
            compareTranslation: _compareTranslation,
            onCompareTap: () => _showComparePicker(compareTranslations),
            onChat: _showChat,
            onHistory: _showHistoricalContext,
          ),

          // Verses
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _verses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isPT
                              ? 'Nenhum conteúdo bíblico foi carregado para esta versão.'
                              : 'No Bible content was loaded for this translation.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.ac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : _compareTranslation != null
                ? _CompareChapterView(
                    primaryVerses: _verses,
                    secondaryVerses: _compareVerses,
                    primaryLabel: AppConstants.translationLabel(
                      settings.translation,
                    ),
                    secondaryLabel: AppConstants.translationLabel(
                      _compareTranslation!,
                    ),
                    fontSize: settings.fontSize,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _verses.length,
                    itemBuilder: (context, index) {
                      final auth = ref.read(authProvider);
                      return _VerseRow(
                        verse: _verses[index],
                        fontSize: settings.fontSize,
                        language: settings.language,
                        isPremium: auth.user?.isPremium ?? false,
                        selectionMode: _selectionMode,
                        isSelected: _selectedIndices.contains(index),
                        onLongPress: () => _enterSelectionMode(index),
                        onSelect: () => _toggleSelection(index),
                      );
                    },
                  ),
          ),

          // Multi-select action bar
          if (_selectionMode && _compareTranslation == null)
            _MultiSelectBar(
              count: _selectedIndices.length,
              language: settings.language,
              onCopy: () => _copySelected(settings.language),
              onShare: () => _shareSelected(settings.language),
              onCancel: _exitSelectionMode,
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
    FocusScope.of(context).unfocus();
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

  void _showChat() {
    FocusScope.of(context).unfocus();
    final settings = ref.read(settingsProvider);
    final auth = ref.read(authProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BibleChatBottomSheet(
        book: _selectedBook!,
        chapter: _selectedChapter,
        language: settings.language,
        isPremium: auth.user?.isPremium ?? false,
      ),
    );
  }
}

class _BibleHeader extends StatelessWidget {
  final List<String> books;
  final String selectedBook;
  final int selectedChapter;
  final int totalChapters;
  final List<String> availableTranslations;
  final String translation;
  final String? compareTranslation;
  final bool isPT;
  final bool canInteract;
  final ValueChanged<String> onBookChanged;
  final ValueChanged<int> onChapterChanged;
  final ValueChanged<String> onTranslationChanged;
  final VoidCallback onCompareTap;
  final VoidCallback onChat;
  final VoidCallback onHistory;

  const _BibleHeader({
    required this.books,
    required this.selectedBook,
    required this.selectedChapter,
    required this.totalChapters,
    required this.availableTranslations,
    required this.translation,
    required this.compareTranslation,
    required this.isPT,
    required this.canInteract,
    required this.onBookChanged,
    required this.onChapterChanged,
    required this.onTranslationChanged,
    required this.onCompareTap,
    required this.onChat,
    required this.onHistory,
  });

  List<String> _orderedTranslations() {
    final ordered = List<String>.from(availableTranslations);
    final selectedIndex = ordered.indexOf(translation);
    if (selectedIndex > 0) {
      final selected = ordered.removeAt(selectedIndex);
      ordered.insert(0, selected);
    }
    return ordered;
  }

  void _showTranslationPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TranslationPickerSheet(
        translations: availableTranslations,
        selectedTranslation: translation,
        isPT: isPT,
        onSelected: onTranslationChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    final orderedTranslations = _orderedTranslations();
    final activeTranslation = orderedTranslations.first;
    final hasOtherTranslations = orderedTranslations.length > 1;

    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(bottom: BorderSide(color: ac.divider)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Book + Chapter pills
            Row(
              children: [
                // Book pill
                Expanded(
                  child: _HeaderPill(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: books.contains(selectedBook)
                            ? selectedBook
                            : null,
                        isExpanded: true,
                        isDense: true,
                        dropdownColor: ac.surface,
                        icon: Icon(
                          Icons.expand_more_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        style: TextStyle(
                          color: ac.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        items: books
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(
                                  b,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) onBookChanged(val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Chapter pill
                _HeaderPill(
                  width: 120,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selectedChapter,
                      isExpanded: true,
                      isDense: true,
                      dropdownColor: ac.surface,
                      icon: Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      style: TextStyle(
                        color: ac.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      items: List.generate(
                        totalChapters,
                        (i) => DropdownMenuItem(
                          value: i + 1,
                          child: Text(isPT ? 'Cap. ${i + 1}' : 'Ch. ${i + 1}'),
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

            const SizedBox(height: 8),

            // Row 2: Translation toggle + action icons
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: ac.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ac.cardBorder.withAlpha(160)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _TranslationChip(
                              label: AppConstants.translationLabel(
                                activeTranslation,
                              ),
                              selected: true,
                              onTap: () => _showTranslationPicker(context),
                            ),
                          ),
                          if (hasOtherTranslations)
                            _TranslationChip(
                              label: isPT ? 'Escolher outra' : 'Choose another',
                              selected: false,
                              icon: Icons.add_rounded,
                              onTap: () => _showTranslationPicker(context),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.compare_arrows_rounded,
                  label: compareTranslation != null
                      ? AppConstants.translationLabel(compareTranslation!)
                      : (isPT ? 'Comparar' : 'Compare'),
                  onTap: canInteract ? onCompareTap : null,
                  highlighted: compareTranslation != null,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.history_edu_rounded,
                  label: isPT ? 'Contexto' : 'Context',
                  onTap: canInteract ? onHistory : null,
                ),
                const SizedBox(width: 8),
                _ActionPill(
                  icon: Icons.chat_outlined,
                  label: isPT ? 'Tutor' : 'Tutor',
                  onTap: canInteract ? onChat : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TranslationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  const _TranslationChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.primary.withAlpha(70)
        : Colors.transparent;
    final backgroundColor = selected
        ? AppColors.primary.withAlpha(14)
        : Colors.transparent;
    final textColor = selected
        ? AppColors.primary
        : context.ac.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: textColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TranslationPickerSheet extends StatelessWidget {
  final List<String> translations;
  final String selectedTranslation;
  final bool isPT;
  final ValueChanged<String> onSelected;

  const _TranslationPickerSheet({
    required this.translations,
    required this.selectedTranslation,
    required this.isPT,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: ac.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ac.cardBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  isPT ? 'Versões bíblicas' : 'Bible versions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ac.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...translations.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppConstants.translationLabel(item),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  AppConstants.translationLabel(item),
                  style: TextStyle(
                    color: ac.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: item == selectedTranslation
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelected(item);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final Widget child;
  final double? width;

  const _HeaderPill({required this.child, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: context.ac.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.ac.cardBorder),
      ),
      child: child,
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool highlighted;

  const _ActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = highlighted
        ? AppColors.primary
        : enabled
        ? AppColors.primary
        : context.ac.textSecondary.withAlpha(80);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: highlighted
              ? AppColors.primary.withAlpha(18)
              : enabled
              ? AppColors.primary.withAlpha(14)
              : context.ac.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withAlpha(90)
                : enabled
                ? AppColors.primary.withAlpha(60)
                : context.ac.cardBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareTranslationSheet extends StatelessWidget {
  final List<String> options;
  final String? selectedTranslation;
  final bool isPT;
  final ValueChanged<String?> onSelected;

  const _CompareTranslationSheet({
    required this.options,
    required this.selectedTranslation,
    required this.isPT,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: ac.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: ac.cardBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isPT ? 'Comparar com...' : 'Compare with...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ac.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (selectedTranslation != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.close_rounded,
                  color: AppColors.primary,
                ),
                title: Text(
                  isPT ? 'Desativar comparação' : 'Disable comparison',
                  style: TextStyle(
                    color: ac.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => onSelected(null),
              ),
            ...options.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppConstants.translationLabel(item),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(
                  AppConstants.translationLabel(item),
                  style: TextStyle(
                    color: ac.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: item == selectedTranslation
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : null,
                onTap: () => onSelected(item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareChapterView extends StatelessWidget {
  final List<BibleVerse> primaryVerses;
  final List<BibleVerse> secondaryVerses;
  final String primaryLabel;
  final String secondaryLabel;
  final double fontSize;

  const _CompareChapterView({
    required this.primaryVerses,
    required this.secondaryVerses,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryByVerse = {
      for (final verse in secondaryVerses) verse.verse: verse,
    };
    final allVerseNumbers = <int>{
      ...primaryVerses.map((verse) => verse.verse),
      ...secondaryVerses.map((verse) => verse.verse),
    }.toList()
      ..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: allVerseNumbers.length,
      itemBuilder: (context, index) {
        final verseNumber = allVerseNumbers[index];
        final primary = primaryVerses
            .cast<BibleVerse?>()
            .firstWhere((verse) => verse?.verse == verseNumber, orElse: () => null);
        final secondary = secondaryByVerse[verseNumber];

        return _CompareVerseRow(
          verseNumber: verseNumber,
          primaryVerse: primary,
          secondaryVerse: secondary,
          primaryLabel: primaryLabel,
          secondaryLabel: secondaryLabel,
          fontSize: fontSize,
        );
      },
    );
  }
}

class _CompareVerseRow extends StatelessWidget {
  final int verseNumber;
  final BibleVerse? primaryVerse;
  final BibleVerse? secondaryVerse;
  final String primaryLabel;
  final String secondaryLabel;
  final double fontSize;

  const _CompareVerseRow({
    required this.verseNumber,
    required this.primaryVerse,
    required this.secondaryVerse,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$verseNumber',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CompareVersionBlock(
                    label: primaryLabel,
                    text: primaryVerse?.text ?? '—',
                    fontSize: fontSize,
                    highlighted: true,
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: ac.cardBorder,
                ),
                Expanded(
                  child: _CompareVersionBlock(
                    label: secondaryLabel,
                    text: secondaryVerse?.text ?? '—',
                    fontSize: fontSize,
                    highlighted: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareVersionBlock extends StatelessWidget {
  final String label;
  final String text;
  final double fontSize;
  final bool highlighted;

  const _CompareVersionBlock({
    required this.label,
    required this.text,
    required this.fontSize,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: highlighted
                    ? AppColors.primary.withAlpha(12)
                    : ac.cardBackground,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: highlighted
                      ? AppColors.primary.withAlpha(40)
                      : ac.cardBorder.withAlpha(160),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: highlighted ? AppColors.primary : ac.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: GoogleFonts.merriweather(
            fontSize: fontSize - 1,
            height: 1.7,
            color: ac.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _VerseRow extends StatefulWidget {
  final BibleVerse verse;
  final double fontSize;
  final String language;
  final bool isPremium;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback onSelect;

  const _VerseRow({
    required this.verse,
    required this.fontSize,
    required this.language,
    required this.isPremium,
    required this.selectionMode,
    required this.isSelected,
    required this.onLongPress,
    required this.onSelect,
  });

  @override
  State<_VerseRow> createState() => _VerseRowState();
}

class _VerseRowState extends State<_VerseRow> {
  bool _expanded = false;

  void _openExplain() {
    setState(() => _expanded = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExplainBottomSheet(
        verse: widget.verse,
        language: widget.language,
        isPremium: widget.isPremium,
      ),
    );
  }

  void _openWordStudy() {
    setState(() => _expanded = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WordStudyBottomSheet(
        verse: widget.verse,
        language: widget.language,
        isPremium: widget.isPremium,
      ),
    );
  }

  String get _verseText =>
      '«${widget.verse.text}»\n— ${widget.verse.book} ${widget.verse.chapter}:${widget.verse.verse}';

  void _copyVerse() {
    Clipboard.setData(ClipboardData(text: _verseText));
    setState(() => _expanded = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.language == 'pt' ? 'Versículo copiado' : 'Verse copied',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareVerse() {
    setState(() => _expanded = false);
    Share.share(_verseText);
  }

  @override
  Widget build(BuildContext context) {
    final isPT = widget.language == 'pt';
    final isSelected = widget.isSelected;
    final selectionMode = widget.selectionMode;
    return GestureDetector(
      onTap: () {
        if (selectionMode) {
          widget.onSelect();
        } else {
          HapticFeedback.selectionClick();
          setState(() => _expanded = !_expanded);
        }
      },
      onLongPress: selectionMode ? null : widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.secondary.withAlpha(30)
              : _expanded
              ? AppColors.primary.withAlpha(12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.secondary.withAlpha(100))
              : _expanded
              ? Border.all(color: AppColors.primary.withAlpha(40))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                            color: Theme.of(
                              context,
                            ).extension<AppAdaptiveColors>()!.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (selectionMode)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.secondary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.secondary
                              : context.ac.textSecondary.withAlpha(100),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            // Action row — shown when verse is tapped (not in selection mode)
            if (_expanded && !selectionMode)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ActionChip(
                      icon: Icons.lightbulb_outline_rounded,
                      label: isPT ? 'Explicar' : 'Explain',
                      onTap: _openExplain,
                    ),
                    _ActionChip(
                      icon: Icons.translate_rounded,
                      label: isPT ? 'Palavras' : 'Words',
                      onTap: _openWordStudy,
                    ),
                    _ActionChip(
                      icon: Icons.copy_rounded,
                      label: isPT ? 'Copiar' : 'Copy',
                      onTap: _copyVerse,
                    ),
                    _ActionChip(
                      icon: Icons.share_rounded,
                      label: isPT ? 'Partilhar' : 'Share',
                      onTap: _shareVerse,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).extension<AppAdaptiveColors>()!.cardBackground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiSelectBar extends StatelessWidget {
  final int count;
  final String language;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onCancel;

  const _MultiSelectBar({
    required this.count,
    required this.language,
    required this.onCopy,
    required this.onShare,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isPT = language == 'pt';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(20),
        border: Border(
          top: BorderSide(color: AppColors.secondary.withAlpha(80)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPT
                  ? (count == 1
                        ? 'versículo selecionado'
                        : 'versículos selecionados')
                  : (count == 1 ? 'verse selected' : 'verses selected'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.ac.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
            tooltip: isPT ? 'Copiar' : 'Copy',
            color: AppColors.primary,
            iconSize: 20,
          ),
          IconButton(
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded),
            tooltip: isPT ? 'Partilhar' : 'Share',
            color: AppColors.primary,
            iconSize: 20,
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded),
            tooltip: isPT ? 'Cancelar' : 'Cancel',
            color: context.ac.textSecondary,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

class _ExplainBottomSheet extends ConsumerStatefulWidget {
  final BibleVerse verse;
  final String language;
  final bool isPremium;

  const _ExplainBottomSheet({
    required this.verse,
    required this.language,
    required this.isPremium,
  });

  @override
  ConsumerState<_ExplainBottomSheet> createState() =>
      _ExplainBottomSheetState();
}

class _ExplainBottomSheetState extends ConsumerState<_ExplainBottomSheet> {
  String? _explanation;
  String? _context;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isPT = widget.language == 'pt';
    try {
      final hasKey = await OpenAIService.instance.hasApiKey();
      if (!hasKey) {
        if (!mounted) return;
        setState(() {
          _error = isPT
              ? 'Chave OpenAI não configurada. Vai a Definições.'
              : 'OpenAI key not configured. Go to Settings.';
          _loading = false;
        });
        return;
      }
      final raw = await OpenAIService.instance.explainVerse(
        reference: widget.verse.reference,
        verseText: widget.verse.text,
        language: widget.language,
        isPremium: widget.isPremium,
      );
      if (!mounted) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _explanation = json['explanation']?.toString() ?? '';
        _context = json['context']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPT = widget.language == 'pt';
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.85,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).extension<AppAdaptiveColors>()!.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.ac.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_rounded,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPT ? 'Explicação' : 'Explanation',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.ac.textPrimary,
                          ),
                        ),
                        Text(
                          widget.verse.reference,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.ac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Verse text
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.secondary.withAlpha(60)),
              ),
              child: Text(
                widget.verse.text,
                style: GoogleFonts.merriweather(
                  fontSize: 13,
                  height: 1.6,
                  color: context.ac.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isPT ? 'A explicar...' : 'Explaining...',
                            style: TextStyle(
                              color: context.ac.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.ac.textSecondary),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _explanation ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.7,
                              color: context.ac.textPrimary,
                            ),
                          ),
                          if (_context != null &&
                              _context!.isNotEmpty &&
                              _context != 'null') ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).extension<AppAdaptiveColors>()!.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: context.ac.cardBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isPT
                                            ? 'Contexto histórico'
                                            : 'Historical context',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _context!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: context.ac.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

class _WordStudyBottomSheet extends ConsumerStatefulWidget {
  final BibleVerse verse;
  final String language;
  final bool isPremium;

  const _WordStudyBottomSheet({
    required this.verse,
    required this.language,
    required this.isPremium,
  });

  @override
  ConsumerState<_WordStudyBottomSheet> createState() =>
      _WordStudyBottomSheetState();
}

class _WordStudyBottomSheetState extends ConsumerState<_WordStudyBottomSheet> {
  List<WordStudyEntry> _words = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final isPT = widget.language == 'pt';
    try {
      final hasKey = await OpenAIService.instance.hasApiKey();
      if (!hasKey) {
        if (!mounted) return;
        setState(() {
          _error = isPT
              ? 'Chave OpenAI não configurada.\nVai a Definições e adiciona a tua chave API.'
              : 'OpenAI key not configured.\nGo to Settings and add your API key.';
          _loading = false;
        });
        return;
      }

      final words = await OpenAIService.instance.getVerseWordStudy(
        reference: widget.verse.reference,
        verseText: widget.verse.text,
        language: widget.language,
        isPremium: widget.isPremium,
      );
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _error = isPT ? 'Erro ao carregar:\n$msg' : 'Error loading:\n$msg';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPT = widget.language == 'pt';
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).extension<AppAdaptiveColors>()!.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.ac.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.translate_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPT ? 'Estudo das Palavras' : 'Word Study',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.ac.textPrimary,
                          ),
                        ),
                        Text(
                          widget.verse.reference,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.ac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Verse text preview
            Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).extension<AppAdaptiveColors>()!.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.ac.cardBorder),
              ),
              child: Text(
                widget.verse.text,
                style: GoogleFonts.merriweather(
                  fontSize: 13,
                  height: 1.6,
                  color: context.ac.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isPT
                                ? 'A analisar as palavras originais...'
                                : 'Analyzing original words...',
                            style: TextStyle(
                              color: context.ac.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.ac.textSecondary),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      itemCount: _words.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _WordStudyCard(entry: _words[i], isPT: isPT),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordStudyCard extends StatelessWidget {
  final WordStudyEntry entry;
  final bool isPT;

  const _WordStudyCard({required this.entry, required this.isPT});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).extension<AppAdaptiveColors>()!.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.ac.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: translated word → original word
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '"${entry.translatedWord}"',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).extension<AppAdaptiveColors>()!.cardBackground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: context.ac.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                entry.originalWord,
                style: const TextStyle(
                  fontSize: 20,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Transliteration + Strongs number
          Row(
            children: [
              Text(
                entry.transliteration,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (entry.strongsNumber.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.strongsNumber,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          // Meaning
          Text(
            isPT ? 'Significado' : 'Meaning',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            entry.meaning,
            style: TextStyle(
              fontSize: 14,
              color: context.ac.textPrimary,
              height: 1.5,
            ),
          ),
          if (entry.insight.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              isPT ? 'Perspectiva Teológica' : 'Theological Insight',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.insight,
              style: TextStyle(
                fontSize: 14,
                color: context.ac.textPrimary,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
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
      decoration: BoxDecoration(
        color: Theme.of(context).extension<AppAdaptiveColors>()!.cardBackground,
        border: Border(top: BorderSide(color: context.ac.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (chapter > 1)
            IconButton.filled(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            )
          else
            const SizedBox(width: 48),
          Text(
            'Capítulo $chapter de $total',
            style: TextStyle(
              color: context.ac.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (chapter < total)
            IconButton.filled(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            )
          else
            const SizedBox(width: 48),
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
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).extension<AppAdaptiveColors>()!.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.ac.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.history_edu_rounded,
                    color: AppColors.primary,
                  ),
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
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
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

// ─── Bible Chat ──────────────────────────────────────────────────────────────

class _ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  const _ChatMessage({required this.role, required this.content});
}

class _BibleChatBottomSheet extends ConsumerStatefulWidget {
  final String book;
  final int chapter;
  final String language;
  final bool isPremium;

  const _BibleChatBottomSheet({
    required this.book,
    required this.chapter,
    required this.language,
    required this.isPremium,
  });

  @override
  ConsumerState<_BibleChatBottomSheet> createState() =>
      _BibleChatBottomSheetState();
}

class _BibleChatBottomSheetState extends ConsumerState<_BibleChatBottomSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    final isPT = widget.language == 'pt';
    _ctrl.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', content: text));
      _sending = true;
    });
    _scrollToBottom();

    try {
      final hasKey = await OpenAIService.instance.hasApiKey();
      if (!hasKey) {
        if (!mounted) return;
        setState(() {
          _messages.add(
            _ChatMessage(
              role: 'assistant',
              content: isPT
                  ? 'Chave OpenAI não configurada. Vai a Definições e adiciona a tua chave API.'
                  : 'OpenAI key not configured. Go to Settings and add your API key.',
            ),
          );
          _sending = false;
        });
        return;
      }

      // Build history for OpenAI (exclude latest user message — it's sent as `question`)
      final history = _messages
          .take(_messages.length - 1)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final raw = await OpenAIService.instance.chatBibleQuestion(
        question: text,
        book: widget.book,
        chapter: widget.chapter,
        history: history,
        language: widget.language,
        isPremium: widget.isPremium,
      );

      if (!mounted) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final answer = json['answer']?.toString() ?? '';
      final refs = (json['relatedVerses'] as List<dynamic>? ?? [])
          .map((r) => r.toString())
          .where((r) => r.isNotEmpty)
          .toList();

      final fullAnswer = refs.isEmpty
          ? answer
          : '$answer\n\n📖 ${refs.join(' · ')}';

      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', content: fullAnswer));
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            content: e.toString().replaceFirst('Exception: ', ''),
          ),
        );
        _sending = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPT = widget.language == 'pt';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).extension<AppAdaptiveColors>()!.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.ac.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: [
                  const Icon(Icons.chat_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPT ? 'Tutor Bíblico' : 'Bible Tutor',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: context.ac.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.book} ${widget.chapter}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.ac.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isPT
                                    ? 'Faz uma pergunta sobre ${widget.book} ${widget.chapter}.\n\nPor exemplo:\n"O que significa este capítulo?"\n"Quem escreveu este livro?"\n"Por que Deus fez isso?"'
                                    : 'Ask a question about ${widget.book} ${widget.chapter}.\n\nFor example:\n"What does this chapter mean?"\n"Who wrote this book?"\n"Why did God do this?"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: context.ac.textSecondary,
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _ChatBubble(message: _messages[i]),
                    ),
            ),
            // Typing indicator
            if (_sending)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '...',
                      style: TextStyle(
                        color: context.ac.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            // Input — sobe com o teclado via AnimatedPadding
            AnimatedPadding(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: bottomInset > 0 ? bottomInset + 10 : 24,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isPT
                            ? 'Faz uma pergunta...'
                            : 'Ask a question...',
                        hintStyle: TextStyle(
                          color: context.ac.textSecondary,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: context.ac.inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.white,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : context.ac.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : context.ac.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Historical Context ───────────────────────────────────────────────────────

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
        color: Theme.of(context).extension<AppAdaptiveColors>()!.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.ac.cardBorder),
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}
