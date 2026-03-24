import '../core/network/kis_api_client.dart';
import '../models/ranking_stock.dart';

class StocksMarketRepository {
  StocksMarketRepository(this._apiClient);

  final KisApiClient _apiClient;

  Future<List<RankingStock>> searchStocks(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final responses = await Future.wait([
      fetchDomesticStocks(sortByTradeAmount: true),
      fetchDomesticStocks(sortByTradeAmount: false),
      fetchOverseasStocks(sortByTradeAmount: true),
      fetchOverseasStocks(sortByTradeAmount: false),
    ]);

    final byCode = <String, RankingStock>{};
    for (final stocks in responses) {
      for (final stock in stocks) {
        if (!_matchesQuery(stock, normalizedQuery)) {
          continue;
        }
        byCode.putIfAbsent(stock.code, () => stock);
      }
    }

    final results = byCode.values.toList(growable: false);
    results.sort((left, right) {
      final scoreComparison = _score(right, normalizedQuery).compareTo(_score(left, normalizedQuery));
      if (scoreComparison != 0) {
        return scoreComparison;
      }

      return left.name.compareTo(right.name);
    });
    return results;
  }

  Future<List<RankingStock>> fetchDomesticStocks({
    required bool sortByTradeAmount,
  }) async {
    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/quotations/volume-rank',
      trId: 'FHPST01710000',
      queryParameters: {
        'FID_COND_MRKT_DIV_CODE': 'J',
        'FID_COND_SCR_DIV_CODE': '20171',
        'FID_INPUT_ISCD': '0000',
        'FID_DIV_CLS_CODE': '0',
        'FID_BLNG_CLS_CODE': sortByTradeAmount ? '3' : '0',
        'FID_TRGT_CLS_CODE': '111111111',
        'FID_TRGT_EXLS_CLS_CODE': '0000000000',
        'FID_INPUT_PRICE_1': '0',
        'FID_INPUT_PRICE_2': '0',
        'FID_VOL_CNT': '0',
        'FID_INPUT_DATE_1': '0',
      },
    );

    return (response['output'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => RankingStock(
            rank: _toInt(item['data_rank']),
            name: item['hts_kor_isnm'] as String? ?? '',
            code: item['mksc_shrn_iscd'] as String? ?? '',
            price: _toInt(item['stck_prpr']),
            changeRate: _toDouble(item['prdy_ctrt']),
            extraLabel: sortByTradeAmount ? '거래대금' : '거래량',
            extraValue: sortByTradeAmount
                ? _formatNumber(_toInt(item['acml_tr_pbmn']))
                : '${_formatNumber(_toInt(item['acml_vol']))}주',
            isPositive: _isPositive(item['prdy_vrss_sign'] as String?, _toDouble(item['prdy_ctrt'])),
          ),
        )
        .toList(growable: false);
  }

  Future<List<RankingStock>> fetchOverseasStocks({
    required bool sortByTradeAmount,
  }) async {
    final response = await _apiClient.get(
      path: sortByTradeAmount
          ? '/uapi/overseas-stock/v1/ranking/trade-pbmn'
          : '/uapi/overseas-stock/v1/ranking/trade-vol',
      trId: sortByTradeAmount ? 'HHDFS76320010' : 'HHDFS76310010',
      queryParameters: {
        'KEYB': '',
        'AUTH': '',
        'EXCD': 'NAS',
        'NDAY': '0',
        'VOL_RANG': '0',
        'PRC1': '',
        'PRC2': '',
      },
    );

    return (response['output2'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => RankingStock(
            rank: _toInt(item['rank']),
            name: item['name'] as String? ?? '',
            code: item['symb'] as String? ?? '',
            price: _toDouble(item['last']).round(),
            changeRate: _toDouble(item['rate']),
            extraLabel: sortByTradeAmount ? '거래대금' : '거래량',
            extraValue: sortByTradeAmount
                ? _formatNumber(_toInt(item['tamt']))
                : '${_formatNumber(_toInt(item['tvol']))}주',
            isPositive: _isPositive(item['sign'] as String?, _toDouble(item['rate'])),
          ),
        )
        .toList(growable: false);
  }

  int _toInt(dynamic value) {
    return int.tryParse('${value ?? ''}'.replaceAll(',', '').trim()) ?? 0;
  }

  double _toDouble(dynamic value) {
    return double.tryParse('${value ?? ''}'.replaceAll(',', '').trim()) ?? 0.0;
  }

  bool _isPositive(String? sign, double rate) {
    switch (sign) {
      case '1':
      case '4':
      case '5':
        return false;
      case '2':
      case '3':
        return true;
      default:
        return rate >= 0;
    }
  }

  bool _matchesQuery(RankingStock stock, String query) {
    final name = stock.name.toLowerCase();
    final code = stock.code.toLowerCase();
    return name.contains(query) || code.contains(query);
  }

  int _score(RankingStock stock, String query) {
    final name = stock.name.toLowerCase();
    final code = stock.code.toLowerCase();

    if (code == query) {
      return 5;
    }
    if (name == query) {
      return 4;
    }
    if (name.startsWith(query)) {
      return 3;
    }
    if (code.startsWith(query)) {
      return 2;
    }
    return 1;
  }

  String _formatNumber(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final fromEnd = digits.length - i - 1;
      if (fromEnd > 0 && fromEnd % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}
