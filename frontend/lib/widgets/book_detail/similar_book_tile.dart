import 'package:flutter/material.dart';
import 'package:shelf_scanner/models/book_result.dart';

/// Tile showing a "similar liked book" on the BookDetailScreen.
/// Tapping opens the [BookResultSheet] bottom sheet.
class SimilarBookTile extends StatelessWidget {
  final BookResult book;
  const SimilarBookTile({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: book.coverUrl.isNotEmpty
              ? Image.network(book.coverUrl,
                  width: 42, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _ph())
              : _ph(),
        ),
        title: Text(book.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(book.authors.join(', '),
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: book.matchScore != null
            ? Text(
                '${(book.matchScore! * 100).round()}%',
                style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold),
              )
            : null,
        onTap: () {
          Navigator.pushNamed(
            context,
            '/book-detail',
            arguments: book,
          );
        },
      ),
    );
  }

  Widget _ph() => Container(
        width: 42,
        height: 60,
        color: Colors.grey.shade300,
        child: const Icon(Icons.menu_book, size: 20, color: Colors.grey),
      );
}
