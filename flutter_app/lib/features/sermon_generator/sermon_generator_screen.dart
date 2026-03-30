import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/sermon_model.dart';
import '../../data/remote/openai_service.dart';
import '../../data/remote/api_client.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/settings_provider.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/loading_overlay.dart';

class SermonGeneratorScreen extends ConsumerStatefulWidget {
  const SermonGeneratorScreen({super.key});

  @override
  ConsumerState<SermonGeneratorScreen> createState() =>
      _SermonGeneratorScreenState();
}

class _SermonGeneratorScreenState
    extends ConsumerState<SermonGeneratorScreen> {
  final _controller = TextEditingController();
  SermonContent? _content;
  String _generatedTitle = '';
  String _generatedPassage = '';
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final auth = ref.read(authProvider);
    final settings = ref.read(settingsProvider);

    // Check usage limits for logged-in users
    if (auth.isLoggedIn) {
      final allowed =
          await ApiClient.instance.incrementUsage('sermonGenerator');
      if (!allowed) {
        setState(() => _error = settings.language == 'pt'
            ? 'Limite mensal atingido (2 esboços). Actualiza para Premium.'
            : 'Monthly limit reached (2 outlines). Upgrade to Premium.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _content = null;
      _saved = false;
    });

    try {
      final content = await OpenAIService.instance.generateSermonOutline(
        input: input,
        language: settings.language,
        isPremium: auth.user?.isPremium ?? false,
      );

      // Try to extract title and passage from the raw JSON
      // The generateSermonOutline already parsed content but we need title/passage separately
      // Re-generate with JSON to get title/passage
      setState(() {
        _content = content;
        _generatedTitle = 'Esboço de Sermão';
        _generatedPassage = '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().contains('OpenAI API key not configured')
            ? 'Chave da API OpenAI não configurada. Vai às Definições.'
            : 'Erro ao gerar esboço. Verifica a tua ligação à internet.';
      });
    }
  }

  Future<void> _save() async {
    if (_content == null) return;
    final auth = ref.read(authProvider);
    final settings = ref.read(settingsProvider);

    if (!auth.isLoggedIn) {
      _showLoginRequired();
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ApiClient.instance.saveSermon({
        'title': _generatedTitle.isNotEmpty
            ? _generatedTitle
            : _controller.text.trim(),
        'basePassage': _generatedPassage,
        'language': settings.language,
        'inputPrompt': _controller.text.trim(),
        'content': _content!.toJson(),
      });
      setState(() {
        _isSaving = false;
        _saved = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esboço guardado na biblioteca!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao guardar. Tenta novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _copy() {
    if (_content == null) return;
    final text = _content!.toPlainText(
        _generatedTitle.isNotEmpty ? _generatedTitle : 'Esboço',
        _generatedPassage);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Esboço copiado!')),
    );
  }

  void _share() {
    if (_content == null) return;
    final text = _content!.toPlainText(
        _generatedTitle.isNotEmpty ? _generatedTitle : 'Esboço',
        _generatedPassage);
    Share.share(text, subject: _generatedTitle);
  }

  void _showLoginRequired() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conta necessária'),
        content: const Text(
            'Cria uma conta para guardar os teus esboços na biblioteca.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to login
            },
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPT ? 'Gerador de Esboço' : 'Sermon Generator',
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),

            // Input
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: isPT
                          ? 'Digite um tema, passagem ou situação para pregar...'
                          : 'Enter a theme, passage or situation to preach about...',
                      hintMaxLines: 3,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: isPT ? 'Gerar Esboço' : 'Generate Outline',
                      icon: Icons.auto_awesome,
                      onPressed: _isLoading ? null : _generate,
                      isLoading: _isLoading,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? AILoadingWidget(
                      message: isPT
                          ? 'A IA está a preparar o teu esboço...'
                          : 'AI is preparing your outline...',
                    )
                  : _error != null
                      ? _buildError()
                      : _content == null
                          ? _buildEmptyState(isPT)
                          : _buildOutline(isPT),
            ),
          ],
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
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
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
            Icon(Icons.auto_stories_outlined,
                size: 64, color: AppColors.primary.withAlpha(80)),
            const SizedBox(height: 16),
            Text(
              isPT
                  ? 'Descreve o tema ou passagem\ne a IA gerará um esboço completo'
                  : 'Describe the theme or passage\nand AI will generate a complete outline',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutline(bool isPT) {
    return Column(
      children: [
        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(isPT ? 'Copiar' : 'Copy'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(isPT ? 'Partilhar' : 'Share'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _generate,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(isPT ? 'Regenerar' : 'Regenerate'),
                ),
              ),
            ],
          ),
        ),

        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: _saved
                ? OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle, color: AppColors.success),
                    label: Text(
                        isPT ? 'Guardado na Biblioteca' : 'Saved to Library'),
                  )
                : AppButton(
                    label: isPT ? 'Guardar na Biblioteca' : 'Save to Library',
                    icon: Icons.bookmark_add_rounded,
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                    backgroundColor: AppColors.secondary,
                  ),
          ),
        ),

        // Sermon content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              if (_generatedTitle.isNotEmpty)
                _SectionCard(
                  icon: Icons.title_rounded,
                  label: isPT ? 'Título' : 'Title',
                  content: _generatedTitle,
                  isTitle: true,
                ),
              if (_generatedPassage.isNotEmpty)
                _SectionCard(
                  icon: Icons.menu_book_rounded,
                  label: isPT ? 'Texto Base' : 'Base Passage',
                  content: _generatedPassage,
                  accentColor: AppColors.secondary,
                ),
              _SectionCard(
                icon: Icons.record_voice_over_rounded,
                label: isPT ? 'Introdução' : 'Introduction',
                content: _content!.introduction,
              ),
              ...List.generate(_content!.points.length, (i) {
                final p = _content!.points[i];
                return _PointCard(
                  number: i + 1,
                  point: p,
                  isPT: isPT,
                );
              }),
              if (_content!.illustrations.isNotEmpty)
                _IllustrationsCard(
                  illustrations: _content!.illustrations,
                  isPT: isPT,
                ),
              _SectionCard(
                icon: Icons.campaign_rounded,
                label: isPT ? 'Conclusão' : 'Conclusion',
                content: _content!.conclusion,
              ),
              _SectionCard(
                icon: Icons.volunteer_activism_rounded,
                label: isPT ? 'Oração de Encerramento' : 'Closing Prayer',
                content: _content!.closingPrayer,
                accentColor: AppColors.secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String content;
  final bool isTitle;
  final Color? accentColor;

  const _SectionCard({
    required this.icon,
    required this.label,
    required this.content,
    this.isTitle = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: isTitle
                ? Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                    )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.7,
                    ),
          ),
        ],
      ),
    );
  }
}

class _PointCard extends StatelessWidget {
  final int number;
  final SermonPoint point;
  final bool isPT;

  const _PointCard({
    required this.number,
    required this.point,
    required this.isPT,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${isPT ? 'Ponto' : 'Point'} $number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            point.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            point.development,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.7),
          ),
          if (point.supportingVerses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: point.supportingVerses
                  .map((v) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.secondary.withAlpha(80)),
                        ),
                        child: Text(
                          v,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B6914),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _IllustrationsCard extends StatelessWidget {
  final List<String> illustrations;
  final bool isPT;

  const _IllustrationsCard({
    required this.illustrations,
    required this.isPT,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                isPT ? 'Ilustrações e Histórias' : 'Illustrations & Stories',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...illustrations.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.value,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
