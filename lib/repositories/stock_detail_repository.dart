import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_exception.dart';
import '../models/account_profile.dart';
import '../models/stock_detail.dart';
import '../models/stock_market_type.dart';

class StockDetailRepository {
  StockDetailRepository(this._apiClient, this._account);

  final KisApiClient _apiClient;
  final AccountProfile _account;

  Future<StockDetail> fetchStockDetail({
    required String code,
    required String name,
    required StockChartPeriod period,
    required StockMarketType marketType,
    String? exchangeCode,
  }) async {
    if (marketType == StockMarketType.overseas) {
      return _fetchOverseasStockDetail(
        code: code,
        name: name,
        period: period,
        exchangeCode: exchangeCode ?? 'NAS',
      );
    }

    final quoteResponse = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/quotations/inquire-price',
      trId: 'FHKST01010100',
      queryParameters: {'FID_COND_MRKT_DIV_CODE': 'J', 'FID_INPUT_ISCD': code},
    );

    final quote =
        quoteResponse['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final chartEntries = await _fetchChartEntries(code: code, period: period);

    final latestChart = chartEntries.isEmpty ? null : chartEntries.last;
    final changeRate = _toDouble(quote['prdy_ctrt']) == 0 && latestChart != null
        ? _deriveChangeRate(chartEntries)
        : _toDouble(quote['prdy_ctrt']);
    var availableBuyQuantity = 0;
    var availableCash = 0;

    if (_account.isConfigured) {
      try {
        final buyableResponse = await _apiClient.get(
          path: '/uapi/domestic-stock/v1/trading/inquire-psbl-order',
          trId: _apiClient.useMockServer ? 'VTTC8908R' : 'TTTC8908R',
          queryParameters: {
            'CANO': _account.accountNumber,
            'ACNT_PRDT_CD': _account.accountProductCode,
            'PDNO': code,
            'ORD_UNPR': '0',
            'ORD_DVSN': '01',
            'CMA_EVLU_AMT_ICLD_YN': 'N',
            'OVRS_ICLD_YN': 'N',
          },
        );

        final output =
            buyableResponse['output'] as Map<String, dynamic>? ??
            <String, dynamic>{};
        availableBuyQuantity = _toInt(output['nrcvb_buy_qty']);
        availableCash = _toInt(output['ord_psbl_cash']);
      } on KisApiException {
        availableBuyQuantity = 0;
        availableCash = 0;
      }
    }

    return StockDetail(
      name: name,
      code: code,
      marketType: StockMarketType.domestic,
      currentPrice: _toInt(quote['stck_prpr']) == 0 && latestChart != null
          ? latestChart.closePrice
          : _toInt(quote['stck_prpr']),
      changeRate: changeRate,
      isPositive: _isPositive(quote['prdy_vrss_sign'] as String?, changeRate),
      openPrice: _toInt(quote['stck_oprc']),
      highPrice: _toInt(quote['stck_hgpr']),
      lowPrice: _toInt(quote['stck_lwpr']),
      volume: _toInt(quote['acml_vol']),
      chartEntries: chartEntries,
      availableBuyQuantity: availableBuyQuantity,
      availableCash: availableCash,
      marketLabel: '국내',
    );
  }

