import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';

import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/settings_provider.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _confirmDeleteAccount(bool isPT) async {
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isPT ? 'Eliminar conta' : 'Delete account'),
        content: Text(
          isPT
              ? 'Esta ação elimina permanentemente a tua conta e os teus sermões guardados. Esta ação não pode ser desfeita.'
              : 'This permanently deletes your account and your saved sermons. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isPT ? 'Cancelar' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isPT ? 'Eliminar' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await ref.read(authProvider.notifier).deleteAccount();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (isPT
                    ? 'Conta eliminada com sucesso.'
                    : 'Account deleted successfully.')
              : (ref.read(authProvider).error ??
                    (isPT
                        ? 'Não foi possível eliminar a conta.'
                        : 'Could not delete account.')),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(isPT ? 'Definições' : 'Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account section
          _SectionHeader(title: isPT ? 'Conta' : 'Account'),
          if (auth.isLoggedIn) ...[
            _SettingsTile(
              icon: Icons.person_outline,
              title: auth.user!.email,
              subtitle: auth.user!.name.isNotEmpty ? auth.user!.name : null,
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.logout_rounded,
              title: isPT ? 'Terminar Sessão' : 'Sign Out',
              onTap: () => ref.read(authProvider.notifier).logout(),
              titleColor: AppColors.error,
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.delete_forever_rounded,
              title: isPT ? 'Eliminar Conta' : 'Delete Account',
              subtitle: isPT
                  ? 'Apaga a tua conta e os dados associados'
                  : 'Delete your account and associated data',
              onTap: auth.isLoading ? null : () => _confirmDeleteAccount(isPT),
              titleColor: AppColors.error,
            ),
          ] else ...[
            _SettingsTile(
              icon: Icons.login_rounded,
              title: isPT ? 'Entrar / Criar Conta' : 'Sign In / Create Account',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Limits
          _SectionHeader(title: isPT ? 'Limites do Plano' : 'Plan Limits'),
          Container(
            decoration: BoxDecoration(
              color: context.ac.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.ac.cardBorder),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _limitRow(
                  context,
                  label: isPT ? 'Busca por cenário' : 'Scenario search',
                  quota: isPT ? '5 / semana' : '5 / week',
                ),
                _limitRow(
                  context,
                  label: isPT ? 'Gerar esboço' : 'Generate outline',
                  quota: isPT ? '4 / mês' : '4 / month',
                ),
                _limitRow(
                  context,
                  label: isPT ? 'Explicar versículo' : 'Explain verse',
                  quota: isPT ? '20 / dia' : '20 / day',
                ),
                _limitRow(
                  context,
                  label: isPT ? 'Estudo de palavras' : 'Word study',
                  quota: isPT ? '10 / dia' : '10 / day',
                ),
                _limitRow(
                  context,
                  label: isPT ? 'Contexto histórico' : 'Historical context',
                  quota: isPT ? '15 / dia' : '15 / day',
                ),
                _limitRow(
                  context,
                  label: isPT ? 'Tutor bíblico' : 'Bible tutor',
                  quota: isPT ? '30 / dia' : '30 / day',
                ),
                _limitRow(
                  context,
                  label: isPT ? 'Biblioteca' : 'Library',
                  quota: isPT ? '5 sermões' : '5 sermons',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Language
          _SectionHeader(title: isPT ? 'Idioma' : 'Language'),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: isPT ? 'Idioma do App' : 'App Language',
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pt', label: Text('PT')),
                ButtonSegment(value: 'en', label: Text('EN')),
              ],
              selected: {settings.language},
              onSelectionChanged: (val) {
                ref.read(settingsProvider.notifier).setLanguage(val.first);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Appearance
          _SectionHeader(title: isPT ? 'Aparência' : 'Appearance'),
          Container(
            decoration: BoxDecoration(
              color: context.ac.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.ac.cardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.dark_mode_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPT ? 'Tema' : 'Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: context.ac.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(
                              Icons.light_mode_rounded,
                              size: 16,
                            ),
                            label: Text(isPT ? 'Claro' : 'Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode_rounded, size: 16),
                            label: Text(isPT ? 'Escuro' : 'Dark'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(
                              Icons.settings_suggest_rounded,
                              size: 16,
                            ),
                            label: Text(isPT ? 'Auto' : 'Auto'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (val) => ref
                            .read(settingsProvider.notifier)
                            .setThemeMode(val.first),
                        expandedInsets: EdgeInsets.zero,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Reading
          _SectionHeader(title: isPT ? 'Leitura' : 'Reading'),
          _SettingsTile(
            icon: Icons.format_size_rounded,
            title: isPT ? 'Tamanho da Fonte' : 'Font Size',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: settings.fontSize > 12
                      ? () => ref
                            .read(settingsProvider.notifier)
                            .setFontSize(settings.fontSize - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.primary,
                ),
                Text(
                  '${settings.fontSize.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  onPressed: settings.fontSize < 28
                      ? () => ref
                            .read(settingsProvider.notifier)
                            .setFontSize(settings.fontSize + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.primary,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About
          _SectionHeader(title: isPT ? 'Sobre' : 'About'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.ac.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.ac.cardBorder),
            ),
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
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shalom Bible',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: context.ac.textPrimary,
                          ),
                        ),
                        Text('v1.0.0', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  isPT ? 'A nossa missão' : 'Our mission',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPT
                      ? 'A Bíblia foi escrita originalmente em hebraico, aramaico e grego — línguas com estruturas e nuances muito diferentes das nossas. '
                            'Palavras como hesed (amor leal em hebraico) ou agape (amor incondicional em grego) carregam profundidades que as traduções modernas nem sempre conseguem transmitir na totalidade.\n\n'
                            'A isto acrescenta-se a distância histórica e cultural: costumes, figuras de linguagem e referências do Oriente Próximo antigo que eram óbvias para os leitores originais podem parecer estranhas hoje. '
                            'E a Bíblia contém géneros literários muito distintos — poesia, profecia, lei, narrativa, carta — que pedem leituras diferentes.\n\n'
                            'O Shalom Bible existe para tornar esse conhecimento acessível a qualquer pessoa. '
                            'Sem impor uma denominação, sem julgamentos — apenas explicações honestas, contexto real e espaço para as tuas próprias perguntas.\n\n'
                            'O nosso desejo é simples: que quem abre a Bíblia a compreenda melhor, '
                            'e que esse entendimento traga mais liberdade e uma fé mais consciente.'
                      : 'The Bible was originally written in Hebrew, Aramaic, and Greek — languages with structures and nuances very different from our own. '
                            'Words like hesed (loyal love in Hebrew) or agape (unconditional love in Greek) carry depths that modern translations don\'t always fully convey.\n\n'
                            'Add to this the historical and cultural distance: customs, figures of speech, and references from the ancient Near East that were obvious to original readers can feel strange today. '
                            'And the Bible contains very distinct literary genres — poetry, prophecy, law, narrative, letter — each requiring a different kind of reading.\n\n'
                            'Shalom Bible exists to make this knowledge accessible to anyone. '
                            'Without imposing a denomination, without judgment — just honest explanations, real context, and space for your own questions.\n\n'
                            'Our desire is simple: that whoever opens the Bible understands it better, '
                            'and that understanding brings more freedom and a more informed faith.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: context.ac.textSecondary,
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

Widget _limitRow(
  BuildContext context, {
  required String label,
  required String quota,
}) {
  final ac = context.ac;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: ac.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            quota,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.ac.textSecondary,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.ac.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.ac.cardBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppColors.primary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: titleColor ?? context.ac.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: context.ac.textSecondary),
              )
            : null,
        trailing:
            trailing ??
            (onTap != null
                ? Icon(
                    Icons.chevron_right_rounded,
                    color: context.ac.textSecondary,
                  )
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
