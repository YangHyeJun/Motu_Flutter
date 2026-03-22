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

  HoldingStock copyWith({
    String? name,
    String? code,
    int? quantity,
    int? buyPrice,
    int? currentPrice,
    int? evaluationAmount,
    int? profitAmount,
    double? profitRate,
    bool? isPositive,
  }) {
    return HoldingStock(
      name: name ?? this.name,
      code: code ?? this.code,
      quantity: quantity ?? this.quantity,
      buyPrice: buyPrice ?? this.buyPrice,
      currentPrice: currentPrice ?? this.currentPrice,
      evaluationAmount: evaluationAmount ?? this.evaluationAmount,
      profitAmount: profitAmount ?? this.profitAmount,
      profitRate: profitRate ?? this.profitRate,
      isPositive: isPositive ?? this.isPositive,
    );
  }

  HoldingStock applyRealtimePrice({
    required int nextPrice,
    required double nextProfitRate,
    required bool nextIsPositive,
  }) {
    final nextEvaluationAmount = nextPrice * quantity;
    final nextProfitAmount = nextEvaluationAmount - (buyPrice * quantity);

    return copyWith(
      currentPrice: nextPrice,
      evaluationAmount: nextEvaluationAmount,
      profitAmount: nextProfitAmount,
      profitRate: nextProfitRate,
      isPositive: nextIsPositive,
    );
  }
}
