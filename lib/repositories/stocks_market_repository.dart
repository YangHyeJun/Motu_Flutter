import '../core/network/kis_api_client.dart';
import '../models/models.dart';

class StocksMarketRepository {
  StocksMarketRepository(this._apiClient);

  static const _usExchanges = [
    ('NAS', '미국 · 나스닥', '512'),
    ('NYS', '미국 · 뉴욕', '513'),
    ('AMS', '미국 · 아멕스', '529'),
  ];

  final KisApiClient _apiClient;

  Future<List<RankingStock>> fetchMarketStocks({
    required String market,
    required String category,
  }) async {
    switch (market) {
      case 'overseas':
        return _fetchOverseasCategory(category);
      case 'all':
        return _mergeAllUnique([
          await _fetchDomesticCategory(category),
          await _fetchOverseasCategory(category),
        ]);
      case 'domestic':
      default:
        return _fetchDomesticCategory(category);
    }
  }

  Future<List<RankingStock>> searchStocks(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final responses = await Future.wait([
      _fetchDomesticCategory('tradeAmount'),
      _fetchDomesticCategory('volume'),
      _fetchDomesticCategory('changeRate'),
      _fetchDomesticCategory('marketCap'),
      _fetchOverseasCategory('tradeAmount'),
      _fetchOverseasCategory('volume'),
      _fetchOverseasCategory('changeRate'),
      _fetchOverseasCategory('marketCap'),
    ]);

    final byCode = <String, RankingStock>{};
    for (final stocks in responses) {
      for (final stock in stocks) {
        if (!_matchesQuery(stock, normalizedQuery)) {
          continue;
        }
        byCode.putIfAbsent(_stockKey(stock), () => stock);
      }
    }

    final exact = await _searchExactUsStocks(query);
    for (final stock in exact) {
      byCode[_stockKey(stock)] = stock;
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

  Future<List<RankingStock>> _fetchDomesticCategory(String category) {
    switch (category) {
      case 'changeRate':
        return _fetchDomesticChangeRateStocks();
      case 'marketCap':
        return _fetchDomesticMarketCapStocks();
      case 'volume':
        return _fetchDomesticVolumeRankStocks(sortByTradeAmount: false);
      case 'tradeAmount':
      default:
        return _fetchDomesticVolumeRankStocks(sortByTradeAmount: true);
    }
  }

  Future<List<RankingStock>> _fetchOverseasCategory(String category) {
    switch (category) {
      case 'changeRate':
        return _fetchOverseasChangeRateStocks();
      case 'marketCap':
        return _fetchOverseasMarketCapStocks();
      case 'volume':
        return _fetchOverseasVolumeRankStocks(sortByTradeAmount: false);
      case 'tradeAmount':
      default:
        return _fetchOverseasVolumeRankStocks(sortByTradeAmount: true);
    }
  }

  Future<List<RankingStock>> _fetchDomesticVolumeRankStocks({
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
            marketType: StockMarketType.domestic,
            marketLabel: '국내',
          ),
        )
        .toList(growable: false);
  }

  Future<List<RankingStock>> _fetchDomesticChangeRateStocks() async {
    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/ranking/fluctuation',
      trId: 'FHPST01700000',
      queryParameters: {
        'fid_cond_mrkt_div_code': 'J',
        'fid_cond_scr_div_code': '20170',
        'fid_input_iscd': '0000',
        'fid_rank_sort_cls_code': '0',
        'fid_input_cnt_1': '0',
        'fid_prc_cls_code': '1',
        'fid_input_price_1': '',
        'fid_input_price_2': '',
        'fid_vol_cnt': '',
        'fid_trgt_cls_code': '0',
        'fid_trgt_exls_cls_code': '0',
        'fid_div_cls_code': '0',
        'fid_rsfl_rate1': '',
        'fid_rsfl_rate2': '',
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
            extraLabel: '등락률',
            extraValue: '${_toDouble(item['prdy_ctrt']).toStringAsFixed(2)}%',
            isPositive: _isPositive(item['prdy_vrss_sign'] as String?, _toDouble(item['prdy_ctrt'])),
            marketType: StockMarketType.domestic,
            marketLabel: '국내',
          ),
        )
        .toList(growable: false);
  }

