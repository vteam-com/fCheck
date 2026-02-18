/// Default ratio used to choose top code-size outlier slices.
const double defaultCodeSizeOutlierRatio = 0.1;

/// Default minimum outlier slice size for code-size views.
const int defaultCodeSizeOutlierMinCount = 3;

/// Default maximum outlier slice size for code-size views.
const int defaultCodeSizeOutlierMaxCount = 10;

/// Returns a stable top slice size for code-size outlier views.
int codeSizeOutlierCount(
  int totalItems, {
  double ratio = defaultCodeSizeOutlierRatio,
  int minCount = defaultCodeSizeOutlierMinCount,
  int maxCount = defaultCodeSizeOutlierMaxCount,
}) {
  if (totalItems <= 0) {
    return 0;
  }
  final proportional = (totalItems * ratio).ceil();
  final bounded = proportional.clamp(minCount, maxCount);
  return bounded > totalItems ? totalItems : bounded;
}
