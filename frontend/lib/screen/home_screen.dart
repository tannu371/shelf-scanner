import 'package:flutter/material.dart';
import 'package:shelf_scanner/widgets/home.dart';
import 'package:shelf_scanner/widgets/settings.dart';
import 'package:shelf_scanner/widgets/library.dart';
import 'package:shelf_scanner/widgets/profile.dart';
// import 'package:flutter_speed_dial/flutter_speed_dial.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Widget> _screens = [
    const Home(),
    const Settings(),
    const Library(),
    const Profile()
  ];
  int _selectedScreen = 0;

  Widget _icons(
    IconData icon,
    int index,
  ) {
    final selected = _selectedScreen == index;
    return IconButton(
      onPressed: () => setState(() => _selectedScreen = index),
      icon: Icon(
        icon,
        color: selected
            ? Theme.of(context).primaryColor
            : Theme.of(context).primaryColorLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'BookShelf Scanner',
          style: TextStyle(fontSize: 32, color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: _screens[_selectedScreen],
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _icons(Icons.home, 0),
              _icons(Icons.settings_sharp, 1),
              FloatingActionButton(
                onPressed: () {
                  setState(() {
                    Navigator.pushNamed(context, '/live');
                  });
                },
                child: const Icon(
                  Icons.camera_alt,
                ),
              ),
              _icons(Icons.local_library_rounded, 2),
              _icons(Icons.person, 3),
            ],
          ),
        ),
      ),
    );
  }
}
