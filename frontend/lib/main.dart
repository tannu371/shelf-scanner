import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shelf_scanner/screen/home_screen.dart';
import 'package:shelf_scanner/screen/preview_screen.dart';
import 'package:shelf_scanner/screen/live_detection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => const HomeScreen(),
        '/live': (context) => const LiveDetectionScreen(),
        '/preview': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return PreviewScreen(
            imageFile: args['imageFile'],
            visionModel: args['visionModel'],
          );
        },
      },
      title: 'BookShelf scanner',
      theme: ThemeData(
        textTheme: GoogleFonts.caveatBrushTextTheme(),
        // textTheme: GoogleFonts.dmSerifDisplayTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
