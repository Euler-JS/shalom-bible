import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/openai_service.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/settings_provider.dart';
import '../auth/auth_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  bool _hasApiKey = false;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkApiKey() async {
    final has = await OpenAIService.instance.hasApiKey();
    if (mounted) setState(() => _hasApiKey = has);
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) return;
    await OpenAIService.instance.saveApiKey(key);
    _apiKeyCtrl.clear();
    setState(() => _hasApiKey = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Chave API guardada.'),
            backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final isPT = settings.language == 'pt';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isPT ? 'Definições' : 'Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account section
          _SectionHeader(title: isPT ? 'Conta' : 'Account'),
          if (auth.isLoggedIn) ...[
            _SettingsTile(
              icon: Icons.person_outline,
              title: auth.user!.email,
              subtitle:
                  '${auth.user!.plan == 'premium' ? 'Premium' : 'Plano Gratuito'} · ${auth.user!.name}',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: auth.user!.isPremium
                      ? AppColors.secondary.withAlpha(30)
                      : AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  auth.user!.plan == 'premium' ? 'Premium' : 'Free',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: auth.user!.isPremium
                        ? const Color(0xFF8B6914)
                        : AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.logout_rounded,
              title: isPT ? 'Terminar Sessão' : 'Sign Out',
              onTap: () => ref.read(authProvider.notifier).logout(),
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
                Text('${settings.fontSize.toInt()}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
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

          // OpenAI API Key
          _SectionHeader(title: 'OpenAI API Key'),
          Container(
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
                    Icon(
                      _hasApiKey
                          ? Icons.check_circle_rounded
                          : Icons.key_rounded,
                      color: _hasApiKey ? AppColors.success : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _hasApiKey
                          ? (isPT ? 'Chave API configurada' : 'API key configured')
                          : (isPT
                              ? 'Chave API não configurada'
                              : 'API key not configured'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            _hasApiKey ? AppColors.success : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isPT
                      ? 'Necessária para usar as funcionalidades de IA. Obtém a tua chave em platform.openai.com'
                      : 'Required to use AI features. Get your key at platform.openai.com',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: _obscureApiKey,
                  decoration: InputDecoration(
                    hintText: 'sk-...',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(_obscureApiKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscureApiKey = !_obscureApiKey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveApiKey,
                    child: Text(isPT ? 'Guardar Chave' : 'Save Key'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Backend URL (for developers)
          _SectionHeader(title: isPT ? 'Avançado' : 'Advanced'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Shalom Bible v1.0.0',
            subtitle: isPT ? 'Desenvolvido com Flutter + AI' : 'Built with Flutter + AI',
          ),
        ],
      ),
    );
  }
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
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppColors.primary, size: 22),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: titleColor ?? AppColors.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary))
            : null,
        trailing: trailing ?? (onTap != null
            ? const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary)
            : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
