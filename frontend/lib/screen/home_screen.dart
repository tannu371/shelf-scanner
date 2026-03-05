import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shelf_scanner/services/yolo_service.dart';
import 'package:shelf_scanner/widgets/home.dart';
import 'package:shelf_scanner/widgets/settings.dart';
import 'package:shelf_scanner/widgets/library.dart';
import 'package:shelf_scanner/widgets/profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _screens = [
    Home(),
    Library(),
    Profile(),
    Settings(),
  ];

  static const _labels = ['Home', 'Library', 'Profile', 'Settings'];

  static const _icons = [
    Icons.home_rounded,
    Icons.local_library_rounded,
    Icons.person_rounded,
    Icons.settings_rounded,
  ];

  static const _activeIcons = [
    Icons.home_rounded,
    Icons.local_library_rounded,
    Icons.person_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Row(
          children: [
            Icon(Icons.auto_stories, color: cs.primary, size: 26),
            const SizedBox(width: 8),
            Text(
              _labels[_selectedIndex],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        actions: const [
          // Import an image from the gallery directly from the AppBar
          _ImportButton(),
          SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        indicatorColor: cs.primaryContainer,
        destinations: List.generate(
          _labels.length,
          (i) => NavigationDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_activeIcons[i], color: cs.onPrimaryContainer),
            label: _labels[i],
          ),
        ),
      ),
      // Centre FAB — camera (live scan)
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/live'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        tooltip: 'Scan the Shelf',
        child: const Icon(Icons.camera_alt_rounded),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// ── Import button ─────────────────────────────────────────────────────────────

/// AppBar action that lets the user pick a shelf photo from the gallery
/// and feeds it through the same YOLO + recommendation pipeline as the camera.
class _ImportButton extends StatefulWidget {
  const _ImportButton();

  @override
  State<_ImportButton> createState() => _ImportButtonState();
}

class _ImportButtonState extends State<_ImportButton> {
  final _picker = ImagePicker();
  YoloService? _vision; // lazy — only created on first tap
  bool _busy = false;

  Future<void> _pickImage() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) return;

      // Show loading indicator while model loads
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Loading model…'),
                ],
              ),
            ),
          ),
        ),
      );

      // Lazily load the YOLO model once
      _vision ??= YoloService();
      await _vision!.loadModel(
        modelPath: 'assets/models/yolov11-2.tflite',
        numThreads: 2,
        useGpu: false,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loader

      await Navigator.pushNamed(
        context,
        '/preview',
        arguments: {'imageFile': file, 'visionModel': _vision},
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // dismiss loader if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: _busy
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: cs.primary),
            )
          : SvgPicture.asset(
              'assets/icons/gallery-import.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(cs.primary, BlendMode.srcIn),
            ),
      tooltip: 'Import from Gallery',
      onPressed: _busy ? null : _pickImage,
    );
  }
}
