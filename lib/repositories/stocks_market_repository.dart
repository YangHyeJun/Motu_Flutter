import '../core/network/kis_api_client.dart';
import '../models/models.dart';
import 'stock_search_repository.dart';

class StocksMarketRepository {
  StocksMarketRepository(this._apiClient, this._stockSearchRepository);

  static const _usExchanges = [
    ('NAS', '미국 · 나스닥', '512'),
    ('NYS', '미국 · 뉴욕', '513'),
    ('AMS', '미국 · 아멕스', '529'),
  ];

  final KisApiClient _apiClient;
  final StockSearchRepository _stockSearchRepository;

  Future<List<RankingStock>> fetchMarketStocks({
    required String market,
    required String category,
  }) async {
    switch (market) {
      case 'overseas':
        return _reRankStocks(await _fetchOverseasCategory(category));
      case 'all':
        return _reRankStocks(
          _mergeAllUnique([
            await _fetchDomesticCategory(category),
            await _fetchOverseasCategory(category),
          ]),
        );
      case 'domestic':
      default:
        return _reRankStocks(await _fetchDomesticCategory(category));
    }
  }

  Future<List<RankingStock>> fetchDomesticTopMovers({int limit = 5}) async {
    return _reRankStocks(
      (await _fetchDomesticChangeRateStocks(riseOnly: true))
          .take(limit)
          .toList(growable: false),
    );
  }

  Future<List<RankingStock>> fetchDomesticVolumeLeaders({int limit = 5}) async {
    return _reRankStocks(
      (await _fetchDomesticVolumeRankStocks(
        sortByTradeAmount: false,
      )).take(limit).toList(growable: false),
    );
  }

  Future<List<RankingStock>> fetchOverseasTopMovers({int limit = 5}) async {
    return _reRankStocks(
      (await _fetchOverseasChangeRateStocks(riseOnly: true))
          .take(limit)
          .toList(growable: false),
    );
  }

  Future<List<RankingStock>> fetchOverseasVolumeLeaders({int limit = 5}) async {
    return _reRankStocks(
      (await _fetchOverseasVolumeRankStocks(
        sortByTradeAmount: false,
      )).take(limit).toList(growable: false),
    );
  }

  Future<List<RankingStock>> searchStocks(String query) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final searchEntries = await _stockSearchRepository.searchEntries(query);
    if (searchEntries.isEmpty) {
      final exact = await _searchExactUsStocks(query);
      return _reRankStocks(exact);
    }

    final seeded = <String, RankingStock>{};
    final candidates = searchEntries.take(40).toList(growable: false);
    final liveResults = await Future.wait([
      for (final entry in candidates)
        _fetchSearchQuote(entry.toFallbackRankingStock(rank: 0)),
    ]);
    for (var index = 0; index < candidates.length; index++) {
      final fallback = candidates[index].toFallbackRankingStock(rank: 0);
      seeded[_stockKey(fallback)] = liveResults[index] ?? fallback;
    }

    final exact = await _searchExactUsStocks(query);
    for (final stock in exact) {
      seeded[_stockKey(stock)] = stock;
    }

