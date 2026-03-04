import 'package:flutter/material.dart';
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
        actions: [
          // Camera shortcut in top-right
          IconButton(
            icon: Icon(Icons.camera_alt_rounded, color: cs.primary),
            tooltip: 'Scan a shelf',
            onPressed: () => Navigator.pushNamed(context, '/live'),
          ),
          const SizedBox(width: 4),
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
      // Centre FAB for scanning
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
