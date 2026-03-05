import 'package:flutter/material.dart';
import 'package:shelf_scanner/api/api_service.dart';
import 'package:shelf_scanner/widgets/spine_detail/spine_image.dart';
import 'package:shelf_scanner/widgets/spine_detail/book_metadata.dart';
import 'package:shelf_scanner/widgets/spine_detail/action_buttons.dart';
import 'package:shelf_scanner/widgets/spine_detail/similar_section.dart';

/// Stateful card for a single detected spine.
/// Fetches its own similar-books recommendations.
class SpineCard extends StatefulWidget {
  final SpineEntry entry;
  final int index;
  final String? userId;
  final SimilarViewMode viewMode;
  final ValueChanged<SimilarViewMode> onViewModeChanged;

  const SpineCard({
    super.key,
    required this.entry,
    required this.index,
    required this.viewMode,
    required this.onViewModeChanged,
    this.userId,
  });

  @override
  State<SpineCard> createState() => _SpineCardState();
}

class _SpineCardState extends State<SpineCard> {
  List<BookResult> _similar = [];
  bool _loadingSimilar = false;
  String? _similarError;
  bool _descExpanded = false;

  BookResult get book => widget.entry.book;

  @override
  void initState() {
    super.initState();
    _loadSimilar();
    ApiService.logFeedback(book.isbn, 'confirm', userId: widget.userId);
  }

  Future<void> _loadSimilar() async {
    setState(() {
      _loadingSimilar = true;
      _similarError = null;
    });
    try {
      final recs = await ApiService.recommend(book.isbn, userId: widget.userId);
      if (mounted) setState(() => _similar = recs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _similarError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _similarError = 'Could not load recommendations');
      }
    } finally {
      if (mounted) setState(() => _loadingSimilar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Spine index label (only when multiple) ───────────────────────
          if (widget.index > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Spine ${widget.index + 1}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
              ),
            ),

          // ── Top row: spine image + book metadata ─────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: cropped spine image
                SpineImage(spineBytes: widget.entry.spineBytes),

                const SizedBox(width: 16),

                // Right: metadata
                Expanded(
                  child: BookMetadata(
                    book: book,
                    descExpanded: _descExpanded,
                    onToggleDesc: () =>
                        setState(() => _descExpanded = !_descExpanded),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── View full details ─────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('View Full Details'),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/book-detail',
                  arguments: book,
                );
              },
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          SpineActionButtons(book: book, userId: widget.userId),

          const SizedBox(height: 20),

          // ── Similar Books ─────────────────────────────────────────────────
          Text(
            'Similar Books',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SimilarSection(
            books: _similar,
            loading: _loadingSimilar,
            error: _similarError,
            userId: widget.userId,
            viewMode: widget.viewMode,
            onViewModeChanged: widget.onViewModeChanged,
          ),
        ],
      ),
    );
  }
}
