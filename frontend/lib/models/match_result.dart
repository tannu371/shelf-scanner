import 'package:shelf_scanner/models/book_result.dart';

/// Shared-category theme overlap between a candidate book and liked books.
class ThemeMatch {
  final List<String> sharedCategories;
  final double overlapScore;

  const ThemeMatch({
    required this.sharedCategories,
    required this.overlapScore,
  });

  factory ThemeMatch.fromJson(Map<String, dynamic> j) => ThemeMatch(
        sharedCategories: (j['shared_categories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        overlapScore: (j['overlap_score'] as num?)?.toDouble() ?? 0,
      );
}

/// NLP-powered personalised fit result returned by `/match`.
class MatchResult {
  final String isbn;
  final double fitScore;       // 0.0 – 1.0 (NLP cosine similarity)
  final String confidence;     // "high" | "medium" | "low"
  final String whyYouLikeIt;  // NLP-generated sentence
  final ThemeMatch themeMatch;
  final BookResult? topSimilarLiked;

  const MatchResult({
    required this.isbn,
    required this.fitScore,
    required this.confidence,
    required this.whyYouLikeIt,
    required this.themeMatch,
    this.topSimilarLiked,
  });

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        isbn: j['isbn'] as String,
        fitScore: (j['fit_score'] as num).toDouble(),
        confidence: j['confidence'] as String,
        whyYouLikeIt: j['why_you_like_it'] as String,
        themeMatch: ThemeMatch.fromJson(
            j['theme_match'] as Map<String, dynamic>),
        topSimilarLiked: j['top_similar_liked'] != null
            ? BookResult.fromJson(
                j['top_similar_liked'] as Map<String, dynamic>)
            : null,
      );
}
