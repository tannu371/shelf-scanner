/// Data model for a single book returned by the backend.
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
