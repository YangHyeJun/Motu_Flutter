class StockDetail {
  const StockDetail({
    required this.name,
    required this.code,
    required this.currentPrice,
    required this.changeRate,
    required this.isPositive,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.chartEntries,
    required this.availableBuyQuantity,
    required this.availableCash,
  });

  final String name;
  final String code;
  final int currentPrice;
  final double changeRate;
  final bool isPositive;
  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final int volume;
  final List<StockChartEntry> chartEntries;
  final int availableBuyQuantity;
  final int availableCash;

  List<double> get normalizedChartPoints {
    if (chartEntries.isEmpty) {
      return const [];
    }

    final prices = chartEntries.map((entry) => entry.closePrice.toDouble()).toList();
    final minPrice = prices.reduce((left, right) => left < right ? left : right);
    final maxPrice = prices.reduce((left, right) => left > right ? left : right);
    final gap = maxPrice - minPrice;

    if (gap == 0) {
      return List<double>.filled(prices.length, 0.5);
    }

    return prices.map((price) => (price - minPrice) / gap).toList(growable: false);
  }

  StockDetail copyWith({
    String? name,
    String? code,
    int? currentPrice,
    double? changeRate,
    bool? isPositive,
    int? openPrice,
    int? highPrice,
    int? lowPrice,
    int? volume,
    List<StockChartEntry>? chartEntries,
    int? availableBuyQuantity,
    int? availableCash,
  }) {
    return StockDetail(
      name: name ?? this.name,
      code: code ?? this.code,
      currentPrice: currentPrice ?? this.currentPrice,
      changeRate: changeRate ?? this.changeRate,
      isPositive: isPositive ?? this.isPositive,
      openPrice: openPrice ?? this.openPrice,
      highPrice: highPrice ?? this.highPrice,
      lowPrice: lowPrice ?? this.lowPrice,
      volume: volume ?? this.volume,
      chartEntries: chartEntries ?? this.chartEntries,
      availableBuyQuantity: availableBuyQuantity ?? this.availableBuyQuantity,
      availableCash: availableCash ?? this.availableCash,
    );
  }
}

enum StockChartPeriod {
  oneDay('1일'),
  oneWeek('1주'),
  oneMonth('1달'),
  oneYear('1년'),
  all('전체');

  const StockChartPeriod(this.label);

  final String label;
}

class StockChartEntry {
  const StockChartEntry({
    required this.date,
    required this.timeLabel,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.closePrice,
    required this.volume,
  });

  final String date;
  final String timeLabel;
  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final int closePrice;
  final int volume;
}
