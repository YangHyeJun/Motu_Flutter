import 'stock_market_type.dart';

class StockDetail {
  const StockDetail({
    required this.name,
    required this.code,
    required this.marketType,
    required this.currentPrice,
    required this.previousClosePrice,
    required this.changeRate,
    required this.isPositive,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.chartEntries,
    required this.availableBuyQuantity,
    required this.availableCash,
    this.exchangeCode,
    this.marketLabel = '',
    this.currencySymbol = '원',
    this.priceDecimals = 0,
    this.exchangeRate,
    this.orderBook = const [],
    this.infoItems = const [],
    this.infoSections = const [],
  });

  final String name;
  final String code;
  final StockMarketType marketType;
  final int currentPrice;
  final int previousClosePrice;
  final double changeRate;
  final bool isPositive;
  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final int volume;
  final List<StockChartEntry> chartEntries;
  final int availableBuyQuantity;
  final int availableCash;
  final String? exchangeCode;
  final String marketLabel;
  final String currencySymbol;
  final int priceDecimals;
  final double? exchangeRate;
  final List<StockOrderBookLevel> orderBook;
  final List<StockInfoItem> infoItems;
  final List<StockInfoSection> infoSections;

  List<double> get normalizedChartPoints {
    if (chartEntries.isEmpty) {
      return const [];
    }

    final prices = chartEntries
        .map((entry) => entry.closePrice.toDouble())
        .toList();
    final minPrice = prices.reduce(
      (left, right) => left < right ? left : right,
    );
    final maxPrice = prices.reduce(
      (left, right) => left > right ? left : right,
    );
    final gap = maxPrice - minPrice;

    if (gap == 0) {
      return List<double>.filled(prices.length, 0.5);
    }

    return prices
        .map((price) => (price - minPrice) / gap)
        .toList(growable: false);
  }

  StockDetail copyWith({
    String? name,
    String? code,
    StockMarketType? marketType,
    int? currentPrice,
    int? previousClosePrice,
    double? changeRate,
    bool? isPositive,
    int? openPrice,
    int? highPrice,
    int? lowPrice,
    int? volume,
    List<StockChartEntry>? chartEntries,
    int? availableBuyQuantity,
    int? availableCash,
    String? exchangeCode,
    String? marketLabel,
    String? currencySymbol,
    int? priceDecimals,
    double? exchangeRate,
    List<StockOrderBookLevel>? orderBook,
    List<StockInfoItem>? infoItems,
    List<StockInfoSection>? infoSections,
  }) {
    return StockDetail(
      name: name ?? this.name,
      code: code ?? this.code,
      marketType: marketType ?? this.marketType,
      currentPrice: currentPrice ?? this.currentPrice,
      previousClosePrice: previousClosePrice ?? this.previousClosePrice,
      changeRate: changeRate ?? this.changeRate,
      isPositive: isPositive ?? this.isPositive,
      openPrice: openPrice ?? this.openPrice,
      highPrice: highPrice ?? this.highPrice,
      lowPrice: lowPrice ?? this.lowPrice,
      volume: volume ?? this.volume,
      chartEntries: chartEntries ?? this.chartEntries,
      availableBuyQuantity: availableBuyQuantity ?? this.availableBuyQuantity,
      availableCash: availableCash ?? this.availableCash,
      exchangeCode: exchangeCode ?? this.exchangeCode,
      marketLabel: marketLabel ?? this.marketLabel,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      priceDecimals: priceDecimals ?? this.priceDecimals,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      orderBook: orderBook ?? this.orderBook,
      infoItems: infoItems ?? this.infoItems,
      infoSections: infoSections ?? this.infoSections,
    );
  }
}

class StockLiveQuote {
  const StockLiveQuote({
    required this.currentPrice,
    required this.previousClosePrice,
    required this.changeRate,
    required this.isPositive,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    this.exchangeRate,
  });

  final int currentPrice;
  final int previousClosePrice;
  final double changeRate;
  final bool isPositive;
  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final int volume;
  final double? exchangeRate;
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

class StockOrderBookLevel {
  const StockOrderBookLevel({
    required this.askPrice,
    required this.askVolume,
    required this.bidPrice,
    required this.bidVolume,
  });

  final int askPrice;
  final int askVolume;
  final int bidPrice;
  final int bidVolume;
}

class StockInfoItem {
  const StockInfoItem({required this.label, required this.value});

  final String label;
  final String value;
}

class StockInfoSection {
  const StockInfoSection({required this.title, required this.items});

  final String title;
  final List<StockInfoItem> items;
}
