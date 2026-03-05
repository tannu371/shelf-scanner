import 'package:flutter/material.dart';
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/services/liked_books_store.dart';

/// Like and Share action buttons for a single spine card.
class SpineActionButtons extends StatefulWidget {
  final BookResult book;
  final String? userId;
  const SpineActionButtons({super.key, required this.book, this.userId});

  @override
  State<SpineActionButtons> createState() => _SpineActionButtonsState();
}

class _SpineActionButtonsState extends State<SpineActionButtons> {
  bool get _liked => LikedBooksStore.instance.isLiked(widget.book.isbn);

  void _toggleLike() {
    LikedBooksStore.instance.toggle(widget.book);
    ApiService.logFeedback(
      widget.book.isbn,
      _liked ? 'like' : 'unlike',
      userId: widget.userId,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_liked ? '❤️ Added to Library!' : 'Removed from Library'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 1),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(
              _liked ? Icons.favorite : Icons.favorite_outline,
              size: 16,
            ),
            label: Text(_liked ? 'Liked' : 'Like',
                style: const TextStyle(fontSize: 13)),
            style: _liked
                ? OutlinedButton.styleFrom(
                    foregroundColor: Colors.pinkAccent,
                    side: const BorderSide(color: Colors.pinkAccent),
                  )
                : null,
            onPressed: _toggleLike,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Share', style: TextStyle(fontSize: 13)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing: ${widget.book.title}')),
              );
            },
          ),
        ),
      ],
    );
  }
}
