import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/sermon_model.dart';
import '../../data/remote/api_client.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/providers/settings_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<SermonModel> _sermons = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiClient.instance.getSermons(query: query);
      final list = (data['sermons'] as List<dynamic>)
          .map((s) => SermonModel.fromJson(s as Map<String, dynamic>))
          .toList();
      setState(() {
        _sermons = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar biblioteca.';
      });
    }
  }

  Future<void> _delete(SermonModel sermon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Sermão'),
        content: Text(
          'Eliminar "${sermon.title}"? Esta acção não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && sermon.id != null) {
      try {
        await ApiClient.instance.deleteSermon(sermon.id!);
        setState(() => _sermons.removeWhere((s) => s.id == sermon.id));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Sermão eliminado.')));
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao eliminar.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';
    final theme = Theme.of(context);

    ref.listen<int>(libraryRefreshProvider, (prev, next) {
      if (prev != next && auth.isLoggedIn) {
        _load(query: _searchQuery.isNotEmpty ? _searchQuery : null);
      }
    });

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.isLoggedIn != next.isLoggedIn) {
        if (next.isLoggedIn) {
          _load(query: _searchQuery.isNotEmpty ? _searchQuery : null);
        } else {
          setState(() {
            _sermons = [];
            _loading = false;
            _error = null;
          });
        }
      }
    });

    if (!auth.isLoggedIn) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.library_books_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isPT ? 'Biblioteca de Sermões' : 'Sermon Library',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPT
                        ? 'Cria uma conta para guardar e aceder\naos teus esboços de sermão.'
                        : 'Create an account to save and access\nyour sermon outlines.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to auth screen
                    },
                    child: Text(
                      isPT
                          ? 'Entrar / Criar Conta'
                          : 'Sign In / Create Account',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.library_books_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPT ? 'Biblioteca' : 'Library',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${_sermons.length} ${isPT ? 'sermões' : 'sermons'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _load(query: val.isNotEmpty ? val : null);
                },
                decoration: InputDecoration(
                  hintText: isPT ? 'Pesquisar sermões...' : 'Search sermons...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _load();
                          },
                        )
                      : null,
                ),
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                  ? Center(child: Text(_error!))
                  : _sermons.isEmpty
                  ? _buildEmptyState(isPT)
                  : RefreshIndicator(
                      onRefresh: () => _load(
                        query: _searchQuery.isNotEmpty ? _searchQuery : null,
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: _sermons.length,
                        itemBuilder: (context, index) {
                          return _SermonCard(
                            sermon: _sermons[index],
                            isPT: isPT,
                            onTap: () => _openSermon(_sermons[index]),
                            onDelete: () => _delete(_sermons[index]),
                          );
                        },
                      ),
                    ),
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
              Icons.library_books_outlined,
              size: 64,
              color: AppColors.primary.withAlpha(80),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? (isPT
                        ? 'Nenhum sermão encontrado para "$_searchQuery"'
                        : 'No sermons found for "$_searchQuery"')
                  : (isPT
                        ? 'A tua biblioteca está vazia.\nGera o teu primeiro esboço!'
                        : 'Your library is empty.\nGenerate your first outline!'),
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

  void _openSermon(SermonModel sermon) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SermonDetailSheet(sermon: sermon),
    );
  }
}

class _SermonCard extends StatelessWidget {
  final SermonModel sermon;
  final bool isPT;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SermonCard({
    required this.sermon,
    required this.isPT,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.ac.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ac.cardBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sermon.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sermon.basePassage.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sermon.basePassage,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      sermon.createdAt != null
                          ? DateFormatter.formatRelative(sermon.createdAt!)
                          : '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textSecondary,
                ),
                onSelected: (val) {
                  if (val == 'delete') onDelete();
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(isPT ? 'Eliminar' : 'Delete'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SermonDetailSheet extends StatelessWidget {
  final SermonModel sermon;

  const _SermonDetailSheet({required this.sermon});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Container(
        decoration: BoxDecoration(
          color: ac.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sermon.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (sermon.basePassage.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      sermon.basePassage,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailSection(
                      title: 'Introdução',
                      content: sermon.content.introduction,
                    ),
                    ...sermon.content.points.asMap().entries.map(
                      (e) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ponto ${e.key + 1}: ${e.value.title}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            e.value.development,
                            style: const TextStyle(height: 1.6),
                          ),
                          if (e.value.supportingVerses.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              e.value.supportingVerses.join(' • '),
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    _DetailSection(
                      title: 'Conclusão',
                      content: sermon.content.conclusion,
                    ),
                    _DetailSection(
                      title: 'Oração de Encerramento',
                      content: sermon.content.closingPrayer,
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

class _DetailSection extends StatelessWidget {
  final String title;
  final String content;

  const _DetailSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(content, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 16),
      ],
    );
  }
}
