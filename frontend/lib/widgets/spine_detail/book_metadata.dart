import 'package:flutter/material.dart';
import 'package:shelf_scanner/models/book_result.dart';

// ── BookMetadata ──────────────────────────────────────────────────────────────

/// Right-column widget in the spine card: cover art thumbnail, title, authors,
/// meta chips, description, and category chips.
class BookMetadata extends StatelessWidget {
  final BookResult book;
  final bool descExpanded;
  final VoidCallback onToggleDesc;

  const BookMetadata({
    super.key,
    required this.book,
    required this.descExpanded,
    required this.onToggleDesc,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cover image + title/author row ─────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover art thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: book.coverUrl.isNotEmpty
                  ? Image.network(
                      book.coverUrl,
                      width: 64,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(),
                    )
                  : _coverPlaceholder(),
            ),
            const SizedBox(width: 10),

            // Title + authors
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.authors.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      book.authors.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w500,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Meta chips (year, rating, match)
        const SizedBox(height: 10),
        MetaChips(book: book),

        // Description
        if (book.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            book.description,
            maxLines: descExpanded ? 100 : 4,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        //   GestureDetector(
        //     onTap: onToggleDesc,
        //     child: Text(
        //       descExpanded ? 'Show less' : 'Read more',
        //       style: TextStyle(
        //         color: cs.primary,
        //         fontSize: 12,
        //         fontWeight: FontWeight.w500,
        //       ),
        //     ),
        //   ),
        ],

        // Category chips
        if (book.categories.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: book.categories
                .take(3)
                .map((c) => CategoryChip(label: c))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 64,
        height: 92,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.menu_book, size: 28, color: Colors.grey),
      );
}

// ── MetaChips ─────────────────────────────────────────────────────────────────

/// Row of compact icon+label chips for rating, year, and match score.
class MetaChips extends StatelessWidget {
  final BookResult book;
  const MetaChips({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chips = <Widget>[];

    if (book.avgRating != null) {
      chips.add(_chip(
        context,
        Icons.star_rounded,
        Colors.amber.shade600,
        book.avgRating!.toStringAsFixed(1),
      ));
    }
    if (book.year.isNotEmpty) {
      chips.add(
          _chip(context, Icons.calendar_today, cs.primary, book.year));
    }
    if (book.matchScore != null) {
      chips.add(_chip(
        context,
        Icons.analytics_outlined,
        Colors.green.shade700,
        '${(book.matchScore! * 100).round()}% match',
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }

  Widget _chip(BuildContext ctx, IconData icon, Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── CategoryChip ──────────────────────────────────────────────────────────────

/// Small genre/category label chip.
class CategoryChip extends StatelessWidget {
  final String label;
  const CategoryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cs.onPrimaryContainer,
              fontSize: 10,
            ),
      ),
    );
  }
}
