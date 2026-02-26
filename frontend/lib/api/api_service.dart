import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

// ── Base URL config ──────────────────────────────────────────────────────────
// Android emulator  → 10.0.2.2 reaches the host machine's localhost
// Physical device   → replace with your computer's LAN IP (e.g. 192.168.1.10)
// Production        → set to your deployed API URL
const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

// ── Data models ─────────────────────────────────────────────────────────────

class BookResult {
  final String isbn;
  final String title;
  final List<String> authors;
  final String publisher;
  final String year;
  final String description;
  final List<String> categories;
  final String coverUrl;
  final double? avgRating;
  final int? ratingCount;
  final double? matchScore;

  const BookResult({
    required this.isbn,
    required this.title,
    required this.authors,
    required this.publisher,
    required this.year,
    required this.description,
    required this.categories,
    required this.coverUrl,
    this.avgRating,
    this.ratingCount,
    this.matchScore,
  });

  factory BookResult.fromJson(Map<String, dynamic> json) {
    return BookResult(
      isbn: json['isbn'] as String? ?? '',
      title: json['title'] as String? ?? 'Unknown Title',
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      publisher: json['publisher'] as String? ?? '',
      year: json['year'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      coverUrl: json['cover_url'] as String? ?? '',
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      ratingCount: json['rating_count'] as int?,
      matchScore: (json['match_score'] as num?)?.toDouble(),
    );
  }
}

// ── API Service ──────────────────────────────────────────────────────────────

class ApiService {
  static final _client = http.Client();
  static const _timeout = Duration(seconds: 20);

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
        .timeout(_timeout);

    _checkStatus(response, '/scan');
    return _parseBookList(response.body);
  }

  // ── POST /search ───────────────────────────────────────────────────────────
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
        .catchError((e) => null);
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