  Future<List<RankingStock>> _fetchDomesticMarketCapStocks() async {
    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/ranking/market-cap',
      trId: 'FHPST01740000',
      queryParameters: {
        'fid_cond_mrkt_div_code': 'J',
        'fid_cond_scr_div_code': '20174',
        'fid_div_cls_code': '0',
        'fid_input_iscd': '0000',
        'fid_trgt_cls_code': '0',
        'fid_trgt_exls_cls_code': '0',
        'fid_input_price_1': '',
        'fid_input_price_2': '',
        'fid_vol_cnt': '',
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
            extraLabel: '시가총액',
            extraValue: _formatMarketCap(item['hts_avls'] ?? item['data_val']),
            isPositive: _isPositive(item['prdy_vrss_sign'] as String?, _toDouble(item['prdy_ctrt'])),
            marketType: StockMarketType.domestic,
            marketLabel: '국내',
          ),
        )
        .toList(growable: false);
  }

  Future<List<RankingStock>> _fetchOverseasVolumeRankStocks({
    required bool sortByTradeAmount,
  }) async {
    final stocks = <RankingStock>[];
    for (final exchange in _usExchanges) {
      final response = await _apiClient.get(
        path: sortByTradeAmount
            ? '/uapi/overseas-stock/v1/ranking/trade-pbmn'
            : '/uapi/overseas-stock/v1/ranking/trade-vol',
        trId: sortByTradeAmount ? 'HHDFS76320010' : 'HHDFS76310010',
        queryParameters: {
          'KEYB': '',
          'AUTH': '',
          'EXCD': exchange.$1,
          'NDAY': '0',
          'VOL_RANG': '0',
          'PRC1': '',
          'PRC2': '',
        },
      );
      stocks.addAll(
        _mapOverseasStocks(
          response['output2'] as List<dynamic>? ?? const <dynamic>[],
          exchangeCode: exchange.$1,
          marketLabel: exchange.$2,
          productTypeCode: exchange.$3,
          extraLabel: sortByTradeAmount ? '거래대금' : '거래량',
          extraValueBuilder: (item) => sortByTradeAmount
              ? _formatNumber(_toInt(item['tamt']))
              : '${_formatNumber(_toInt(item['tvol']))}주',
        ),
      );
    }
    return stocks;
  }

  Future<List<RankingStock>> _fetchOverseasChangeRateStocks() async {
    final stocks = <RankingStock>[];
    for (final exchange in _usExchanges) {
      final response = await _apiClient.get(
        path: '/uapi/overseas-stock/v1/ranking/updown-rate',
        trId: 'HHDFS76290000',
        queryParameters: {
          'KEYB': '',
          'AUTH': '',
          'EXCD': exchange.$1,
          'GUBN': '1',
          'NDAY': '0',
          'VOL_RANG': '0',
        },
      );
      stocks.addAll(
        _mapOverseasStocks(
          response['output2'] as List<dynamic>? ?? const <dynamic>[],
          exchangeCode: exchange.$1,
          marketLabel: exchange.$2,
          productTypeCode: exchange.$3,
          extraLabel: '등락률',
          extraValueBuilder: (item) => '${_toDouble(item['rate']).toStringAsFixed(2)}%',
        ),
      );
    }
    return stocks;
  }

  Future<List<RankingStock>> _fetchOverseasMarketCapStocks() async {
    final stocks = <RankingStock>[];
    for (final exchange in _usExchanges) {
      final response = await _apiClient.get(
        path: '/uapi/overseas-stock/v1/ranking/market-cap',
        trId: 'HHDFS76350100',
        queryParameters: {
          'KEYB': '',
          'AUTH': '',
          'EXCD': exchange.$1,
          'VOL_RANG': '0',
        },
      );
      stocks.addAll(
        _mapOverseasStocks(
          response['output2'] as List<dynamic>? ?? const <dynamic>[],
          exchangeCode: exchange.$1,
          marketLabel: exchange.$2,
          productTypeCode: exchange.$3,
          extraLabel: '시가총액 순위',
          extraValueBuilder: (item) => '${_toInt(item['rank'])}위',
        ),
      );
    }
    return stocks;
  }

  Future<List<RankingStock>> _searchExactUsStocks(String query) async {
    final normalized = query.trim().toUpperCase();
    if (normalized.isEmpty || normalized.length > 12) {
      return const [];
    }

    final results = <RankingStock>[];
    for (final exchange in _usExchanges) {
      try {
        final info = await _apiClient.get(
          path: '/uapi/overseas-price/v1/quotations/search-info',
          trId: 'CTPF1702R',
          queryParameters: {
            'PRDT_TYPE_CD': exchange.$3,
            'PDNO': normalized,
          },
        );
        final output = info['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final productName = output['prdt_name'] as String? ?? '';
        if (productName.isEmpty) {
          continue;
        }

        final quote = await _apiClient.get(
          path: '/uapi/overseas-price/v1/quotations/price',
          trId: 'HHDFS00000300',
          queryParameters: {
            'AUTH': '',
            'EXCD': exchange.$1,
            'SYMB': normalized,
          },
        );
        final quoteOutput = quote['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final decimals = _resolvePriceDecimals(quoteOutput['zdiv'], fallback: 2);
        final scale = _pow10(decimals);
        results.add(
          RankingStock(
            rank: 0,
            name: productName,
            code: normalized,
            price: (_toDouble(quoteOutput['last']) * scale).round(),
            changeRate: _toDouble(quoteOutput['rate']),
            extraLabel: '직접 검색',
            extraValue: exchange.$2,
            isPositive: _isPositive(quoteOutput['sign'] as String?, _toDouble(quoteOutput['rate'])),
            marketType: StockMarketType.overseas,
            exchangeCode: exchange.$1,
            productTypeCode: exchange.$3,
            marketLabel: exchange.$2,
            currencySymbol: r'$',
            priceDecimals: decimals,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  List<RankingStock> _mapOverseasStocks(
    List<dynamic> rawItems, {
    required String exchangeCode,
    required String marketLabel,
    required String productTypeCode,
    required String extraLabel,
    required String Function(Map<String, dynamic> item) extraValueBuilder,
  }) {
    return rawItems.whereType<Map<String, dynamic>>().map((item) {
      final decimals = _resolvePriceDecimals(item['zdiv'], fallback: _detectDecimalPlaces(item['last']));
      final scale = _pow10(decimals);
      return RankingStock(
        rank: _toInt(item['rank']),
        name: item['name'] as String? ?? '',
        code: item['symb'] as String? ?? '',
        price: (_toDouble(item['last']) * scale).round(),
        changeRate: _toDouble(item['rate']),
        extraLabel: extraLabel,
        extraValue: extraValueBuilder(item),
        isPositive: _isPositive(item['sign'] as String?, _toDouble(item['rate'])),
        marketType: StockMarketType.overseas,
        exchangeCode: exchangeCode,
        productTypeCode: productTypeCode,
        marketLabel: marketLabel,
        currencySymbol: r'$',
        priceDecimals: decimals,
      );
    }).toList(growable: false);
  }

  List<RankingStock> _mergeAllUnique(List<List<RankingStock>> groups) {
    final byKey = <String, RankingStock>{};
    for (final group in groups) {
      for (final stock in group) {
        byKey.putIfAbsent(_stockKey(stock), () => stock);
      }
    }
    return byKey.values.toList(growable: false);
  }

  String _stockKey(RankingStock stock) {
    return '${stock.marketType.name}:${stock.exchangeCode ?? ''}:${stock.code}';
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
    final market = stock.marketLabel.toLowerCase();
    return name.contains(query) || code.contains(query) || market.contains(query);
  }

  int _score(RankingStock stock, String query) {
    final name = stock.name.toLowerCase();
    final code = stock.code.toLowerCase();

    if (code == query) {
      return 6;
    }
    if (name == query) {
      return 5;
    }
    if (code.startsWith(query)) {
      return 4;
    }
    if (name.startsWith(query)) {
      return 3;
    }
    if (name.contains(query)) {
      return 2;
    }
    return 1;
  }

  int _resolvePriceDecimals(dynamic value, {int fallback = 0}) {
    final parsed = int.tryParse('${value ?? ''}'.trim());
    if (parsed == null || parsed < 0) {
      return fallback;
    }
    return parsed;
  }

  int _detectDecimalPlaces(dynamic value) {
    final raw = '${value ?? ''}'.trim();
    final parts = raw.split('.');
    if (parts.length < 2) {
      return 0;
    }
    return parts[1].length.clamp(0, 4);
  }

  int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
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

  String _formatMarketCap(dynamic value) {
    final parsed = _toInt(value);
    if (parsed <= 0) {
      return '-';
    }
    return _formatNumber(parsed);
  }
}
