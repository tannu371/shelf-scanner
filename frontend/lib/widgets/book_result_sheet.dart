import 'package:flutter/material.dart';
import 'package:shelf_scanner/api/api_service.dart';

/// Draggable bottom sheet showing a detected book's details
/// and a "Similar Books" recommendations list.
class BookResultSheet extends StatefulWidget {
  final BookResult book;
  final String? userId;

  const BookResultSheet({super.key, required this.book, this.userId});

  @override
  State<BookResultSheet> createState() => _BookResultSheetState();
}

class _BookResultSheetState extends State<BookResultSheet> {
  List<BookResult> _recommendations = [];
  bool _loadingRecs = false;
  String? _recsError;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
    // Log that user confirmed this book
    ApiService.logFeedback(
      widget.book.isbn,
      'confirm',
      userId: widget.userId,
    );
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _loadingRecs = true;
      _recsError = null;
    });
    try {
      final recs = await ApiService.recommend(
        widget.book.isbn,
        userId: widget.userId,
      );
      if (mounted) setState(() => _recommendations = recs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _recsError = e.message);
    } catch (_) {
      if (mounted) setState(() => _recsError = 'Could not load recommendations');
    } finally {
      if (mounted) setState(() => _loadingRecs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [BoxShadow(blurRadius: 16, color: Colors.black26)],
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _DragHandle(),
              const SizedBox(height: 12),
              _BookHeader(book: widget.book),
              const SizedBox(height: 16),
              if (widget.book.description.isNotEmpty) ...[
                const _SectionLabel('Description'),
                const SizedBox(height: 6),
                Text(
                  widget.book.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
              ],
              _ActionRow(book: widget.book, userId: widget.userId),
              const SizedBox(height: 20),
              const _SectionLabel('Similar Books'),
              const SizedBox(height: 10),
              _RecommendationsList(
                books: _recommendations,
                loading: _loadingRecs,
                error: _recsError,
                userId: widget.userId,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _BookHeader extends StatelessWidget {
  final BookResult book;
  const _BookHeader({required this.book});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: book.coverUrl.isNotEmpty
              ? Image.network(
                  book.coverUrl,
                  width: 80,
                  height: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _PlaceholderCover(),
                )
              : _PlaceholderCover(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (book.authors.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  book.authors.join(', '),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (book.year.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  book.year,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
              if (book.avgRating != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${book.avgRating!.toStringAsFixed(1)}'
                      '${book.ratingCount != null ? ' (${book.ratingCount})' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceholderCover extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 120,
      color: Colors.grey.shade300,
      child: const Icon(Icons.menu_book, size: 40, color: Colors.grey),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final BookResult book;
  final String? userId;
  const _ActionRow({required this.book, this.userId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.favorite_outline),
            label: const Text('Like'),
            onPressed: () {
              ApiService.logFeedback(book.isbn, 'like', userId: userId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to your library!')),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () {
              // Share logic placeholder
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing: ${book.title}')),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecommendationsList extends StatelessWidget {
  final List<BookResult> books;
  final bool loading;
  final String? error;
  final String? userId;

  const _RecommendationsList({
    required this.books,
    required this.loading,
    this.error,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          error!,
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (books.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'No recommendations yet — scan more books to build your profile!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return Column(
      children: books
          .map((b) => _RecommendationTile(book: b, userId: userId))
          .toList(),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final BookResult book;
  final String? userId;
  const _RecommendationTile({required this.book, this.userId});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: book.coverUrl.isNotEmpty
            ? Image.network(
                book.coverUrl,
                width: 40,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(width: 40, height: 60, color: Colors.grey.shade300),
              )
            : Container(width: 40, height: 60, color: Colors.grey.shade300,
                child: const Icon(Icons.menu_book, size: 20, color: Colors.grey)),
      ),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        book.authors.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: book.matchScore != null
          ? Text(
              '${(book.matchScore! * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            )
          : null,
      onTap: () {
        ApiService.logFeedback(book.isbn, 'confirm', userId: userId);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => BookResultSheet(book: book, userId: userId),
        );
      },
    );
  }
}
