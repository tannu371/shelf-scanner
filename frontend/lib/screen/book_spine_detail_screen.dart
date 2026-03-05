import 'package:flutter/material.dart';
import 'package:shelf_scanner/models/spine_entry.dart';
import 'package:shelf_scanner/widgets/spine_detail/spine_card.dart';
import 'package:shelf_scanner/widgets/spine_detail/similar_section.dart';

/// Full-screen page shown after a shelf scan.
///
/// Each detected spine gets its own **tab** — swipe or tap to switch.
/// When only one spine is found, the tab bar is hidden.
///
///   ┌──────────────────────────────────────────┐
///   │  ←  N Books Found                        │
///   ├──────────────────────────────────────────┤
///   │  [Book A]  [Book B]  [Book C]  ←tabs→   │
///   ├──────────────────────────────────────────┤
///   │  [SpineCard for selected tab]            │
///   └──────────────────────────────────────────┘
class BookSpineDetailScreen extends StatefulWidget {
  final List<SpineEntry> entries;
  final String? userId;

  const BookSpineDetailScreen({
    super.key,
    required this.entries,
    this.userId,
  });

  @override
  State<BookSpineDetailScreen> createState() => _BookSpineDetailScreenState();
}

class _BookSpineDetailScreenState extends State<BookSpineDetailScreen> {
  /// Shared view-mode for Similar Books — toggling on any tab updates all tabs.
  SimilarViewMode _viewMode = SimilarViewMode.card;

  List<SpineEntry> get entries => widget.entries;
  String? get userId => widget.userId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool multipleSpines = entries.length > 1;

    // Single spine — no tab overhead needed
    if (!multipleSpines) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Column(
            children: [
              const _BackBar(total: 1),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                  child: SpineCard(
                    entry: entries.first,
                    index: 0,
                    userId: userId,
                    viewMode: _viewMode,
                    onViewModeChanged: (m) => setState(() => _viewMode = m),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Multiple spines — one tab per spine
    return DefaultTabController(
      length: entries.length,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ─────────────────────────────────────────────────
              _BackBar(total: entries.length),

              // ── Tab bar ──────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  isScrollable: entries.length > 3,
                  tabAlignment: entries.length > 3
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  indicator: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: cs.onPrimary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  labelStyle: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  tabs: List.generate(entries.length, (i) {
                    // Truncate title to first two words for readability
                    final words =
                        entries[i].book.title.split(' ');
                    final label = words.length <= 2
                        ? entries[i].book.title
                        : '${words.take(2).join(' ')}…';
                    return Tab(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(label, maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    );
                  }),
                ),
              ),

              // ── Tab pages — each spine in its own scrollable page ────────
              Expanded(
                child: TabBarView(
                  children: List.generate(
                    entries.length,
                    (i) => SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
                      child: SpineCard(
                        entry: entries[i],
                        index: i,
                        userId: userId,
                        viewMode: _viewMode,
                        onViewModeChanged: (m) => setState(() => _viewMode = m),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Back bar ──────────────────────────────────────────────────────────────────

class _BackBar extends StatelessWidget {
  final int total;
  const _BackBar({required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Text(
            total == 1 ? 'Book Found' : '$total Books Found',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
