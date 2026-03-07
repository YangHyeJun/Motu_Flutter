class HoldingStock {
  const HoldingStock({
    required this.name,
    required this.code,
    required this.quantity,
    required this.buyPrice,
    required this.currentPrice,
    required this.evaluationAmount,
    required this.profitAmount,
    required this.profitRate,
    required this.isPositive,
  });

  final String name;
  final String code;
  final int quantity;
  final int buyPrice;
  final int currentPrice;
  final int evaluationAmount;
  final int profitAmount;
  final double profitRate;
  final bool isPositive;
}
