import 'stock_market_type.dart';

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
    this.marketType = StockMarketType.domestic,
    this.exchangeCode,
    this.productTypeCode,
    this.marketLabel = '',
    this.currencySymbol = '원',
    this.priceDecimals = 0,
  });

  final int rank;
  final String name;
  final String code;
  final int price;
  final double changeRate;
  final String extraLabel;
  final String extraValue;
  final bool isPositive;
  final StockMarketType marketType;
  final String? exchangeCode;
  final String? productTypeCode;
  final String marketLabel;
  final String currencySymbol;
  final int priceDecimals;
}
