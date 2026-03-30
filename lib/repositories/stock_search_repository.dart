import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ranking_stock.dart';
import '../models/stock_market_type.dart';

class StockSearchRepository {
  Future<List<StockSearchEntry>> loadEntries() {
    return _cache ??= _loadEntries();
  }

  Future<List<StockSearchEntry>> searchEntries(String query) async {
    final normalized = _normalize(query);
    if (normalized.isEmpty) {
      return const [];
    }

    final entries = await loadEntries();
    final matches = entries
        .where((entry) => entry.matches(normalized))
        .toList(growable: false);
    matches.sort(
      (left, right) => right
          .score(normalized)
          .compareTo(left.score(normalized)),
    );
    return matches;
  }

  Future<List<StockSearchEntry>> _loadEntries() async {
    final raw = await rootBundle.loadString('assets/data/stock_search_index.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(StockSearchEntry.fromJson)
        .toList(growable: false);
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(' ', '');
  }

  Future<List<StockSearchEntry>>? _cache;
}

class StockSearchEntry {
  const StockSearchEntry({
    required this.code,
    required this.name,
    required this.englishName,
    required this.marketType,
    required this.exchangeCode,
    required this.productTypeCode,
    required this.marketLabel,
    required this.currencySymbol,
    required this.priceDecimals,
  });

  factory StockSearchEntry.fromJson(Map<String, dynamic> json) {
    return StockSearchEntry(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      englishName: json['englishName'] as String? ?? '',
      marketType: (json['marketType'] as String? ?? '') == 'overseas'
          ? StockMarketType.overseas
          : StockMarketType.domestic,
      exchangeCode: json['exchangeCode'] as String? ?? '',
      productTypeCode: json['productTypeCode'] as String? ?? '',
      marketLabel: json['marketLabel'] as String? ?? '',
      currencySymbol: json['currencySymbol'] as String? ?? '원',
      priceDecimals: int.tryParse('${json['priceDecimals'] ?? 0}') ?? 0,
    );
  }

  final String code;
  final String name;
  final String englishName;
  final StockMarketType marketType;
  final String exchangeCode;
  final String productTypeCode;
  final String marketLabel;
  final String currencySymbol;
  final int priceDecimals;

  bool matches(String query) {
    final normalizedCode = code.toLowerCase();
    final normalizedName = name.toLowerCase().replaceAll(' ', '');
    final normalizedEnglish = englishName.toLowerCase().replaceAll(' ', '');
    final normalizedMarket = marketLabel.toLowerCase().replaceAll(' ', '');
    return normalizedCode.contains(query) ||
        normalizedName.contains(query) ||
        normalizedEnglish.contains(query) ||
        normalizedMarket.contains(query);
  }

  int score(String query) {
    final normalizedCode = code.toLowerCase();
    final normalizedName = name.toLowerCase().replaceAll(' ', '');
    final normalizedEnglish = englishName.toLowerCase().replaceAll(' ', '');

    if (normalizedCode == query) {
      return 10;
    }
    if (normalizedName == query || normalizedEnglish == query) {
      return 9;
    }
    if (normalizedCode.startsWith(query)) {
      return 8;
    }
    if (normalizedName.startsWith(query) || normalizedEnglish.startsWith(query)) {
      return 7;
    }
    if (normalizedName.contains(query) || normalizedEnglish.contains(query)) {
      return 6;
    }
    if (marketType == StockMarketType.domestic) {
      return 5;
    }
    return 4;
  }

  RankingStock toFallbackRankingStock({required int rank}) {
    return RankingStock(
      rank: rank,
      name: name,
      code: code,
      price: 0,
      changeRate: 0,
      extraLabel: '검색 결과',
      extraValue: marketLabel,
      isPositive: true,
      marketType: marketType,
      exchangeCode: exchangeCode.isEmpty ? null : exchangeCode,
      productTypeCode: productTypeCode.isEmpty ? null : productTypeCode,
      marketLabel: marketLabel,
      currencySymbol: currencySymbol,
      priceDecimals: priceDecimals,
    );
  }
}
