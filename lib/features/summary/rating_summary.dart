import '../../core/models.dart';

RatingSummary summarizeReviews(List<Review> reviews) {
  final histogram = <int, int>{for (var star = 1; star <= 5; star++) star: 0};
  var sum = 0;
  for (final review in reviews) {
    final rating = review.rating;
    if (rating < 1 || rating > 5) {
      throw RangeError.range(rating, 1, 5, 'rating');
    }
    histogram[rating] = histogram[rating]! + 1;
    sum += rating;
  }
  return RatingSummary(
    average: reviews.isEmpty ? null : sum / reviews.length,
    count: reviews.length,
    histogram: Map.unmodifiable(histogram),
  );
}