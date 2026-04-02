import 'holding_stock.dart';
import 'ranking_stock.dart';
import 'stock_market_type.dart';

class FavoriteStock {
  const FavoriteStock({
    required this.name,
    required this.code,
    required this.marketType,
    required this.currentPrice,
    required this.changeRate,
    required this.isPositive,
    this.exchangeCode,
    this.marketLabel = '',
    this.currencySymbol = '원',
    this.priceDecimals = 0,
  });

  final String name;
  final String code;
  final StockMarketType marketType;
  final int currentPrice;
  final double changeRate;
  final bool isPositive;
  final String? exchangeCode;
  final String marketLabel;
  final String currencySymbol;
  final int priceDecimals;

  String get key {
    if (marketType == StockMarketType.domestic) {
      return code.trim().toUpperCase();
    }
    return '${_normalizeOverseasExchangeCode(exchangeCode)}:${code.trim().toUpperCase()}';
  }

  FavoriteStock copyWith({
    String? name,
    String? code,
    StockMarketType? marketType,
    int? currentPrice,
    double? changeRate,
    bool? isPositive,
    String? exchangeCode,
    String? marketLabel,
    String? currencySymbol,
    int? priceDecimals,
  }) {
    return FavoriteStock(
      name: name ?? this.name,
      code: code ?? this.code,
      marketType: marketType ?? this.marketType,
      currentPrice: currentPrice ?? this.currentPrice,
      changeRate: changeRate ?? this.changeRate,
      isPositive: isPositive ?? this.isPositive,
      exchangeCode: exchangeCode ?? this.exchangeCode,
      marketLabel: marketLabel ?? this.marketLabel,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      priceDecimals: priceDecimals ?? this.priceDecimals,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'marketType': marketType.name,
      'currentPrice': currentPrice,
      'changeRate': changeRate,
      'isPositive': isPositive,
      'exchangeCode': exchangeCode,
      'marketLabel': marketLabel,
      'currencySymbol': currencySymbol,
      'priceDecimals': priceDecimals,
    };
  }

  factory FavoriteStock.fromJson(Map<String, dynamic> json) {
    return FavoriteStock(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      marketType: switch (json['marketType'] as String? ?? 'domestic') {
        'overseas' => StockMarketType.overseas,
        _ => StockMarketType.domestic,
      },
      currentPrice: json['currentPrice'] as int? ?? 0,
      changeRate: (json['changeRate'] as num?)?.toDouble() ?? 0,
      isPositive: json['isPositive'] as bool? ?? true,
      exchangeCode: json['exchangeCode'] as String?,
      marketLabel: json['marketLabel'] as String? ?? '',
      currencySymbol: json['currencySymbol'] as String? ?? '원',
      priceDecimals: json['priceDecimals'] as int? ?? 0,
    );
  }

  factory FavoriteStock.fromRankingStock(RankingStock stock) {
    return FavoriteStock(
      name: stock.name,
      code: stock.code,
      marketType: stock.marketType,
      currentPrice: stock.price,
      changeRate: stock.changeRate,
      isPositive: stock.isPositive,
      exchangeCode: stock.exchangeCode,
      marketLabel: stock.marketLabel,
      currencySymbol: stock.currencySymbol,
      priceDecimals: stock.priceDecimals,
    );
  }

  factory FavoriteStock.fromHoldingStock(HoldingStock stock) {
    return FavoriteStock(
      name: stock.name,
      code: stock.code,
      marketType: stock.marketType,
      currentPrice: stock.currentPrice,
      changeRate: stock.profitRate,
      isPositive: stock.isPositive,
      exchangeCode: stock.exchangeCode,
      marketLabel: stock.marketType == StockMarketType.domestic ? '국내' : '해외',
      currencySymbol: stock.currencySymbol,
      priceDecimals: stock.priceDecimals,
    );
  }

  RankingStock toRankingStock({int rank = 0}) {
    return RankingStock(
      rank: rank,
      name: name,
      code: code,
      price: currentPrice,
      changeRate: changeRate,
      extraLabel: '즐겨찾기',
      extraValue: marketLabel.isEmpty ? '관심 종목' : marketLabel,
      isPositive: isPositive,
      marketType: marketType,
      exchangeCode: exchangeCode,
      marketLabel: marketLabel,
      currencySymbol: currencySymbol,
      priceDecimals: priceDecimals,
    );
  }

  static String _normalizeOverseasExchangeCode(String? exchangeCode) {
    switch ((exchangeCode ?? 'NAS').trim().toUpperCase()) {
      case 'NASD':
      case 'BAQ':
        return 'NAS';
      case 'NYSE':
      case 'BAY':
        return 'NYS';
      case 'AMEX':
      case 'BAA':
        return 'AMS';
      default:
        return (exchangeCode ?? 'NAS').trim().toUpperCase();
    }
  }
}
