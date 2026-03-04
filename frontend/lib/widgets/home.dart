import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero card ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_stories, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  'ShelfScanner',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Point your camera at any bookshelf.\nGet instant details & personalised picks.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/live'),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Start Scanning'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          Text('How it works',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ── Step cards ────────────────────────────────────────────────────
          ..._steps.map((s) => _StepCard(step: s)),

          const SizedBox(height: 28),
          Text('Tips',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._tips.map((t) => _TipRow(text: t)),
        ],
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

const _steps = [
  (icon: Icons.camera_alt_rounded, title: 'Scan',      body: 'Open the camera and point at a bookshelf. YOLO detects each spine in real-time.'),
  (icon: Icons.text_snippet_rounded, title: 'Read',    body: 'Our OCR engine reads the title & author from each detected spine.'),
  (icon: Icons.auto_awesome_rounded, title: 'Discover',body: 'Get instant metadata, ratings, and personalised "books like this" recommendations.'),
  (icon: Icons.favorite_rounded, title: 'Save',        body: 'Like any book to save it to your Library for later review.'),
];

const _tips = [
  '💡 Hold the phone steady — live mode works best in good lighting.',
  '📚 Tap "Get Recommendation" after capturing a photo for detailed results.',
  '🔍 Tilted or worn spines? Try angling the phone slightly.',
];

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  final ({IconData icon, String title, String body}) step;
  const _StepCard({required this.step});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(step.icon, color: cs.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(step.body,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey.shade600, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String text;
  const _TipRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(height: 1.5, color: Colors.grey.shade700)),
    );
  }
}
