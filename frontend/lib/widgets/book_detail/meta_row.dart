import 'package:flutter/material.dart';
import 'package:shelf_scanner/models/book_result.dart';

/// Row of compact info chips (year, publisher, rating, match score).
class MetaRow extends StatelessWidget {
  final BookResult book;
  const MetaRow({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (book.year.isNotEmpty) _chip(context, Icons.calendar_today, book.year),
        if (book.publisher.isNotEmpty)
          _chip(context, Icons.business_outlined, book.publisher),
        if (book.avgRating != null)
          _chip(context, Icons.star_rounded,
              '${book.avgRating!.toStringAsFixed(1)} / 5'
              '${book.ratingCount != null ? '  (${_formatCount(book.ratingCount!)})' : ''}'),
        if (book.matchScore != null)
          _chip(context, Icons.analytics_outlined,
              '${(book.matchScore! * 100).round()}% scan match'),
      ],
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: cs.primary),
          const SizedBox(width: 5),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurface)),
        ],
      ),
    );
  }

  String _formatCount(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}
