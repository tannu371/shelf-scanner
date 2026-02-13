import 'package:flutter/material.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Spacer(),
          Text(
            'Welcome to BookShelf Scanner!',
            style: TextStyle(fontSize: 24),
          ),
          Spacer(),
          Text(
            'Scan your book shelf by clicking the camera icon in the nav-bar.\nGet personalized recommendation & Save them for later review.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          Spacer(),
          Image(image: AssetImage('assets/images/bookshelf.png'), height: 250),
          Spacer(),
        ],
      ),
    );
  }
}
