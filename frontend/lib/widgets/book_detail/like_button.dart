import 'package:flutter/material.dart';
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/services/liked_books_store.dart';

/// Stateful Like button for the BookDetailScreen.
class LikeButton extends StatefulWidget {
  final BookResult book;
  const LikeButton({super.key, required this.book});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool get _liked => LikedBooksStore.instance.isLiked(widget.book.isbn);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(_liked ? Icons.favorite : Icons.favorite_outline,
          color: _liked ? Colors.pinkAccent : null),
      label: Text(_liked ? 'Liked' : 'Like'),
      style: _liked
          ? OutlinedButton.styleFrom(
              foregroundColor: Colors.pinkAccent,
              side: const BorderSide(color: Colors.pinkAccent))
          : null,
      onPressed: () {
        LikedBooksStore.instance.toggle(widget.book);
        ApiService.logFeedback(widget.book.isbn, _liked ? 'like' : 'unlike');
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _liked ? '❤️ Added to Library!' : 'Removed from Library'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ));
      },
    );
  }
}
