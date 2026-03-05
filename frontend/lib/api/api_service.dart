import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shelf_scanner/models/book_result.dart';
import 'package:shelf_scanner/models/match_result.dart';

// Re-export models so existing imports like:
//   import 'package:shelf_scanner/api/api_service.dart' show BookResult, SpineEntry;
// continue to work with zero changes in the rest of the codebase.
export 'package:shelf_scanner/models/book_result.dart';
export 'package:shelf_scanner/models/spine_entry.dart';
export 'package:shelf_scanner/models/match_result.dart';

// ── Base URL config ──────────────────────────────────────────────────────────
// Android emulator  → use 10.0.2.2:8000 (emulator localhost alias)
// Physical device   → use your Mac's LAN IP so the phone can reach it over WiFi
//                     Run: `ipconfig getifaddr en0` on your Mac to get it.
// Production        → set to your deployed API URL
//
// Pass via: flutter run --dart-define=API_BASE_URL=http://192.168.1.113:8000
const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.1.113:8000', // Mac LAN IP — run `ipconfig getifaddr en0` to confirm
);

// ── API Service ──────────────────────────────────────────────────────────────

class ApiService {
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 30);         // normal endpoints
  static const _scanTimeout = Duration(seconds: 120);    // /scan: first request downloads PaddleOCR models (~60s)

  // ── POST /scan ─────────────────────────────────────────────────────────────
  /// Send raw image bytes of a detected book spine to the backend.
  /// Returns a list of matching book candidates.
  static Future<List<BookResult>> scanSpine(
    Uint8List imageBytes, {
    String? userId,
  }) async {
    final body = json.encode({
      'image_b64': base64Encode(imageBytes),
      if (userId != null) 'user_id': userId,
    });

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/scan'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(_scanTimeout);

    _checkStatus(response, '/scan');
    return _parseBookList(response.body);
  }

  // ── POST /match ─────────────────────────────────────────────────────────────
  /// Personalised fit score: cosine similarity between `isbn` and the user's
  /// liked books' SBERT embeddings (computed server-side with pgvector).
  static Future<MatchResult> matchBook(
    String isbn,
    List<String> likedIsbns, {
    String? userId,
  }) async {
    final body = json.encode({
      'isbn': isbn,
      'liked_isbns': likedIsbns,
      if (userId != null) 'user_id': userId,
    });

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/match'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(_timeout);

    _checkStatus(response, '/match');
    return MatchResult.fromJson(
        json.decode(response.body) as Map<String, dynamic>);
  }

  /// Search by OCR text string (title + author). Used when text is
  /// already extracted on-device.
  static Future<List<BookResult>> search(
    String ocrText, {
    String? userId,
  }) async {
    final body = json.encode({
      'ocr_text': ocrText,
      if (userId != null) 'user_id': userId,
    });

    final response = await _client
        .post(
          Uri.parse('$_baseUrl/search'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(_timeout);

    _checkStatus(response, '/search');
    return _parseBookList(response.body);
  }

  // ── GET /recommend ─────────────────────────────────────────────────────────
  /// Fetch Top-K similar books for a given ISBN using pgvector KNN.
  static Future<List<BookResult>> recommend(
    String isbn, {
    String? userId,
    int limit = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl/recommend').replace(queryParameters: {
      'isbn': isbn,
      'limit': '$limit',
      if (userId != null) 'user_id': userId,
    });

    final response = await _client.get(uri).timeout(_timeout);
    _checkStatus(response, '/recommend');
    return _parseBookList(response.body);
  }

  // ── POST /log_feedback ─────────────────────────────────────────────────────
  /// Log user action for HITL retraining (confirm / like / skip).
  static Future<void> logFeedback(
    String isbn,
    String action, {
    String? userId,
    String? ocrRawText,
    String? spineImageB64,
  }) async {
    final body = json.encode({
      'isbn': isbn,
      'action': action,
      if (userId != null) 'user_id': userId,
      if (ocrRawText != null) 'ocr_raw_text': ocrRawText,
      if (spineImageB64 != null) 'spine_image_b64': spineImageB64,
    });

    // Fire-and-forget — don't block the UI on feedback logging
    _client
        .post(
          Uri.parse('$_baseUrl/log_feedback'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(_timeout)
        .ignore();
  }

  // ── GET /metadata/{isbn} ───────────────────────────────────────────────────
  static Future<BookResult> getMetadata(String isbn) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/metadata/$isbn'))
        .timeout(_timeout);
    _checkStatus(response, '/metadata');
    return BookResult.fromJson(json.decode(response.body) as Map<String, dynamic>);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static void _checkStatus(http.Response response, String endpoint) {
    if (response.statusCode >= 400) {
      final detail = _tryParseDetail(response.body);
      throw ApiException(
        statusCode: response.statusCode,
        message: detail ?? 'Request to $endpoint failed',
      );
    }
  }

  static List<BookResult> _parseBookList(String body) {
    final data = json.decode(body);
    if (data is List) {
      return data
          .map((e) => BookResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  static String? _tryParseDetail(String body) {
    try {
      final decoded = json.decode(body);
      if (decoded is Map && decoded.containsKey('detail')) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return null;
  }
}

// ── Exception ────────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;
  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
