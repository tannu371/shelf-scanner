import 'package:flutter/material.dart';
import 'package:shelf_scanner/models/book_result.dart';

// ── DecisionCard ──────────────────────────────────────────────────────────────

/// "Should You Read It?" card — heuristic signals about rating, popularity,
/// content depth, and genre diversity.
class DecisionCard extends StatelessWidget {
  final BookResult book;
  const DecisionCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final signals = _buildSignals();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.4),
            cs.secondaryContainer.withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: cs.primaryContainer.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded,
                  color: cs.primary, size: 22),
              const SizedBox(width: 8),
              Text('Should You Read It?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
            ],
          ),
          const SizedBox(height: 14),
          ...signals.map((s) => SignalRow(signal: s)),
        ],
      ),
    );
  }

  List<BookSignal> _buildSignals() {
    final signals = <BookSignal>[];

    // Rating signal
    if (book.avgRating != null) {
      final r = book.avgRating!;
      if (r >= 4.2) {
        signals.add(BookSignal(
            icon: Icons.star_rounded,
            color: Colors.amber.shade700,
            label: 'Highly Rated',
            detail: '${r.toStringAsFixed(1)} / 5.0'));
      } else if (r >= 3.5) {
        signals.add(BookSignal(
            icon: Icons.star_half_rounded,
            color: Colors.amber.shade400,
            label: 'Well Rated',
            detail: '${r.toStringAsFixed(1)} / 5.0'));
      } else {
        signals.add(BookSignal(
            icon: Icons.star_outline_rounded,
            color: Colors.grey,
            label: 'Mixed Reviews',
            detail: '${r.toStringAsFixed(1)} / 5.0'));
      }
    }

    // Popularity signal
    if (book.ratingCount != null && book.ratingCount! > 1000) {
      signals.add(BookSignal(
          icon: Icons.people_alt_rounded,
          color: Colors.blue.shade600,
          label: 'Popular',
          detail:
              '${(book.ratingCount! / 1000).toStringAsFixed(1)}k ratings'));
    }

    // Description length as depth proxy
    final words = book.description.split(' ').length;
    if (words > 80) {
      signals.add(BookSignal(
          icon: Icons.auto_stories_rounded,
          color: Colors.purple.shade600,
          label: 'Rich Content',
          detail: 'Detailed synopsis available'));
    }

    // Category count as diversity proxy
    if (book.categories.length >= 2) {
      signals.add(BookSignal(
          icon: Icons.category_rounded,
          color: Colors.teal.shade600,
          label: 'Multi-genre',
          detail: book.categories.take(2).join(', ')));
    }

    if (signals.isEmpty) {
      signals.add(const BookSignal(
          icon: Icons.help_outline_rounded,
          color: Colors.grey,
          label: 'Limited info',
          detail: 'Not enough data to evaluate'));
    }

    return signals;
  }
}

// ── BookSignal ────────────────────────────────────────────────────────────────

class BookSignal {
  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  const BookSignal({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
  });
}

// ── SignalRow ─────────────────────────────────────────────────────────────────

class SignalRow extends StatelessWidget {
  final BookSignal signal;
  const SignalRow({super.key, required this.signal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(signal.icon, color: signal.color, size: 18),
          const SizedBox(width: 8),
          Text(signal.label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              signal.detail,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
