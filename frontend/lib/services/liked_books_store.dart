import 'package:flutter/foundation.dart';
import 'package:shelf_scanner/api/api_service.dart';

/// In-memory store for liked books.
/// Accessed as a singleton via [LikedBooksStore.instance].
/// Widgets that need reactivity should wrap with [ValueListenableBuilder].
class LikedBooksStore extends ChangeNotifier {
  LikedBooksStore._();
  static final LikedBooksStore instance = LikedBooksStore._();

  final List<BookResult> _books = [];

  List<BookResult> get books => List.unmodifiable(_books);

  bool isLiked(String isbn) => _books.any((b) => b.isbn == isbn);

  void toggle(BookResult book) {
    if (isLiked(book.isbn)) {
      _books.removeWhere((b) => b.isbn == book.isbn);
    } else {
      _books.insert(0, book);
    }
    notifyListeners();
  }

  int get count => _books.length;
}
