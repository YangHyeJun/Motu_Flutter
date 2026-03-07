class MarketIndex {
  const MarketIndex({
    required this.name,
    required this.value,
    required this.changeRate,
    required this.isPositive,
  });

  final String name;
  final String value;
  final String changeRate;
  final bool isPositive;
}
