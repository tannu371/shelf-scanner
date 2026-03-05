import 'package:flutter/material.dart';
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/screen/book_detail_screen.dart';

// ── View mode (public so BookSpineDetailScreen can own the state) ─────────────

enum SimilarViewMode { card, list }

// ── SimilarSection ────────────────────────────────────────────────────────────

/// Shows similar-book recommendations with a **list / card toggle**.
///
/// The view-mode state is owned by the parent (BookSpineDetailScreen) so that
/// toggling on one tab applies to every tab.
///
/// • Card mode — horizontal scrollable rail of 120px cards
/// • List  mode — vertical list of compact tiles
class SimilarSection extends StatelessWidget {
  final List<BookResult> books;
  final bool loading;
  final String? error;
  final String? userId;
  final SimilarViewMode viewMode;
  final ValueChanged<SimilarViewMode> onViewModeChanged;

  const SimilarSection({
    super.key,
    required this.books,
    required this.loading,
    required this.viewMode,
    required this.onViewModeChanged,
    this.error,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    // ── Loading / error / empty states ────────────────────────────────────
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text(error!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center),
      );
    }
    if (books.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No recommendations yet — scan more books to personalise your feed!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toggle row ───────────────────────────────────────────────────
        Row(
          children: [
            Text(
              '${books.length} similar books',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            _ToggleButton(
              icon: Icons.view_column_rounded,
              tooltip: 'Card view',
              selected: viewMode == SimilarViewMode.card,
              onTap: () => onViewModeChanged(SimilarViewMode.card),
            ),
            const SizedBox(width: 4),
            _ToggleButton(
              icon: Icons.view_list_rounded,
              tooltip: 'List view',
              selected: viewMode == SimilarViewMode.list,
              onTap: () => onViewModeChanged(SimilarViewMode.list),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Content ──────────────────────────────────────────────────────
        viewMode == SimilarViewMode.card
            ? _CardRail(books: books, userId: userId)
            : _ListRail(books: books, userId: userId),
      ],
    );
  }
}

// ── Toggle button ─────────────────────────────────────────────────────────────

class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? cs.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Card rail (horizontal) ────────────────────────────────────────────────────

class _CardRail extends StatelessWidget {
  final List<BookResult> books;
  final String? userId;
  const _CardRail({required this.books, this.userId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) =>
            SimilarBookCard(book: books[i], userId: userId),
      ),
    );
  }
}

// ── List rail (vertical) ──────────────────────────────────────────────────────

class _ListRail extends StatelessWidget {
  final List<BookResult> books;
  final String? userId;
  const _ListRail({required this.books, this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: books
          .map((b) => _SimilarListTile(book: b, userId: userId))
          .toList(),
    );
  }
}

// ── SimilarBookCard ───────────────────────────────────────────────────────────

class SimilarBookCard extends StatelessWidget {
  final BookResult book;
  final String? userId;
  const SimilarBookCard({super.key, required this.book, this.userId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        ApiService.logFeedback(book.isbn, 'confirm', userId: userId);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
        );
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: book.coverUrl.isNotEmpty
                  ? Image.network(book.coverUrl,
                      width: 120, height: 110, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder())
                  : _coverPlaceholder(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w600, height: 1.2)),
                    const Spacer(),
                    Row(
                      children: [
                        if (book.avgRating != null) ...[
                          Icon(Icons.star_rounded,
                              size: 11, color: Colors.amber.shade600),
                          const SizedBox(width: 2),
                          Text(book.avgRating!.toStringAsFixed(1),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: cs.onSurfaceVariant)),
                          const Spacer(),
                        ],
                        if (book.matchScore != null)
                          Text(
                            '${(book.matchScore! * 100).round()}%',
                            style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 10),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() => Container(
        width: 120,
        height: 110,
        color: Colors.grey.shade300,
        child: const Icon(Icons.menu_book, size: 32, color: Colors.grey),
      );
}

// ── SimilarListTile ───────────────────────────────────────────────────────────

class _SimilarListTile extends StatelessWidget {
  final BookResult book;
  final String? userId;
  const _SimilarListTile({required this.book, this.userId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        ApiService.logFeedback(book.isbn, 'confirm', userId: userId);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: book.coverUrl.isNotEmpty
                  ? Image.network(book.coverUrl,
                      width: 44, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ph())
                  : _ph(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (book.authors.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(book.authors.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                  if (book.avgRating != null) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      Icon(Icons.star_rounded,
                          size: 13, color: Colors.amber.shade600),
                      const SizedBox(width: 3),
                      Text(book.avgRating!.toStringAsFixed(1),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ]),
                  ],
                ],
              ),
            ),
            if (book.matchScore != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(book.matchScore! * 100).round()}%',
                  style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _ph() => Container(
        width: 44,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.menu_book, size: 20, color: Colors.grey),
      );
}
