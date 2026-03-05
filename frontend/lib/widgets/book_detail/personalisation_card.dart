import 'package:flutter/material.dart';
import 'package:shelf_scanner/models/match_result.dart';

/// NLP personalisation card showing fit score, explanation, and shared genres.
class PersonalisationCard extends StatelessWidget {
  final bool loading;
  final MatchResult? match;
  final String? error;
  final bool hasLikedBooks;

  const PersonalisationCard({
    super.key,
    required this.loading,
    required this.match,
    required this.error,
    required this.hasLikedBooks,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!hasLikedBooks) {
      return _card(
        context,
        cs,
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Like books to unlock your personalised fit score.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    if (loading) {
      return _card(
        context,
        cs,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return _card(
        context,
        cs,
        child: Text('⚠️ $error',
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      );
    }

    if (match == null) return const SizedBox.shrink();

    final score = match!.fitScore;
    final pct = (score * 100).round();
    final color = score >= 0.75
        ? Colors.green
        : (score >= 0.5 ? Colors.amber.shade700 : Colors.grey);

    return _card(
      context,
      cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personalised Fit  ·  ${match!.confidence.toUpperCase()}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Score bar
          Row(
            children: [
              Text('$pct%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      )),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // NLP explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              match!.whyYouLikeIt,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.55),
            ),
          ),

          // Shared genres
          if (match!.themeMatch.sharedCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: match!.themeMatch.sharedCategories
                  .take(4)
                  .map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        backgroundColor: color.withValues(alpha: 0.12),
                        labelStyle: TextStyle(color: color),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, ColorScheme cs,
      {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}
