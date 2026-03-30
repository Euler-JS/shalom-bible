import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/bible_verse.dart';

class VerseCard extends StatelessWidget {
  final ScenarioPassage passage;
  final VoidCallback? onViewContext;
  final VoidCallback? onSave;

  const VerseCard({
    super.key,
    required this.passage,
    this.onViewContext,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reference header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  passage.reference,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verse text
                if (passage.verseData != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      passage.verseData!.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Explanation
                Text(
                  passage.explanation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 12),

                // Action buttons
                Row(
                  children: [
                    if (onViewContext != null)
                      TextButton.icon(
                        onPressed: onViewContext,
                        icon: const Icon(Icons.history_edu, size: 16),
                        label: const Text('Contexto'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    const Spacer(),
                    if (onSave != null)
                      IconButton(
                        onPressed: onSave,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        color: AppColors.secondary,
                        tooltip: 'Salvar',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
