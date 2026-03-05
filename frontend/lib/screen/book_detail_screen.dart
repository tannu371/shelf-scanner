import 'package:flutter/material.dart';
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/services/liked_books_store.dart';
import 'package:shelf_scanner/widgets/book_detail/hero_cover.dart';
import 'package:shelf_scanner/widgets/book_detail/meta_row.dart';
import 'package:shelf_scanner/widgets/book_detail/like_button.dart';
import 'package:shelf_scanner/widgets/book_detail/personalisation_card.dart';
import 'package:shelf_scanner/widgets/book_detail/decision_card.dart';
import 'package:shelf_scanner/widgets/book_detail/similar_book_tile.dart';
import 'package:shelf_scanner/widgets/book_detail/section_title.dart';

/// Full-page detail view for a single book.
/// Shows rich metadata + NLP-powered personalisation card (fit score, why).
class BookDetailScreen extends StatefulWidget {
  final BookResult book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  MatchResult? _match;
  bool _loadingMatch = false;
  String? _matchError;

  bool _descExpanded = false;

  BookResult get book => widget.book;

  @override
  void initState() {
    super.initState();
    _loadMatch();
  }

  Future<void> _loadMatch() async {
    final liked = LikedBooksStore.instance.books;
    final likedIsbns =
        liked.where((b) => b.isbn != book.isbn).map((b) => b.isbn).toList();

    if (likedIsbns.isEmpty) return; // no history yet — skip

    setState(() {
      _loadingMatch = true;
      _matchError = null;
    });
    try {
      final result = await ApiService.matchBook(book.isbn, likedIsbns);
      if (mounted) setState(() => _match = result);
    } on ApiException catch (e) {
      if (mounted) setState(() => _matchError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _matchError = 'Could not load personalisation');
      }
    } finally {
      if (mounted) setState(() => _loadingMatch = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero AppBar ───────────────────────────────────────────────────
          HeroCover(book: book),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Title + authors
                const SizedBox(height: 20),
                Text(
                  book.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.25,
                      ),
                ),
                if (book.authors.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    book.authors.join(' · '),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],

                const SizedBox(height: 16),

                // Meta chips row
                MetaRow(book: book),

                const SizedBox(height: 20),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    LikeButton(book: book),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Sharing: ${book.title}')),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── NLP Personalisation card ───────────────────────────────
                PersonalisationCard(
                  loading: _loadingMatch,
                  match: _match,
                  error: _matchError,
                  hasLikedBooks: LikedBooksStore.instance.count > 0,
                ),

                const SizedBox(height: 28),

                // ── Should you read it? ────────────────────────────────────
                DecisionCard(book: book),

                const SizedBox(height: 28),

                // ── Description ────────────────────────────────────────────
                if (book.description.isNotEmpty) ...[
                  const SectionTitle('About This Book'),
                  const SizedBox(height: 10),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: _descExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Text(
                      book.description,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.6),
                    ),
                    secondChild: Text(
                      book.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(height: 1.6),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _descExpanded = !_descExpanded),
                    child: Text(_descExpanded ? 'Show less' : 'Read more'),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Categories ─────────────────────────────────────────────
                if (book.categories.isNotEmpty) ...[
                  const SectionTitle('Genres'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: book.categories
                        .map((c) => Chip(
                              label: Text(c,
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: cs.primaryContainer,
                              labelStyle:
                                  TextStyle(color: cs.onPrimaryContainer),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Most similar liked book ────────────────────────────────
                if (_match?.topSimilarLiked != null) ...[
                  const SectionTitle('Because You Liked'),
                  const SizedBox(height: 10),
                  SimilarBookTile(book: _match!.topSimilarLiked!),
                  const SizedBox(height: 16),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
