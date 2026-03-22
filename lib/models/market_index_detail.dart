import 'stock_detail.dart';

class MarketIndexDetail {
  const MarketIndexDetail({
    required this.name,
    required this.code,
    required this.currentValue,
    required this.changeAmount,
    required this.changeRate,
    required this.isPositive,
    required this.openValue,
    required this.highValue,
    required this.lowValue,
    required this.volume,
    required this.chartEntries,
  });

  final String name;
  final String code;
  final String currentValue;
  final String changeAmount;
  final double changeRate;
  final bool isPositive;
  final String openValue;
  final String highValue;
  final String lowValue;
  final int volume;
  final List<StockChartEntry> chartEntries;
}
