import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_exception.dart';
import '../models/account_profile.dart';
import '../models/stock_detail.dart';

class StockDetailRepository {
  StockDetailRepository(this._apiClient, this._account);

  final KisApiClient _apiClient;
  final AccountProfile _account;

  Future<StockDetail> fetchStockDetail({
    required String code,
    required String name,
    required StockChartPeriod period,
  }) async {
    final quoteResponse = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/quotations/inquire-price',
      trId: 'FHKST01010100',
      queryParameters: {
        'FID_COND_MRKT_DIV_CODE': 'J',
        'FID_INPUT_ISCD': code,
      },
    );

    final quote = quoteResponse['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final chartEntries = await _fetchChartEntries(code: code, period: period);

    final latestChart =
        chartEntries.isEmpty ? null : chartEntries.last;
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

        final output = buyableResponse['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
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
    );
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
              timeLabel: _formatTimeLabel(item['stck_cntg_hour'] as String? ?? ''),
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
      StockChartPeriod.oneMonth => ('D', now.subtract(const Duration(days: 30))),
      StockChartPeriod.oneYear => ('W', now.subtract(const Duration(days: 365))),
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
            timeLabel: _formatDateLabel(item['stck_bsop_date'] as String? ?? ''),
            openPrice: _firstNonZeroInt([
              item['stck_oprc'],
              item['stck_clpr'],
            ]),
            highPrice: _firstNonZeroInt([
              item['stck_hgpr'],
              item['stck_clpr'],
            ]),
            lowPrice: _firstNonZeroInt([
              item['stck_lwpr'],
              item['stck_clpr'],
            ]),
            closePrice: _toInt(item['stck_clpr']),
            volume: _toInt(item['acml_vol']),
          ),
        )
        .toList(growable: false);

    return entries;
  }

  Future<String> placeMarketBuyOrder({
    required String code,
    required int quantity,
  }) async {
    _ensureOrderableAccount();

    final response = await _apiClient.postAuthenticated(
      path: '/uapi/domestic-stock/v1/trading/order-cash',
      trId: _apiClient.useMockServer ? 'VTTC0012U' : 'TTTC0012U',
      includeHashKey: true,
      body: {
        'CANO': _account.accountNumber,
        'ACNT_PRDT_CD': _account.accountProductCode,
        'PDNO': code,
        'ORD_DVSN': '01',
        'ORD_QTY': '$quantity',
        'ORD_UNPR': '0',
      },
    );

    return response['msg1'] as String? ?? '매수 주문이 접수되었습니다.';
  }

  Future<String> placeMarketSellOrder({
    required String code,
    required int quantity,
  }) async {
    _ensureOrderableAccount();

    final response = await _apiClient.postAuthenticated(
      path: '/uapi/domestic-stock/v1/trading/order-cash',
      trId: _apiClient.useMockServer ? 'VTTC0011U' : 'TTTC0011U',
      includeHashKey: true,
      body: {
        'CANO': _account.accountNumber,
        'ACNT_PRDT_CD': _account.accountProductCode,
        'PDNO': code,
        'SLL_TYPE': '01',
        'ORD_DVSN': '01',
        'ORD_QTY': '$quantity',
        'ORD_UNPR': '0',
      },
    );

    return response['msg1'] as String? ?? '매도 주문이 접수되었습니다.';
  }

  void _ensureOrderableAccount() {
    if (!_account.isConfigured) {
      throw const KisApiException('계좌가 선택되지 않아 주문을 진행할 수 없습니다.');
    }
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

  String _formatDateLabel(String value) {
    if (value.length != 8) {
      return value;
    }

    final currentYear = DateTime.now().year.toString().padLeft(4, '0');
    if (value.substring(0, 4) != currentYear) {
      return '${value.substring(0, 4)}/${value.substring(4, 6)}/${value.substring(6, 8)}';
    }

    return '${value.substring(4, 6)}/${value.substring(6, 8)}';
  }
}
