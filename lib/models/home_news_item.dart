class HomeNewsItem {
  const HomeNewsItem({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.linkUrl,
    this.primaryCode,
    this.primaryName,
    this.categoryCode,
  });

  final String id;
  final String title;
  final String source;
  final DateTime publishedAt;
  final String linkUrl;
  final String? primaryCode;
  final String? primaryName;
  final String? categoryCode;
}
