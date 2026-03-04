import 'package:flutter/material.dart';
import 'package:shelf_scanner/services/theme_provider.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool get _darkMode => ThemeProvider.instance.isDark;
  bool _notifications = true;
  double _confThreshold = 0.5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App section ──────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          _SettingsTile(
            icon: Icons.dark_mode_rounded,
            label: 'Dark Mode',
            subtitle: _darkMode ? 'On' : 'Off',
            trailing: Switch(
              value: _darkMode,
              onChanged: (_) {
                ThemeProvider.instance.toggle();
                setState(() {});
              },
            ),
          ),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            label: 'Notifications',
            subtitle: 'Book tips & updates',
            trailing: Switch(
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
            ),
          ),

          const SizedBox(height: 24),
          _SectionHeader('Detection'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: cs.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confidence Threshold',
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text(
                        '${(_confThreshold * 100).round()}%  — lower = more detections, higher = fewer false positives',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: _confThreshold,
            min: 0.2,
            max: 0.9,
            divisions: 14,
            label: '${(_confThreshold * 100).round()}%',
            onChanged: (v) => setState(() => _confThreshold = v),
          ),

          const SizedBox(height: 24),
          _SectionHeader('Network'),
          _SettingsTile(
            icon: Icons.cloud_rounded,
            label: 'API Server',
            subtitle: 'Tap to view configured URL',
            onTap: () => _showApiDialog(context),
          ),
          _SettingsTile(
            icon: Icons.timer_outlined,
            label: 'Scan Timeout',
            subtitle: '120 s  (first request downloads OCR models ~60 s)',
          ),

          const SizedBox(height: 24),
          _SectionHeader('About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            label: 'ShelfScanner',
            subtitle: 'v1.0.0 · AI-powered book detection',
          ),
          _SettingsTile(
            icon: Icons.code_rounded,
            label: 'Stack',
            subtitle:
                'Flutter · FastAPI · YOLOv11 · PaddleOCR · pgvector',
          ),
          _SettingsTile(
            icon: Icons.school_rounded,
            label: 'Capstone Project',
            subtitle: 'Built as part of an academic capstone',
          ),
        ],
      ),
    );
  }

  void _showApiDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('API URL'),
        content: const Text(
          'Configured via --dart-define=API_BASE_URL.\n\n'
          'Default: http://192.168.1.113:8000\n\n'
          'Run:\n  ipconfig getifaddr en0\nto find your Mac\'s LAN IP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: cs.primary, size: 22),
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        subtitle: subtitle != null
            ? Text(subtitle!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade500))
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded, color: Colors.grey)
                : null),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}