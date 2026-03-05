import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shelf_scanner/screen/home_screen.dart';
import 'package:shelf_scanner/screen/preview_screen.dart';
import 'package:shelf_scanner/screen/live_detection_screen.dart';
import 'package:shelf_scanner/screen/book_detail_screen.dart';
import 'package:shelf_scanner/screen/book_spine_detail_screen.dart';
import 'package:shelf_scanner/api/api_service.dart' show SpineEntry, BookResult;
import 'package:shelf_scanner/services/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static TextTheme _buildTextTheme(Brightness brightness) =>
      GoogleFonts.caveatBrushTextTheme(
        ThemeData(brightness: brightness).textTheme,
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeProvider.instance,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,

          // ── Light theme ────────────────────────────────────────────────
          theme: ThemeData(
            brightness: Brightness.light,
            textTheme: _buildTextTheme(Brightness.light),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.black,
              brightness: Brightness.light,
            ),
          ),

          // ── Dark theme ─────────────────────────────────────────────────
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            textTheme: _buildTextTheme(Brightness.dark),
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurpleAccent,
              brightness: Brightness.dark,
            ),
          ),

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
            '/book-detail': (context) {
              final book = ModalRoute.of(context)!.settings.arguments
                  as BookResult;
              return BookDetailScreen(book: book);
            },
            '/book-spine-detail': (context) {
              final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
              return BookSpineDetailScreen(
                entries: args['entries'] as List<SpineEntry>,
                userId: args['userId'] as String?,
              );
            },
          },
          title: 'BookShelf Scanner',
          home: const HomeScreen(),
        );
      },
    );
  }
}