    final results = seeded.values.toList(growable: false);
    results.sort((left, right) {
      final scoreComparison = _score(
        right,
        normalizedQuery,
      ).compareTo(_score(left, normalizedQuery));
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return left.name.compareTo(right.name);
    });
    return _reRankStocks(results.take(50).toList(growable: false));
  }

  Future<Map<String, RankingStock>> fetchLiveStocks(
    List<RankingStock> stocks,
  ) async {
    final entries = await Future.wait(
      stocks.map((stock) async {
        if (stock.marketType == StockMarketType.overseas) {
          try {
            final quote = await _apiClient.get(
              path: '/uapi/overseas-price/v1/quotations/price',
              trId: 'HHDFS00000300',
              queryParameters: {
                'AUTH': '',
                'EXCD': stock.exchangeCode ?? 'NAS',
                'SYMB': stock.code,
              },
            );
            final output =
                quote['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
            final decimals = _resolvePriceDecimals(
              output['zdiv'],
              fallback: stock.priceDecimals,
            );
            final scale = _pow10(decimals);
            final price = (_toDouble(output['last']) * scale).round();
            final previousClosePrice = (_toDouble(output['base']) * scale)
                .round();
            final changeRate = _resolveOverseasChangeRate(
              currentPrice: price,
              previousClosePrice: previousClosePrice,
              fallbackRate: _toDouble(output['rate']),
            );
            return MapEntry(
              _stockKey(stock),
              RankingStock(
                rank: stock.rank,
                name: stock.name,
                code: stock.code,
                price: price,
                changeRate: changeRate,
                extraLabel: stock.extraLabel,
                extraValue: stock.extraValue,
                isPositive: _resolveOverseasIsPositive(
                  currentPrice: price,
                  previousClosePrice: previousClosePrice,
                  sign: output['sign'] as String?,
                  fallbackRate: changeRate,
                ),
                marketType: stock.marketType,
                exchangeCode: stock.exchangeCode,
                productTypeCode: stock.productTypeCode,
                marketLabel: stock.marketLabel,
                currencySymbol: stock.currencySymbol,
                priceDecimals: decimals,
              ),
            );
          } catch (_) {
            return null;
          }
        }

        try {
          final quote = await _apiClient.get(
            path: '/uapi/domestic-stock/v1/quotations/inquire-price',
            trId: 'FHKST01010100',
            queryParameters: {
              'FID_COND_MRKT_DIV_CODE': 'J',
              'FID_INPUT_ISCD': stock.code,
            },
          );
          final output =
              quote['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
          final changeRate = _toDouble(output['prdy_ctrt']);
          return MapEntry(
            _stockKey(stock),
            RankingStock(
              rank: stock.rank,
              name: stock.name,
              code: stock.code,
              price: _toInt(output['stck_prpr']),
              changeRate: changeRate,
              extraLabel: stock.extraLabel,
              extraValue: stock.extraValue,
              isPositive: _isPositive(
                output['prdy_vrss_sign'] as String?,
                changeRate,
              ),
              marketType: stock.marketType,
              exchangeCode: stock.exchangeCode,
              productTypeCode: stock.productTypeCode,
              marketLabel: stock.marketLabel,
              currencySymbol: stock.currencySymbol,
              priceDecimals: stock.priceDecimals,
            ),
          );
        } catch (_) {
          return null;
        }
      }),
    );

    return {
      for (final entry in entries.whereType<MapEntry<String, RankingStock>>())
        entry.key: entry.value,
    };
  }

  Future<RankingStock?> _fetchSearchQuote(RankingStock stock) async {
    try {
      if (stock.marketType == StockMarketType.overseas) {
        final quote = await _apiClient.get(
          path: '/uapi/overseas-price/v1/quotations/price',
          trId: 'HHDFS00000300',
          queryParameters: {
            'AUTH': '',
            'EXCD': stock.exchangeCode ?? 'NAS',
            'SYMB': stock.code,
          },
        );
        final output =
            quote['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final decimals = _resolvePriceDecimals(
          output['zdiv'],
          fallback: stock.priceDecimals,
        );
        final scale = _pow10(decimals);
        final price = (_toDouble(output['last']) * scale).round();
        final previousClosePrice = (_toDouble(output['base']) * scale).round();
        final changeRate = _resolveOverseasChangeRate(
          currentPrice: price,
          previousClosePrice: previousClosePrice,
          fallbackRate: _toDouble(output['rate']),
        );
        return RankingStock(
          rank: stock.rank,
          name: stock.name,
          code: stock.code,
          price: price,
          changeRate: changeRate,
          extraLabel: stock.extraLabel,
          extraValue: stock.extraValue,
          isPositive: _resolveOverseasIsPositive(
            currentPrice: price,
            previousClosePrice: previousClosePrice,
            sign: output['sign'] as String?,
            fallbackRate: changeRate,
          ),
          marketType: stock.marketType,
          exchangeCode: stock.exchangeCode,
          productTypeCode: stock.productTypeCode,
          marketLabel: stock.marketLabel,
          currencySymbol: stock.currencySymbol,
          priceDecimals: decimals,
        );
      }

      final quote = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/inquire-price',
        trId: 'FHKST01010100',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'J',
          'FID_INPUT_ISCD': stock.code,
        },
      );
      final output =
          quote['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final changeRate = _toDouble(output['prdy_ctrt']);
      return RankingStock(
        rank: stock.rank,
        name: stock.name,
        code: stock.code,
        price: _toInt(output['stck_prpr']),
        changeRate: changeRate,
        extraLabel: stock.extraLabel,
        extraValue: stock.extraValue,
        isPositive: _isPositive(
          output['prdy_vrss_sign'] as String?,
          changeRate,
        ),
        marketType: stock.marketType,
        exchangeCode: stock.exchangeCode,
        productTypeCode: stock.productTypeCode,
        marketLabel: stock.marketLabel,
        currencySymbol: stock.currencySymbol,
        priceDecimals: stock.priceDecimals,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<RankingStock>> _fetchDomesticCategory(String category) {
    switch (category) {
      case 'changeRate':
        return _fetchDomesticChangeRateStocks(riseOnly: false);
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
        return _fetchOverseasChangeRateStocks(riseOnly: false);
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
            isPositive: _isPositive(
              item['prdy_vrss_sign'] as String?,
              _toDouble(item['prdy_ctrt']),
            ),
            marketType: StockMarketType.domestic,
            marketLabel: '국내',
          ),
        )
        .toList(growable: false);
  }

  Future<List<RankingStock>> _fetchDomesticChangeRateStocks({
    required bool riseOnly,
  }) async {
    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/ranking/fluctuation',
      trId: 'FHPST01700000',
      queryParameters: {
        'fid_cond_mrkt_div_code': 'J',
        'fid_cond_scr_div_code': '20170',
        'fid_input_iscd': '0000',
        'fid_rank_sort_cls_code': riseOnly ? '1' : '0',
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
            isPositive: _isPositive(
              item['prdy_vrss_sign'] as String?,
              _toDouble(item['prdy_ctrt']),
            ),
            marketType: StockMarketType.domestic,
            marketLabel: '국내',
          ),
        )
        .where((item) => !riseOnly || item.isPositive)
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
            isPositive: _isPositive(
              item['prdy_vrss_sign'] as String?,
              _toDouble(item['prdy_ctrt']),
            ),
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

  Future<List<RankingStock>> _fetchOverseasChangeRateStocks({
    required bool riseOnly,
  }) async {
    final stocks = <RankingStock>[];
    for (final exchange in _usExchanges) {
      final response = await _apiClient.get(
        path: '/uapi/overseas-stock/v1/ranking/updown-rate',
        trId: 'HHDFS76290000',
        queryParameters: {
          'KEYB': '',
          'AUTH': '',
          'EXCD': exchange.$1,
          'GUBN': riseOnly ? '1' : '',
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
          extraValueBuilder: (item) =>
              '${_toDouble(item['rate']).toStringAsFixed(2)}%',
        ),
      );
    }
    if (!riseOnly) {
      return stocks;
    }
    return stocks.where((stock) => stock.isPositive).toList(growable: false);
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
          queryParameters: {'PRDT_TYPE_CD': exchange.$3, 'PDNO': normalized},
        );
        final output =
            info['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
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
        final quoteOutput =
            quote['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final decimals = _resolvePriceDecimals(
          quoteOutput['zdiv'],
          fallback: 2,
        );
        final scale = _pow10(decimals);
        final price = (_toDouble(quoteOutput['last']) * scale).round();
        final previousClosePrice = (_toDouble(quoteOutput['base']) * scale)
            .round();
        final changeRate = _resolveOverseasChangeRate(
          currentPrice: price,
          previousClosePrice: previousClosePrice,
          fallbackRate: _toDouble(quoteOutput['rate']),
        );
        results.add(
          RankingStock(
            rank: 0,
            name: productName,
            code: normalized,
            price: price,
            changeRate: changeRate,
            extraLabel: '직접 검색',
            extraValue: exchange.$2,
            isPositive: _resolveOverseasIsPositive(
              currentPrice: price,
              previousClosePrice: previousClosePrice,
              sign: quoteOutput['sign'] as String?,
              fallbackRate: changeRate,
            ),
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
    return rawItems
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final decimals = _resolvePriceDecimals(
            item['zdiv'],
            fallback: _detectDecimalPlaces(item['last']),
          );
          final scale = _pow10(decimals);
          return RankingStock(
            rank: _toInt(item['rank']),
            name: item['name'] as String? ?? '',
            code: item['symb'] as String? ?? '',
            price: (_toDouble(item['last']) * scale).round(),
            changeRate: _toDouble(item['rate']),
            extraLabel: extraLabel,
            extraValue: extraValueBuilder(item),
            isPositive: _isPositive(
              item['sign'] as String?,
              _toDouble(item['rate']),
            ),
            marketType: StockMarketType.overseas,
            exchangeCode: exchangeCode,
            productTypeCode: productTypeCode,
            marketLabel: marketLabel,
            currencySymbol: r'$',
            priceDecimals: decimals,
          );
        })
        .toList(growable: false);
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

  List<RankingStock> _reRankStocks(List<RankingStock> stocks) {
    return [
      for (var index = 0; index < stocks.length; index++)
        RankingStock(
          rank: index + 1,
          name: stocks[index].name,
          code: stocks[index].code,
          price: stocks[index].price,
          changeRate: stocks[index].changeRate,
          extraLabel: stocks[index].extraLabel,
          extraValue: stocks[index].extraValue,
          isPositive: stocks[index].isPositive,
          marketType: stocks[index].marketType,
          exchangeCode: stocks[index].exchangeCode,
          productTypeCode: stocks[index].productTypeCode,
          marketLabel: stocks[index].marketLabel,
          currencySymbol: stocks[index].currencySymbol,
          priceDecimals: stocks[index].priceDecimals,
        ),
    ];
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

  double _resolveOverseasChangeRate({
    required int currentPrice,
    required int previousClosePrice,
    required double fallbackRate,
  }) {
    if (currentPrice > 0 && previousClosePrice > 0) {
      return ((currentPrice - previousClosePrice) / previousClosePrice) * 100;
    }
    return fallbackRate;
  }

  bool _resolveOverseasIsPositive({
    required int currentPrice,
    required int previousClosePrice,
    required String? sign,
    required double fallbackRate,
  }) {
    if (currentPrice > 0 && previousClosePrice > 0) {
      return currentPrice >= previousClosePrice;
    }
    return _isPositive(sign, fallbackRate);
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