  Future<StockDetail> _fetchOverseasStockDetail({
    required String code,
    required String name,
    required StockChartPeriod period,
    required String exchangeCode,
  }) async {
    final quoteResponse = await _apiClient.get(
      path: '/uapi/overseas-price/v1/quotations/price',
      trId: 'HHDFS00000300',
      queryParameters: {'AUTH': '', 'EXCD': exchangeCode, 'SYMB': code},
    );

    final quote =
        quoteResponse['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final priceDecimals = _resolvePriceDecimals(quote['zdiv'], fallback: 2);
    final chartEntries = await _fetchOverseasChartEntries(
      exchangeCode: exchangeCode,
      code: code,
      period: period,
      priceDecimals: priceDecimals,
    );
    final latestChart = chartEntries.isEmpty ? null : chartEntries.last;
    final currentPrice = _scaledPrice(quote['last'], priceDecimals);
    final previousClosePrice = _scaledPrice(quote['base'], priceDecimals);
    final changeRate = _resolveOverseasChangeRate(
      currentPrice: currentPrice,
      previousClosePrice: previousClosePrice,
      fallbackRate: _toDouble(quote['rate']),
    );
    final openPrice = _scaledPrice(quote['base'], priceDecimals);
    final highPrice = _scaledPrice(quote['last'], priceDecimals);
    final lowPrice = _scaledPrice(quote['last'], priceDecimals);
    final orderBook = await _fetchOverseasOrderBook(
      exchangeCode: exchangeCode,
      code: code,
      priceDecimals: priceDecimals,
    );
    final infoData = await _fetchOverseasInfoData(
      exchangeCode: exchangeCode,
      code: code,
    );
    final effectiveCurrentPrice = currentPrice == 0 && latestChart != null
        ? latestChart.closePrice
        : currentPrice;
    final exchangeRate = await _fetchUsdKrwRate(
      exchangeCode: exchangeCode,
      code: code,
    );

    return StockDetail(
      name: name,
      code: code,
      marketType: StockMarketType.overseas,
      currentPrice: effectiveCurrentPrice,
      changeRate: changeRate,
      isPositive: _resolveOverseasIsPositive(
        currentPrice: effectiveCurrentPrice,
        previousClosePrice: previousClosePrice,
        sign: quote['sign'] as String?,
        fallbackRate: changeRate,
      ),
      openPrice: openPrice == 0 && latestChart != null
          ? latestChart.openPrice
          : openPrice,
      highPrice: highPrice == 0 && latestChart != null
          ? latestChart.highPrice
          : highPrice,
      lowPrice: lowPrice == 0 && latestChart != null
          ? latestChart.lowPrice
          : lowPrice,
      volume: _toInt(quote['tvol']),
      chartEntries: chartEntries,
      availableBuyQuantity: 0,
      availableCash: 0,
      exchangeCode: exchangeCode,
      marketLabel: _overseasMarketLabel(exchangeCode),
      currencySymbol: r'$',
      priceDecimals: priceDecimals,
      exchangeRate: exchangeRate == 0 ? null : exchangeRate,
      orderBook: orderBook,
      infoItems: infoData.summaryItems,
      infoSections: infoData.sections,
    );
  }

  Future<StockLiveQuote> fetchLiveQuote({
    required String code,
    required StockMarketType marketType,
    String? exchangeCode,
  }) async {
    if (marketType == StockMarketType.overseas) {
      final resolvedExchangeCode = exchangeCode ?? 'NAS';
      final quoteResponse = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/price',
        trId: 'HHDFS00000300',
        queryParameters: {
          'AUTH': '',
          'EXCD': resolvedExchangeCode,
          'SYMB': code,
        },
      );

      final quote =
          quoteResponse['output'] as Map<String, dynamic>? ??
          <String, dynamic>{};
      final priceDecimals = _resolvePriceDecimals(quote['zdiv'], fallback: 2);
      final currentPrice = _scaledPrice(quote['last'], priceDecimals);
      final previousClosePrice = _scaledPrice(quote['base'], priceDecimals);
      final changeRate = _resolveOverseasChangeRate(
        currentPrice: currentPrice,
        previousClosePrice: previousClosePrice,
        fallbackRate: _toDouble(quote['rate']),
      );
      final openPrice = _scaledPrice(quote['base'], priceDecimals);
      final exchangeRate = await _fetchUsdKrwRate(
        exchangeCode: resolvedExchangeCode,
        code: code,
      );

      return StockLiveQuote(
        currentPrice: currentPrice,
        changeRate: changeRate,
        isPositive: _resolveOverseasIsPositive(
          currentPrice: currentPrice,
          previousClosePrice: previousClosePrice,
          sign: quote['sign'] as String?,
          fallbackRate: changeRate,
        ),
        openPrice: openPrice,
        highPrice: currentPrice,
        lowPrice: currentPrice,
        volume: _toInt(quote['tvol']),
        exchangeRate: exchangeRate == 0 ? null : exchangeRate,
      );
    }

    final quoteResponse = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/quotations/inquire-price',
      trId: 'FHKST01010100',
      queryParameters: {'FID_COND_MRKT_DIV_CODE': 'J', 'FID_INPUT_ISCD': code},
    );
    final quote =
        quoteResponse['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final changeRate = _toDouble(quote['prdy_ctrt']);

    return StockLiveQuote(
      currentPrice: _toInt(quote['stck_prpr']),
      changeRate: changeRate,
      isPositive: _isPositive(quote['prdy_vrss_sign'] as String?, changeRate),
      openPrice: _toInt(quote['stck_oprc']),
      highPrice: _toInt(quote['stck_hgpr']),
      lowPrice: _toInt(quote['stck_lwpr']),
      volume: _toInt(quote['acml_vol']),
    );
  }

  Future<List<StockOrderBookLevel>> fetchLiveOrderBook({
    required String code,
    required StockMarketType marketType,
    String? exchangeCode,
    int? priceDecimals,
  }) async {
    if (marketType == StockMarketType.overseas) {
      return _fetchOverseasOrderBook(
        exchangeCode: exchangeCode ?? 'NAS',
        code: code,
        priceDecimals: priceDecimals ?? 2,
      );
    }

    try {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/inquire-asking-price-exp-ccn',
        trId: 'FHKST01010200',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'J',
          'FID_INPUT_ISCD': code,
        },
      );

