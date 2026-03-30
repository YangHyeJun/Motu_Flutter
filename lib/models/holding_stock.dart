import 'stock_market_type.dart';

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
    this.marketType = StockMarketType.domestic,
    this.exchangeCode,
    this.currencySymbol = '원',
    this.priceDecimals = 0,
    this.exchangeRate,
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
  final StockMarketType marketType;
  final String? exchangeCode;
  final String currencySymbol;
  final int priceDecimals;
  final double? exchangeRate;

  int get investedAmount => buyPrice * quantity;

  int get currentAmount => evaluationAmount;

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
    StockMarketType? marketType,
    String? exchangeCode,
    String? currencySymbol,
    int? priceDecimals,
    double? exchangeRate,
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
      marketType: marketType ?? this.marketType,
      exchangeCode: exchangeCode ?? this.exchangeCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      priceDecimals: priceDecimals ?? this.priceDecimals,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }

  HoldingStock applyRealtimePrice({required int nextPrice}) {
    final nextEvaluationAmount = nextPrice * quantity;
    final nextProfitAmount = nextEvaluationAmount - (buyPrice * quantity);
    final nextProfitRate = buyPrice == 0
        ? 0.0
        : ((nextPrice - buyPrice) / buyPrice) * 100;

    return copyWith(
      currentPrice: nextPrice,
      evaluationAmount: nextEvaluationAmount,
      profitAmount: nextProfitAmount,
      profitRate: nextProfitRate,
      isPositive: nextProfitAmount >= 0,
    );
  }
}
