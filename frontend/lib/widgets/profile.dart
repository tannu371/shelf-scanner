import 'package:flutter/material.dart';
import 'package:shelf_scanner/services/liked_books_store.dart';

class Profile extends StatefulWidget {
  const Profile({super.key});

  @override
  State<Profile> createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {
  final _store = LikedBooksStore.instance;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final likedCount = _store.count;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
      child: Column(
        children: [
          // ── Avatar ───────────────────────────────────────────────────────
          CircleAvatar(
            radius: 48,
            backgroundColor: cs.primaryContainer,
            child: Icon(Icons.person_rounded,
                size: 50, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 14),
          Text('Book Lover',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('ShelfScanner Reader',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade500)),

          const SizedBox(height: 28),

          // ── Stats row ─────────────────────────────────────────────────────
          Row(
            children: [
              _StatCard(
                icon: Icons.favorite_rounded,
                label: 'Liked',
                value: '$likedCount',
                color: Colors.pinkAccent,
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.camera_alt_rounded,
                label: 'Scans',
                value: '—',
                color: cs.primary,
              ),
              const SizedBox(width: 12),
              _StatCard(
                icon: Icons.auto_awesome_rounded,
                label: 'Discovered',
                value: '—',
                color: Colors.amber.shade700,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Liked genres ─────────────────────────────────────────────────
          if (likedCount > 0) ...[
            _sectionTitle(context, 'Your Genres'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _genres(context),
            ),
            const SizedBox(height: 28),
          ],

          // ── Quick actions ─────────────────────────────────────────────────
          _sectionTitle(context, 'Quick Actions'),
          const SizedBox(height: 10),
          _ActionTile(
            icon: Icons.camera_alt_rounded,
            label: 'Scan a Shelf',
            onTap: () => Navigator.pushNamed(context, '/live'),
          ),
          _ActionTile(
            icon: Icons.local_library_rounded,
            label: 'View My Library',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _genres(BuildContext context) {
    final categories = _store.books
        .expand((b) => b.categories)
        .toSet()
        .take(8)
        .toList();

    if (categories.isEmpty) {
      return [
        Chip(
          label: const Text('General'),
          backgroundColor:
              Theme.of(context).colorScheme.primaryContainer,
        )
      ];
    }

    return categories
        .map((c) => Chip(
              label: Text(c,
                  style: const TextStyle(fontSize: 12)),
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
            ))
        .toList();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}