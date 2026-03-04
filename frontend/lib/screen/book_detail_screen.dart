
import 'package:flutter/material.dart';
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/services/liked_books_store.dart';
import 'package:shelf_scanner/widgets/book_result_sheet.dart';

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
      if (mounted)
        setState(() => _matchError = 'Could not load personalisation');
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
          _HeroCover(book: book),

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
                _MetaRow(book: book),

                const SizedBox(height: 20),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    _LikeButton(book: book),
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
                _PersonalisationCard(
                  loading: _loadingMatch,
                  match: _match,
                  error: _matchError,
                  hasLikedBooks: LikedBooksStore.instance.count > 0,
                ),

                const SizedBox(height: 28),

                // ── Should you read it? ────────────────────────────────────
                _DecisionCard(book: book),

                const SizedBox(height: 28),

                // ── Description ────────────────────────────────────────────
                if (book.description.isNotEmpty) ...[
                  _SectionTitle('About This Book'),
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
                  _SectionTitle('Genres'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: book.categories
                        .map((c) => Chip(
                              label: Text(c,
                                  style: const TextStyle(fontSize: 12)),
                              backgroundColor: cs.primaryContainer,
                              labelStyle: TextStyle(
                                  color: cs.onPrimaryContainer),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 28),
                ],

                // ── Most similar liked book ────────────────────────────────
                if (_match?.topSimilarLiked != null) ...[
                  _SectionTitle('Because You Liked'),
                  const SizedBox(height: 10),
                  _SimilarBookTile(book: _match!.topSimilarLiked!),
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

// ── Hero Cover ────────────────────────────────────────────────────────────────

class _HeroCover extends StatelessWidget {
  final BookResult book;
  const _HeroCover({required this.book});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.black87,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background
            if (book.coverUrl.isNotEmpty)
              Image.network(
                book.coverUrl,
                fit: BoxFit.cover,
                color: Colors.black45,
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, __, ___) =>
                    Container(color: Colors.grey.shade900),
              )
            else
              Container(color: Colors.grey.shade900),
            // Centred cover on top
            Center(
              child: Hero(
                tag: 'book-cover-${book.isbn}',
                child: book.coverUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          book.coverUrl,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        ),
                      )
                    : _placeholder(),
              ),
            ),
            // Bottom gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        height: 200,
        width: 130,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.menu_book, size: 60, color: Colors.white54),
      );
}

// ── Meta chips ────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final BookResult book;
  const _MetaRow({required this.book});

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

// ── Like button ───────────────────────────────────────────────────────────────

class _LikeButton extends StatefulWidget {
  final BookResult book;
  const _LikeButton({required this.book});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
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

// ── NLP Personalisation card ──────────────────────────────────────────────────

class _PersonalisationCard extends StatelessWidget {
  final bool loading;
  final MatchResult? match;
  final String? error;
  final bool hasLikedBooks;

  const _PersonalisationCard({
    required this.loading,
    required this.match,
    required this.error,
    required this.hasLikedBooks,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!hasLikedBooks) {
      return _card(
        context,
        cs,
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Like books to unlock your personalised fit score.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    if (loading) {
      return _card(
        context,
        cs,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return _card(
        context,
        cs,
        child: Text('⚠️ $error',
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      );
    }

    if (match == null) return const SizedBox.shrink();

    final score = match!.fitScore;
    final pct = (score * 100).round();
    final color = score >= 0.75
        ? Colors.green
        : (score >= 0.5 ? Colors.amber.shade700 : Colors.grey);

    return _card(
      context,
      cs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personalised Fit  ·  ${match!.confidence.toUpperCase()}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Score bar
          Row(
            children: [
              Text('$pct%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      )),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score,
                    backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // NLP explanation
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              match!.whyYouLikeIt,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.55),
            ),
          ),

          // Shared genres
          if (match!.themeMatch.sharedCategories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: match!.themeMatch.sharedCategories
                  .take(4)
                  .map((c) => Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        backgroundColor: color.withValues(alpha: 0.12),
                        labelStyle: TextStyle(color: color),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, ColorScheme cs,
      {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

// ── "Should You Read It?" decision card ──────────────────────────────────────

class _DecisionCard extends StatelessWidget {
  final BookResult book;
  const _DecisionCard({required this.book});

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
        border: Border.all(color: cs.primaryContainer.withValues(alpha: 0.6)),
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
          ...signals.map((s) => _SignalRow(signal: s)),
        ],
      ),
    );
  }

  List<_Signal> _buildSignals() {
    final signals = <_Signal>[];

    // Rating signal
    if (book.avgRating != null) {
      final r = book.avgRating!;
      if (r >= 4.2) {
        signals.add(_Signal(
            icon: Icons.star_rounded,
            color: Colors.amber.shade700,
            label: 'Highly Rated',
            detail: '${r.toStringAsFixed(1)} / 5.0'));
      } else if (r >= 3.5) {
        signals.add(_Signal(
            icon: Icons.star_half_rounded,
            color: Colors.amber.shade400,
            label: 'Well Rated',
            detail: '${r.toStringAsFixed(1)} / 5.0'));
      } else {
        signals.add(_Signal(
            icon: Icons.star_outline_rounded,
            color: Colors.grey,
            label: 'Mixed Reviews',
            detail: '${r.toStringAsFixed(1)} / 5.0'));
      }
    }

    // Popularity signal
    if (book.ratingCount != null && book.ratingCount! > 1000) {
      signals.add(_Signal(
          icon: Icons.people_alt_rounded,
          color: Colors.blue.shade600,
          label: 'Popular',
          detail:
              '${(book.ratingCount! / 1000).toStringAsFixed(1)}k ratings'));
    }

    // Description length as depth proxy
    final words = book.description.split(' ').length;
    if (words > 80) {
      signals.add(_Signal(
          icon: Icons.auto_stories_rounded,
          color: Colors.purple.shade600,
          label: 'Rich Content',
          detail: 'Detailed synopsis available'));
    }

    // Category count as diversity proxy
    if (book.categories.length >= 2) {
      signals.add(_Signal(
          icon: Icons.category_rounded,
          color: Colors.teal.shade600,
          label: 'Multi-genre',
          detail: book.categories.take(2).join(', ')));
    }

    if (signals.isEmpty) {
      signals.add(_Signal(
          icon: Icons.help_outline_rounded,
          color: Colors.grey,
          label: 'Limited info',
          detail: 'Not enough data to evaluate'));
    }

    return signals;
  }
}

class _Signal {
  final IconData icon;
  final Color color;
  final String label;
  final String detail;
  const _Signal(
      {required this.icon,
      required this.color,
      required this.label,
      required this.detail});
}

class _SignalRow extends StatelessWidget {
  final _Signal signal;
  const _SignalRow({required this.signal});

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

// ── Similar liked book tile ───────────────────────────────────────────────────

class _SimilarBookTile extends StatelessWidget {
  final BookResult book;
  const _SimilarBookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
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
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BookResultSheet(book: book),
        ),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

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
