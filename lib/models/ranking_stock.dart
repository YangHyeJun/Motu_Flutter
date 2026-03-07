class RankingStock {
  const RankingStock({
    required this.rank,
    required this.name,
    required this.code,
    required this.price,
    required this.changeRate,
    required this.extraLabel,
    required this.extraValue,
    required this.isPositive,
  });

  final int rank;
  final String name;
  final String code;
  final int price;
  final double changeRate;
  final String extraLabel;
  final String extraValue;
  final bool isPositive;
}
