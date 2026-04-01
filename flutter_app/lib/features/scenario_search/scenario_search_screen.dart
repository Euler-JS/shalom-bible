import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bible_verse.dart';
import '../../data/local/bible_database.dart';
import '../../data/remote/openai_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/settings_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/verse_card.dart';

class ScenarioSearchScreen extends ConsumerStatefulWidget {
  const ScenarioSearchScreen({super.key});

  @override
  ConsumerState<ScenarioSearchScreen> createState() =>
      _ScenarioSearchScreenState();
}

class _ScenarioSearchScreenState extends ConsumerState<ScenarioSearchScreen> {
  final _controller = TextEditingController();
  List<ScenarioPassage> _passages = [];
  bool _isLoading = false;
  String? _error;
  String _submittedQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final auth = ref.read(authProvider);
    final settings = ref.read(settingsProvider);

    setState(() {
      _isLoading = true;
      _error = null;
      _passages = [];
      _submittedQuery = input;
    });

    try {
      final passages = await OpenAIService.instance.searchByScenario(
        scenario: input,
        language: settings.language,
        isPremium: auth.user?.isPremium ?? false,
      );

      // Fetch verse texts from local DB
      final enriched = <ScenarioPassage>[];
      for (final p in passages) {
        final verse = await BibleDatabase.instance.getVerseByReference(
          translation: settings.translation,
          reference: p.reference,
        );
        enriched.add(
          ScenarioPassage(
            reference: p.reference,
            explanation: p.explanation,
            verseData: verse,
          ),
        );
      }

      setState(() {
        _passages = enriched;
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        final msg = e.response?.data is Map<String, dynamic>
            ? (e.response!.data['message']?.toString() ??
                  e.message ??
                  'Erro ao buscar passagens.')
            : (e.message ?? 'Erro ao buscar passagens.');
        _error = msg;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _error = settings.language == 'pt'
            ? 'Erro ao buscar passagens. Verifica tua ligação à internet.'
            : 'Error fetching passages. Check your internet connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header — full when empty, compact when results exist
              if (_passages.isEmpty && !_isLoading) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isPT ? 'Busca por Cenário' : 'Scenario Search',
                            style: theme.textTheme.headlineMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isPT
                            ? 'Descreve a tua situação e encontrarei versículos relevantes'
                            : 'Describe your situation and I will find relevant verses',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      TextField(
                        controller: _controller,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: isPT
                              ? 'Descreve a tua situação ou o que estás a sentir...'
                              : 'Describe your situation or what you are feeling...',
                          hintMaxLines: 3,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: isPT ? 'Encontrar Passagens' : 'Find Passages',
                          icon: Icons.auto_awesome,
                          onPressed: _isLoading ? null : _search,
                          isLoading: _isLoading,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isPT
                            ? '5 buscas por semana no plano gratuito · Premium ilimitado'
                            : '5 searches per week on free plan · Unlimited on Premium',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.ac.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Compact bar — shows query + edit button
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.ac.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.ac.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _submittedQuery,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.ac.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _passages = [];
                          _error = null;
                        }),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          isPT ? 'Editar' : 'Edit',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Results
              Expanded(
                child: _isLoading
                    ? AILoadingWidget(
                        message: isPT
                            ? 'Buscando versículos...'
                            : 'Searching for verses...',
                      )
                    : _error != null
                    ? _buildError()
                    : _passages.isEmpty
                    ? _buildEmptyState(isPT)
                    : _buildResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.ac.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isPT) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: AppColors.primary.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              isPT
                  ? 'Escreve o que estás a sentir\ne eu encontrarei os versículos certos'
                  : 'Write what you\'re feeling\nand I will find the right verses',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.ac.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      itemCount: _passages.length,
      itemBuilder: (context, index) {
        return VerseCard(
          passage: _passages[index],
          onViewContext: () => _showHistoricalContext(_passages[index]),
        );
      },
    );
  }

  void _showHistoricalContext(ScenarioPassage passage) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HistoricalContextSheet(passage: passage),
    );
  }
}

class _HistoricalContextSheet extends ConsumerStatefulWidget {
  final ScenarioPassage passage;

  const _HistoricalContextSheet({required this.passage});

  @override
  ConsumerState<_HistoricalContextSheet> createState() =>
      _HistoricalContextSheetState();
}

class _HistoricalContextSheetState
    extends ConsumerState<_HistoricalContextSheet> {
  String? _context;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    final auth = ref.read(authProvider);

    try {
      // Parse book and chapter from reference
      final parts = widget.passage.reference.split(' ');
      final chapterVerse = parts.last.split(':');
      final book = parts.sublist(0, parts.length - 1).join(' ');
      final chapter = int.tryParse(chapterVerse.first) ?? 1;

      final result = await OpenAIService.instance.getHistoricalContext(
        book: book,
        chapter: chapter,
        language: settings.language,
        isPremium: auth.user?.isPremium ?? false,
      );

      if (mounted) {
        setState(() {
          _context = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).extension<AppAdaptiveColors>()!.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              child: Text(
                'Contexto Histórico — ${widget.passage.reference}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _context == null
                  ? const Center(child: Text('Erro ao carregar contexto.'))
                  : SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                      child: _ContextContent(raw: _context!),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextContent extends StatelessWidget {
  final String raw;

  const _ContextContent({required this.raw});

  @override
  Widget build(BuildContext context) {
    try {
      // Parse JSON context
      final json = _parseJson(raw);
      if (json == null) return Text(raw);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (json['timePeriod'] != null)
            _ContextItem(
              icon: Icons.schedule,
              label: 'Período',
              text: json['timePeriod'].toString(),
            ),
          if (json['author'] != null)
            _ContextItem(
              icon: Icons.person,
              label: 'Autor',
              text: json['author'].toString(),
            ),
          if (json['audience'] != null)
            _ContextItem(
              icon: Icons.groups,
              label: 'Destinatários',
              text: json['audience'].toString(),
            ),
          if (json['geographicContext'] != null)
            _ContextItem(
              icon: Icons.location_on,
              label: 'Contexto Geográfico',
              text: json['geographicContext'].toString(),
            ),
          if (json['purpose'] != null)
            _ContextItem(
              icon: Icons.lightbulb_outline,
              label: 'Propósito',
              text: json['purpose'].toString(),
            ),
          if (json['summary'] != null)
            _ContextItem(
              icon: Icons.summarize,
              label: 'Resumo',
              text: json['summary'].toString(),
            ),
        ],
      );
    } catch (_) {
      return Text(raw);
    }
  }

  Map<String, dynamic>? _parseJson(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class _ContextItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _ContextItem({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.ac.surface,
          borderRadius: BorderRadius.circular(12),
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
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.ac.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
