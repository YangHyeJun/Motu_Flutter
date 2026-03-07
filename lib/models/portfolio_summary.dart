class PortfolioSummary {
  const PortfolioSummary({
    required this.asset,
    required this.invested,
    required this.profitRate,
    required this.profitAmount,
  });

  final int asset;
  final int invested;
  final double profitRate;
  final int profitAmount;
}