      final output =
          response['output1'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return List<StockOrderBookLevel>.generate(5, (index) {
            final level = index + 1;
            return StockOrderBookLevel(
              askPrice: _toInt(output['askp$level']),
              askVolume: _toInt(output['askp_rsqn$level']),
              bidPrice: _toInt(output['bidp$level']),
              bidVolume: _toInt(output['bidp_rsqn$level']),
            );
          })
          .where((level) {
            return level.askPrice != 0 ||
                level.askVolume != 0 ||
                level.bidPrice != 0 ||
                level.bidVolume != 0;
          })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<StockChartEntry>> _fetchChartEntries({
    required String code,
    required StockChartPeriod period,
  }) async {
    if (period == StockChartPeriod.oneDay) {
      final now = DateTime.now();
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/inquire-time-dailychartprice',
        trId: 'FHKST03010230',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'J',
          'FID_INPUT_ISCD': code,
          'FID_INPUT_DATE_1': _formatDate(now),
          'FID_INPUT_HOUR_1': '153000',
          'FID_PW_DATA_INCU_YN': 'Y',
          'FID_FAKE_TICK_INCU_YN': 'N',
        },
      );

      return (response['output2'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList()
          .reversed
          .map(
            (item) => StockChartEntry(
              date: item['stck_bsop_date'] as String? ?? '',
              timeLabel: _formatTimeLabel(
                item['stck_cntg_hour'] as String? ?? '',
              ),
              openPrice: _firstNonZeroInt([
                item['stck_oprc'],
                item['stck_prpr'],
              ]),
              highPrice: _firstNonZeroInt([
                item['stck_hgpr'],
                item['stck_prpr'],
              ]),
              lowPrice: _firstNonZeroInt([
                item['stck_lwpr'],
                item['stck_prpr'],
              ]),
              closePrice: _toInt(item['stck_prpr']),
              volume: _toInt(item['cntg_vol']),
            ),
          )
          .toList(growable: false);
    }

    final now = DateTime.now();
    final (periodCode, startDate) = switch (period) {
      StockChartPeriod.oneWeek => ('D', now.subtract(const Duration(days: 7))),
      StockChartPeriod.oneMonth => (
        'D',
        now.subtract(const Duration(days: 30)),
      ),
      StockChartPeriod.oneYear => (
        'W',
        now.subtract(const Duration(days: 365)),
      ),
      StockChartPeriod.all => ('M', now.subtract(const Duration(days: 3650))),
      StockChartPeriod.oneDay => ('D', now.subtract(const Duration(days: 1))),
    };

    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice',
      trId: 'FHKST03010100',
      queryParameters: {
        'FID_COND_MRKT_DIV_CODE': 'J',
        'FID_INPUT_ISCD': code,
        'FID_INPUT_DATE_1': _formatDate(startDate),
        'FID_INPUT_DATE_2': _formatDate(now),
        'FID_PERIOD_DIV_CODE': periodCode,
        'FID_ORG_ADJ_PRC': '1',
      },
    );

    final entries = (response['output2'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList()
        .reversed
        .map(
          (item) => StockChartEntry(
            date: item['stck_bsop_date'] as String? ?? '',
            timeLabel: _formatDateLabel(
              item['stck_bsop_date'] as String? ?? '',
            ),
            openPrice: _firstNonZeroInt([item['stck_oprc'], item['stck_clpr']]),
            highPrice: _firstNonZeroInt([item['stck_hgpr'], item['stck_clpr']]),
            lowPrice: _firstNonZeroInt([item['stck_lwpr'], item['stck_clpr']]),
            closePrice: _toInt(item['stck_clpr']),
            volume: _toInt(item['acml_vol']),
          ),
        )
        .toList(growable: false);

    return entries;
  }

  Future<List<StockChartEntry>> _fetchOverseasChartEntries({
    required String exchangeCode,
    required String code,
    required StockChartPeriod period,
    required int priceDecimals,
  }) async {
    if (period == StockChartPeriod.oneDay) {
      final response = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/inquire-time-itemchartprice',
        trId: 'HHDFS76950200',
        queryParameters: {
          'AUTH': '',
          'EXCD': exchangeCode,
          'SYMB': code,
          'NMIN': '5',
          'PINC': '1',
          'NEXT': '',
          'NREC': '120',
          'FILL': '',
          'KEYB': '',
        },
      );

      return (response['output2'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList()
          .reversed
          .map(
            (item) => StockChartEntry(
              date: item['xymd'] as String? ?? '',
              timeLabel: _formatOverseasTimeLabel(
                date: item['xymd'] as String? ?? '',
                time: item['xhms'] as String? ?? '',
                showYear: false,
              ),
              openPrice: _scaledPrice(item['open'], priceDecimals),
              highPrice: _scaledPrice(item['high'], priceDecimals),
              lowPrice: _scaledPrice(item['low'], priceDecimals),
              closePrice: _scaledPrice(item['last'], priceDecimals),
              volume: _toInt(item['evol']),
            ),
          )
          .toList(growable: false);
    }

    final now = DateTime.now();
    final (periodCode, startDate) = switch (period) {
      StockChartPeriod.oneWeek => ('D', now.subtract(const Duration(days: 7))),
      StockChartPeriod.oneMonth => (
        'D',
        now.subtract(const Duration(days: 30)),
      ),
      StockChartPeriod.oneYear => (
        'W',
        now.subtract(const Duration(days: 365)),
      ),
      StockChartPeriod.all => ('M', now.subtract(const Duration(days: 3650))),
      StockChartPeriod.oneDay => ('D', now.subtract(const Duration(days: 1))),
    };

    final response = await _apiClient.get(
      path: '/uapi/overseas-price/v1/quotations/inquire-daily-chartprice',
      trId: 'FHKST03030100',
      queryParameters: {
        'FID_COND_MRKT_DIV_CODE': 'N',
        'FID_INPUT_ISCD': code,
        'FID_INPUT_DATE_1': _formatDate(startDate),
        'FID_INPUT_DATE_2': _formatDate(now),
        'FID_PERIOD_DIV_CODE': periodCode,
      },
    );

    return (response['output2'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList()
        .reversed
        .map(
          (item) => StockChartEntry(
            date: item['xymd'] as String? ?? '',
            timeLabel: _formatDateLabel(
              item['xymd'] as String? ?? '',
              includeYearWhenChanged: true,
            ),
            openPrice: _scaledPrice(item['open'], priceDecimals),
            highPrice: _scaledPrice(item['high'], priceDecimals),
            lowPrice: _scaledPrice(item['low'], priceDecimals),
            closePrice: _scaledPrice(item['clos'], priceDecimals),
            volume: _toInt(item['tvol']),
          ),
        )
        .toList(growable: false);
  }

  Future<List<StockOrderBookLevel>> _fetchOverseasOrderBook({
    required String exchangeCode,
    required String code,
    required int priceDecimals,
  }) async {
    try {
      final response = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/inquire-asking-price',
        trId: 'HHDFS76200100',
        queryParameters: {'AUTH': '', 'EXCD': exchangeCode, 'SYMB': code},
      );

      final output =
          response['output2'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return List<StockOrderBookLevel>.generate(5, (index) {
            final level = index + 1;
            return StockOrderBookLevel(
              askPrice: _scaledPrice(output['pask$level'], priceDecimals),
              askVolume: _toInt(output['vask$level']),
              bidPrice: _scaledPrice(output['pbid$level'], priceDecimals),
              bidVolume: _toInt(output['vbid$level']),
            );
          })
          .where((level) {
            return level.askPrice != 0 ||
                level.askVolume != 0 ||
                level.bidPrice != 0 ||
                level.bidVolume != 0;
          })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<({List<StockInfoItem> summaryItems, List<StockInfoSection> sections})>
  _fetchOverseasInfoData({
    required String exchangeCode,
    required String code,
  }) async {
    try {
      final basicInfoResponse = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/search-info',
        trId: 'CTPF1702R',
        queryParameters: {
          'PRDT_TYPE_CD': _productTypeCodeForExchange(exchangeCode),
          'PDNO': code,
        },
      );
      final detailInfoResponse = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/price-detail',
        trId: 'HHDFS76200200',
        queryParameters: {'AUTH': '', 'EXCD': exchangeCode, 'SYMB': code},
      );

      final basicInfo =
          basicInfoResponse['output'] as Map<String, dynamic>? ??
          <String, dynamic>{};
      final detailInfo =
          detailInfoResponse['output'] as Map<String, dynamic>? ??
          <String, dynamic>{};
      final basicItems = _buildInfoItems(
        output: basicInfo,
        preferredOrder: _overseasBasicInfoFieldOrder,
        labels: _overseasBasicInfoLabels,
        valueTransformers: {
          'ovrs_stck_dvsn_cd': _formatOverseasStockType,
          'ovrs_stck_tr_stop_dvsn_cd': (value) =>
              _overseasTradeStatusLabel(value?.toString()),
          'ovrs_stck_etf_risk_drtp_cd': _formatOverseasEtfRiskType,
          'ovrs_stck_stop_rson_cd': _formatOverseasStopReason,
          'lstg_yn': _formatListedStatus,
          'lstg_abol_item_yn': _formatYesNo,
          'tax_levy_yn': _formatYesNo,
          'mint_svc_yn': _formatYesNo,
          'mint_dcpt_trad_psbl_yn': _formatYesNo,
          'mint_fnum_trad_psbl_yn': _formatYesNo,
          'mint_cblc_cvsn_ipsb_yn': _formatYesNo,
          'ptp_item_yn': _formatYesNo,
          'ptp_item_trfx_exmt_yn': _formatYesNo,
          'dtm_tr_psbl_yn': _formatYesNo,
          'sdrf_stop_ecls_yn': _formatYesNo,
          'lstg_dt': _formatApiDate,
          'mint_svc_yn_chng_dt': _formatApiDate,
          'lstg_abol_dt': _formatApiDate,
          'mint_frst_svc_erlm_dt': _formatApiDate,
          'ptp_item_trfx_exmt_strt_dt': _formatApiDate,
          'ptp_item_trfx_exmt_end_dt': _formatApiDate,
          'sdrf_stop_ecls_erlm_dt': _formatApiDate,
        },
      );
      final detailItems = _buildInfoItems(
        output: detailInfo,
        preferredOrder: _overseasPriceDetailFieldOrder,
        labels: _overseasPriceDetailLabels,
        valueTransformers: {
          'h52d': _formatApiDate,
          'l52d': _formatApiDate,
          't_xsgn': _formatOverseasPriceSign,
          'p_xsng': _formatOverseasPriceSign,
        },
      );

      return (
        summaryItems: _buildOverseasSummaryItems(basicInfo, detailInfo),
        sections: [
          if (basicItems.isNotEmpty)
            StockInfoSection(title: '기본 정보', items: basicItems),
          if (detailItems.isNotEmpty)
            StockInfoSection(title: '상세 지표', items: detailItems),
        ],
      );
    } catch (_) {
      return (
        summaryItems: const <StockInfoItem>[],
        sections: const <StockInfoSection>[],
      );
    }
  }

  Future<double> _fetchUsdKrwRate({
    required String exchangeCode,
    required String code,
  }) async {
    try {
      final response = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/price-detail',
        trId: 'HHDFS76200200',
        queryParameters: {'AUTH': '', 'EXCD': exchangeCode, 'SYMB': code},
      );

      final output =
          response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return _toDouble(output['t_rate']);
    } catch (_) {
      return 0.0;
    }
  }

  Future<String> placeBuyOrder({
    required String code,
    required int quantity,
    required int price,
  }) async {
    _ensureOrderableAccount();
    _ensureDomesticCashOrderSession();
    await _ensureBuyOrderCapacity(
      code: code,
      quantity: quantity,
      price: price,
    );

    final response = await _postCashOrder(
      code: code,
      quantity: quantity,
      price: price,
      trId: _apiClient.useMockServer ? 'VTTC0012U' : 'TTTC0012U',
    );

    return response['msg1'] as String? ?? '매수 주문이 접수되었습니다.';
  }

  Future<String> placeSellOrder({
    required String code,
    required int quantity,
    required int price,
  }) async {
    _ensureOrderableAccount();
    _ensureDomesticCashOrderSession();

    final response = await _postCashOrder(
      code: code,
      quantity: quantity,
      price: price,
      trId: _apiClient.useMockServer ? 'VTTC0011U' : 'TTTC0011U',
      includeSellType: true,
    );

    return response['msg1'] as String? ?? '매도 주문이 접수되었습니다.';
  }

  Future<Map<String, dynamic>> _postCashOrder({
    required String code,
    required int quantity,
    required int price,
    required String trId,
    bool includeSellType = false,
  }) async {
    final orderType = _resolveDomesticOrderType(price);
    final body = <String, dynamic>{
      'CANO': _account.accountNumber,
      'ACNT_PRDT_CD': _account.accountProductCode,
      'PDNO': code,
      'ORD_DVSN': orderType.orderDivision,
      'ORD_QTY': '$quantity',
      'ORD_UNPR': orderType.orderPrice,
    };
    if (includeSellType) {
      body['SLL_TYPE'] = '01';
    }

    try {
      return await _apiClient.postAuthenticated(
        path: '/uapi/domestic-stock/v1/trading/order-cash',
        trId: trId,
        includeHashKey: true,
        body: body,
      );
    } on KisApiException catch (error) {
      if (error.apiCode == 'EGW00202') {
        throw KisApiException(
          '주문 라우팅에 실패했습니다. 장 상태와 주문 가격을 확인한 뒤 다시 시도해주세요.',
          statusCode: error.statusCode,
          apiCode: error.apiCode,
        );
      }
      rethrow;
    }
  }

  void _ensureOrderableAccount() {
    if (!_account.isConfigured) {
      throw const KisApiException('계좌가 선택되지 않아 주문을 진행할 수 없습니다.');
    }
  }

  void _ensureDomesticCashOrderSession() {
    if (_isDomesticRegularSession(DateTime.now())) {
      return;
    }

    throw const KisApiException(
      '국내 주식 정규장 시간이 아니어서 주문할 수 없습니다. 정규장(평일 09:00~15:30)에 다시 시도해주세요.',
      apiCode: 'MARKET_CLOSED',
    );
  }

  Future<void> _ensureBuyOrderCapacity({
    required String code,
    required int quantity,
    required int price,
  }) async {
    final orderType = _resolveDomesticOrderType(price);
    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/trading/inquire-psbl-order',
      trId: _apiClient.useMockServer ? 'VTTC8908R' : 'TTTC8908R',
      queryParameters: {
        'CANO': _account.accountNumber,
        'ACNT_PRDT_CD': _account.accountProductCode,
        'PDNO': code,
        'ORD_UNPR': orderType.orderPrice,
        'ORD_DVSN': orderType.orderDivision,
        'CMA_EVLU_AMT_ICLD_YN': 'N',
        'OVRS_ICLD_YN': 'N',
      },
    );

    final output =
        response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final availableBuyQuantity = _firstPositiveInt([
      output['nrcvb_buy_qty'],
      output['max_buy_qty'],
      output['ord_psbl_qty'],
    ]);
    final availableCash = _firstPositiveInt([
      output['ord_psbl_cash'],
      output['ord_psbl_frcr_amt_wcrc'],
    ]);

    if (availableBuyQuantity <= 0) {
      if (availableCash <= 0) {
        throw const KisApiException('주문 가능 금액이 부족해 매수할 수 없습니다.');
      }
      throw const KisApiException(
        '현재 계좌에서 해당 주문 조건으로 매수 가능한 수량을 확인하지 못했습니다. 주문 가격을 다시 확인해주세요.',
      );
    }

    if (quantity > availableBuyQuantity) {
      throw KisApiException(
        '매수 가능 수량을 초과했습니다. 현재 주문 가능한 수량은 $availableBuyQuantity주입니다.',
      );
    }
  }

  _DomesticOrderType _resolveDomesticOrderType(int price) {
    final sanitizedPrice = price > 0 ? price : 0;
    final isLimitOrder = sanitizedPrice > 0;
    return _DomesticOrderType(
      orderDivision: isLimitOrder ? '00' : '01',
      orderPrice: isLimitOrder ? '$sanitizedPrice' : '0',
    );
  }

  bool _isDomesticRegularSession(DateTime now) {
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }

    final minuteOfDay = (now.hour * 60) + now.minute;
    const marketOpenMinute = 9 * 60;
    const marketCloseMinute = (15 * 60) + 30;
    return minuteOfDay >= marketOpenMinute && minuteOfDay < marketCloseMinute;
  }

  int _toInt(dynamic value) {
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  int _firstNonZeroInt(List<dynamic> values) {
    for (final value in values) {
      final parsed = _toInt(value);
      if (parsed != 0) {
        return parsed;
      }
    }

    return 0;
  }

  int _firstPositiveInt(List<dynamic> values) {
    for (final value in values) {
      final parsed = _toInt(value);
      if (parsed > 0) {
        return parsed;
      }
    }

    return 0;
  }

  double _toDouble(dynamic value) {
    return double.tryParse('${value ?? ''}'.trim()) ?? 0.0;
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

  double _deriveChangeRate(List<StockChartEntry> entries) {
    if (entries.length < 2) {
      return 0.0;
    }

    final previous = entries[entries.length - 2].closePrice;
    final current = entries.last.closePrice;
    if (previous == 0) {
      return 0.0;
    }

    return ((current - previous) / previous) * 100;
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _formatTimeLabel(String value) {
    if (value.length < 4) {
      return value;
    }

    final hour = value.substring(0, 2);
    final minute = value.substring(2, 4);
    return '$hour:$minute';
  }

  String _formatDateLabel(String value, {bool includeYearWhenChanged = false}) {
    if (value.length != 8) {
      return value;
    }

    final currentYear = DateTime.now().year.toString().padLeft(4, '0');
    if (includeYearWhenChanged && value.substring(0, 4) != currentYear) {
      return '${value.substring(0, 4)}/${value.substring(4, 6)}/${value.substring(6, 8)}';
    }

    return '${value.substring(4, 6)}/${value.substring(6, 8)}';
  }

  String _formatOverseasTimeLabel({
    required String date,
    required String time,
    required bool showYear,
  }) {
    if (date.length != 8 || time.length < 4) {
      return time;
    }

    final prefix =
        showYear || date.substring(0, 4) != DateTime.now().year.toString()
        ? '${date.substring(0, 4)}/${date.substring(4, 6)}/${date.substring(6, 8)} '
        : '${date.substring(4, 6)}/${date.substring(6, 8)} ';
    return '$prefix${time.substring(0, 2)}:${time.substring(2, 4)}';
  }

  int _resolvePriceDecimals(dynamic value, {int fallback = 0}) {
    final parsed = int.tryParse('${value ?? ''}'.trim());
    if (parsed == null || parsed < 0) {
      return fallback;
    }
    return parsed;
  }

  int _scaledPrice(dynamic value, int decimals) {
    final parsed = double.tryParse('${value ?? ''}'.trim()) ?? 0.0;
    final scale = decimals <= 0 ? 1 : _pow10(decimals);
    return (parsed * scale).round();
  }

  int _pow10(int exponent) {
    var result = 1;
    for (var i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  String _productTypeCodeForExchange(String exchangeCode) {
    switch (exchangeCode) {
      case 'NYS':
      case 'NYSE':
        return '513';
      case 'AMS':
      case 'AMEX':
        return '529';
      case 'NAS':
      default:
        return '512';
    }
  }

  String _overseasMarketLabel(String exchangeCode) {
    switch (exchangeCode) {
      case 'NYS':
        return '미국 · 뉴욕';
      case 'AMS':
        return '미국 · 아멕스';
      case 'NAS':
      default:
        return '미국 · 나스닥';
    }
  }

  String _overseasTradeStatusLabel(String? code) {
    switch (code) {
      case '01':
        return '정상';
      case '02':
        return '거래정지';
      case '03':
        return '거래중단';
      case '04':
        return '매도정지';
      case '06':
        return '매수정지';
      default:
        return '-';
    }
  }

  List<StockInfoItem> _buildOverseasSummaryItems(
    Map<String, dynamic> basicInfo,
    Map<String, dynamic> detailInfo,
  ) {
    final summary = <StockInfoItem>[
      StockInfoItem(
        label: '거래소',
        value: _stringValue(basicInfo['ovrs_excg_name']),
      ),
      StockInfoItem(label: '통화', value: _stringValue(basicInfo['crcy_name'])),
      StockInfoItem(
        label: '상품분류',
        value: _stringValue(basicInfo['prdt_clsf_name']),
      ),
      StockInfoItem(
        label: '상장여부',
        value: _formatListedStatus(basicInfo['lstg_yn']),
      ),
      StockInfoItem(
        label: '거래상태',
        value: _overseasTradeStatusLabel(
          basicInfo['ovrs_stck_tr_stop_dvsn_cd'] as String?,
        ),
      ),
      StockInfoItem(
        label: '블룸버그',
        value: _stringValue(basicInfo['blbg_tckr_text']),
      ),
      StockInfoItem(label: 'PER', value: _stringValue(detailInfo['perx'])),
      StockInfoItem(label: 'PBR', value: _stringValue(detailInfo['pbrx'])),
    ];
    return summary.where((item) => item.value != '-').toList(growable: false);
  }

  List<StockInfoItem> _buildInfoItems({
    required Map<String, dynamic> output,
    required List<String> preferredOrder,
    required Map<String, String> labels,
    required Map<String, String Function(dynamic value)> valueTransformers,
  }) {
    final orderedKeys = <String>[
      ...preferredOrder,
      ...output.keys.where((key) => !preferredOrder.contains(key)).toList()
        ..sort(),
    ];

    final items = <StockInfoItem>[];
    for (final key in orderedKeys) {
      final rawValue = output[key];
      final value =
          valueTransformers[key]?.call(rawValue) ?? _stringValue(rawValue);
      if (value == '-' || value.isEmpty) {
        continue;
      }
      items.add(StockInfoItem(label: labels[key] ?? key, value: value));
    }
    return items;
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == '00000000') {
      return '-';
    }
    return text;
  }

  String _formatYesNo(dynamic value) {
    return switch (_stringValue(value)) {
      'Y' => '예',
      'N' => '아니오',
      final other => other,
    };
  }

  String _formatListedStatus(dynamic value) {
    return switch (_stringValue(value)) {
      'Y' => '상장',
      'N' => '비상장',
      final other => other,
    };
  }

  String _formatApiDate(dynamic value) {
    final raw = _stringValue(value);
    if (raw == '-' || raw.length != 8) {
      return raw;
    }
    return '${raw.substring(0, 4)}.${raw.substring(4, 6)}.${raw.substring(6, 8)}';
  }

  String _formatOverseasStockType(dynamic value) {
    return switch (_stringValue(value)) {
      '01' => '주식',
      '02' => '워런트',
      '03' => 'ETF',
      '04' => '우선주',
      final other => other,
    };
  }

  String _formatOverseasEtfRiskType(dynamic value) {
    return switch (_stringValue(value)) {
      '001' => 'ETF',
      '002' => 'ETN',
      '003' => 'ETC',
      '004' => '기타',
      '005' => 'VIX 기초 ETF',
      '006' => 'VIX 기초 ETN',
      final other => other,
    };
  }

  String _formatOverseasStopReason(dynamic value) {
    return switch (_stringValue(value)) {
      '01' => '권리발생',
      '02' => 'ISIN 상이',
      '03' => '기타',
      '04' => '급등락종목',
      '05' => '상장폐지 예정',
      '06' => '종목코드/거래소 변경',
      '07' => 'PTP 종목',
      final other => other,
    };
  }

  String _formatOverseasPriceSign(dynamic value) {
    return switch (_stringValue(value)) {
      '1' => '상한',
      '2' => '상승',
      '3' => '보합',
      '4' => '하한',
      '5' => '하락',
      final other => other,
    };
  }

  static const List<String> _overseasBasicInfoFieldOrder = [
    'prdt_name',
    'prdt_eng_name',
    'ovrs_item_name',
    'std_pdno',
    'istt_usge_isin_cd',
    'sedol_no',
    'lei_cd',
    'natn_name',
    'tr_mket_name',
    'ovrs_excg_name',
    'ovrs_excg_cd',
    'crcy_name',
    'ovrs_stck_dvsn_cd',
    'prdt_clsf_name',
    'ovrs_papr',
    'sll_unit_qty',
    'buy_unit_qty',
    'tr_unit_amt',
    'lstg_stck_num',
    'lstg_dt',
    'lstg_yn',
    'lstg_abol_item_yn',
    'lstg_abol_dt',
    'ovrs_stck_tr_stop_dvsn_cd',
    'ovrs_stck_stop_rson_cd',
    'ovrs_stck_prdt_grp_no',
    'ovrs_stck_erlm_rosn_cd',
    'ovrs_stck_hist_rght_dvsn_cd',
    'blbg_tckr_text',
    'ovrs_stck_etf_risk_drtp_cd',
    'etp_chas_erng_rt_dbnb',
    'tax_levy_yn',
    'mint_svc_yn',
    'mint_svc_yn_chng_dt',
    'mint_frst_svc_erlm_dt',
    'mint_dcpt_trad_psbl_yn',
    'mint_fnum_trad_psbl_yn',
    'mint_cblc_cvsn_ipsb_yn',
    'dtm_tr_psbl_yn',
    'ptp_item_yn',
    'ptp_item_trfx_exmt_yn',
    'ptp_item_trfx_exmt_strt_dt',
    'ptp_item_trfx_exmt_end_dt',
    'sdrf_stop_ecls_yn',
    'sdrf_stop_ecls_erlm_dt',
    'chng_bf_pdno',
    'prdt_type_cd_2',
  ];

  static const Map<String, String> _overseasBasicInfoLabels = {
    'prdt_name': '상품명',
    'prdt_eng_name': '상품 영문명',
    'ovrs_item_name': '해외 종목명',
    'std_pdno': '표준상품번호',
    'istt_usge_isin_cd': 'ISIN 코드',
    'sedol_no': 'SEDOL 번호',
    'lei_cd': 'LEI 코드',
    'natn_name': '국가',
    'tr_mket_name': '거래시장',
    'ovrs_excg_name': '거래소',
    'ovrs_excg_cd': '거래소 코드',
    'crcy_name': '통화',
    'ovrs_stck_dvsn_cd': '종목 구분',
    'prdt_clsf_name': '상품 분류',
    'ovrs_papr': '액면가',
    'sll_unit_qty': '매도 단위 수량',
    'buy_unit_qty': '매수 단위 수량',
    'tr_unit_amt': '거래 단위 금액',
    'lstg_stck_num': '상장 주식 수',
    'lstg_dt': '상장일',
    'lstg_yn': '상장 여부',
    'lstg_abol_item_yn': '상장폐지 종목 여부',
    'lstg_abol_dt': '상장폐지일',
    'ovrs_stck_tr_stop_dvsn_cd': '거래 상태',
    'ovrs_stck_stop_rson_cd': '거래 정지 사유',
    'ovrs_stck_prdt_grp_no': '상품 그룹 번호',
    'ovrs_stck_erlm_rosn_cd': '등록 사유 코드',
    'ovrs_stck_hist_rght_dvsn_cd': '이력 권리 구분 코드',
    'blbg_tckr_text': '블룸버그 티커',
    'ovrs_stck_etf_risk_drtp_cd': 'ETF 위험 지표',
    'etp_chas_erng_rt_dbnb': 'ETP 추적 수익률',
    'tax_levy_yn': '과세 여부',
    'mint_svc_yn': '소수점 서비스 여부',
    'mint_svc_yn_chng_dt': '소수점 서비스 변경일',
    'mint_frst_svc_erlm_dt': '소수점 서비스 등록일',
    'mint_dcpt_trad_psbl_yn': '소수점 매매 가능',
    'mint_fnum_trad_psbl_yn': '소수점 정수 매매 가능',
    'mint_cblc_cvsn_ipsb_yn': '소수점 잔고 전환 불가',
    'dtm_tr_psbl_yn': '주간거래 가능',
    'ptp_item_yn': 'PTP 종목 여부',
    'ptp_item_trfx_exmt_yn': 'PTP 원천징수 면제',
    'ptp_item_trfx_exmt_strt_dt': 'PTP 면제 시작일',
    'ptp_item_trfx_exmt_end_dt': 'PTP 면제 종료일',
    'sdrf_stop_ecls_yn': '증권신고서 정정 공시 중단',
    'sdrf_stop_ecls_erlm_dt': '증권신고서 중단 등록일',
    'chng_bf_pdno': '변경 전 상품번호',
    'prdt_type_cd_2': '보조 상품유형코드',
  };

  static const List<String> _overseasPriceDetailFieldOrder = [
    'curr',
    'zdiv',
    'vnit',
    'e_hogau',
    'e_ordyn',
    'e_icod',
    'etyp_nm',
    'open',
    'high',
    'low',
    'last',
    'base',
    'h52p',
    'h52d',
    'l52p',
    'l52d',
    'perx',
    'pbrx',
    'epsx',
    'bpsx',
    'shar',
    'mcap',
    'tomv',
    'pvol',
    'pamt',
    'tvol',
    'tamt',
    'uplp',
    'dnlp',
    't_xprc',
    't_xdif',
    't_xrat',
    't_xsgn',
    'p_xprc',
    'p_xdif',
    'p_xrat',
    'p_xsng',
    't_rate',
    'p_rate',
    'e_parp',
    'rsym',
  ];

  static const Map<String, String> _overseasPriceDetailLabels = {
    'curr': '통화 코드',
    'zdiv': '소수점 자리수',
    'vnit': '매매 단위',
    'e_hogau': '호가 단위',
    'e_ordyn': '매매 가능 여부',
    'e_icod': '업종',
    'etyp_nm': '상장 유형명',
    'open': '시가',
    'high': '고가',
    'low': '저가',
    'last': '현재가',
    'base': '기준가',
    'h52p': '52주 최고가',
    'h52d': '52주 최고일',
    'l52p': '52주 최저가',
    'l52d': '52주 최저일',
    'perx': 'PER',
    'pbrx': 'PBR',
    'epsx': 'EPS',
    'bpsx': 'BPS',
    'shar': '발행주식수',
    'mcap': '시가총액',
    'tomv': '거래대금',
    'pvol': '전일 거래량',
    'pamt': '전일 거래대금',
    'tvol': '당일 거래량',
    'tamt': '당일 거래대금',
    'uplp': '상한가',
    'dnlp': '하한가',
    't_xprc': '원화 현재가',
    't_xdif': '원화 대비',
    't_xrat': '원화 등락률',
    't_xsgn': '원화 등락 부호',
    'p_xprc': '전일 원화 현재가',
    'p_xdif': '전일 원화 대비',
    'p_xrat': '전일 원화 등락률',
    'p_xsng': '전일 원화 등락 부호',
    't_rate': '당일 환율',
    'p_rate': '전일 환율',
    'e_parp': '액면가',
    'rsym': '실시간 종목키',
  };
}

class _DomesticOrderType {
  const _DomesticOrderType({
    required this.orderDivision,
    required this.orderPrice,
  });

  final String orderDivision;
  final String orderPrice;
}
