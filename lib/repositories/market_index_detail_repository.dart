import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_exception.dart';
import '../models/market_index_detail.dart';
import '../models/stock_detail.dart';

class MarketIndexDetailRepository {
  MarketIndexDetailRepository(this._apiClient);

  final KisApiClient _apiClient;

  Future<MarketIndexDetail> fetchMarketIndexDetail({
    required String name,
    required StockChartPeriod period,
  }) async {
    final target = _targets[name];
    if (target == null) {
      throw KisApiException('$name 지수 정보를 찾을 수 없습니다.');
    }

    return target.isDomestic
        ? _fetchDomesticDetail(target: target, period: period)
        : _fetchOverseasDetail(target: target, period: period);
  }

  Future<MarketIndexDetail> _fetchDomesticDetail({
    required _MarketIndexTarget target,
    required StockChartPeriod period,
  }) async {
    final quoteResponse = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/quotations/inquire-index-price',
      trId: 'FHPUP02100000',
      queryParameters: {
        'FID_COND_MRKT_DIV_CODE': 'U',
        'FID_INPUT_ISCD': target.code,
      },
    );

    final quote =
        quoteResponse['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final chartDetail = await _fetchDomesticChartDetail(
      target: target,
      period: period,
    );
    final chartSummary = chartDetail.summary;
    final chartEntries = chartDetail.entries;
    final currentValue = _firstNonZeroDouble([
      quote['bstp_nmix_prpr'],
      chartSummary?['bstp_nmix_prpr'],
      chartEntries.isNotEmpty ? chartEntries.last.closePrice : 0,
    ]);
    final changeAmount = _firstNonZeroDouble([
      quote['bstp_nmix_prdy_vrss'],
      chartSummary?['bstp_nmix_prdy_vrss'],
      chartEntries.length >= 2
          ? chartEntries.last.closePrice -
                chartEntries[chartEntries.length - 2].closePrice
          : 0,
    ]);
    final changeRate = _firstNonZeroDouble([
      quote['bstp_nmix_prdy_ctrt'],
      chartSummary?['bstp_nmix_prdy_ctrt'],
      chartEntries.length >= 2 &&
              chartEntries[chartEntries.length - 2].closePrice > 0
          ? ((chartEntries.last.closePrice -
                        chartEntries[chartEntries.length - 2].closePrice) /
                    chartEntries[chartEntries.length - 2].closePrice) *
                100
          : 0,
    ]);
    final openValue = _firstNonZeroDouble([
      quote['bstp_nmix_oprc'],
      chartSummary?['bstp_nmix_oprc'],
      chartEntries.isNotEmpty ? chartEntries.last.openPrice : 0,
    ]);
    final highValue = _firstNonZeroDouble([
      quote['bstp_nmix_hgpr'],
      chartSummary?['bstp_nmix_hgpr'],
      chartEntries.isNotEmpty ? _chartHigh(chartEntries) : 0,
    ]);
    final lowValue = _firstNonZeroDouble([
      quote['bstp_nmix_lwpr'],
      chartSummary?['bstp_nmix_lwpr'],
      chartEntries.isNotEmpty ? _chartLow(chartEntries) : 0,
    ]);
    final volume = _firstNonZeroInt([
      quote['acml_vol'],
      chartSummary?['acml_vol'],
      chartEntries.isNotEmpty ? chartEntries.last.volume : 0,
    ]);

    return MarketIndexDetail(
      name: target.name,
      code: target.code,
      currentValue: _formatNumberString(currentValue),
      changeAmount: _formatSignedNumberString(changeAmount),
      changeRate: changeRate,
      isPositive: _isPositive(
        quote['prdy_vrss_sign'] as String? ??
            chartSummary?['prdy_vrss_sign'] as String?,
        changeRate,
      ),
      openValue: _formatNumberString(openValue),
      highValue: _formatNumberString(highValue),
      lowValue: _formatNumberString(lowValue),
      volume: volume,
      chartEntries: chartEntries,
    );
  }

  Future<MarketIndexDetail> _fetchOverseasDetail({
    required _MarketIndexTarget target,
    required StockChartPeriod period,
  }) async {
    final chartEntries = await _fetchOverseasChartEntries(
      target: target,
      period: period,
    );
    final quote = await _fetchOverseasQuote(target);
    final latestChart = chartEntries.isEmpty ? null : chartEntries.last;
    final currentValue = _firstNonZeroDouble([
      quote['ovrs_nmix_prpr'],
      quote['optn_prpr'],
      latestChart?.closePrice,
    ]);
    final openValue = _firstNonZeroDouble([
      quote['ovrs_prod_oprc'],
      latestChart?.openPrice,
    ]);
    final highValue = _firstNonZeroDouble([
      quote['ovrs_prod_hgpr'],
      latestChart?.highPrice,
    ]);
    final lowValue = _firstNonZeroDouble([
      quote['ovrs_prod_lwpr'],
      latestChart?.lowPrice,
    ]);
    final changeRate =
        _toDouble(quote['prdy_ctrt']) == 0 && chartEntries.length >= 2
        ? ((chartEntries.last.closePrice -
                      chartEntries[chartEntries.length - 2].closePrice) /
                  chartEntries[chartEntries.length - 2].closePrice) *
              100
        : _toDouble(quote['prdy_ctrt']);
    final changeAmount = _firstNonZeroDouble([
      quote['ovrs_nmix_prdy_vrss'],
      chartEntries.length >= 2
          ? chartEntries.last.closePrice -
                chartEntries[chartEntries.length - 2].closePrice
          : 0,
    ]);

    return MarketIndexDetail(
      name: target.name,
      code: quote['symbol'] as String? ?? target.symbolCandidates.first,
      currentValue: _formatNumberString(currentValue),
      changeAmount: _formatSignedNumberString(changeAmount),
      changeRate: changeRate,
      isPositive: _isPositive(quote['prdy_vrss_sign'] as String?, changeRate),
      openValue: _formatNumberString(openValue),
      highValue: _formatNumberString(highValue),
      lowValue: _formatNumberString(lowValue),
      volume: _toInt(quote['acml_vol']),
      chartEntries: chartEntries,
    );
  }

  Future<Map<String, dynamic>> _fetchOverseasQuote(
    _MarketIndexTarget target,
  ) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 7));

    for (final symbol in target.symbolCandidates) {
      try {
        final response = await _fetchOverseasDailyResponse(
          symbol: symbol,
          from: from,
          to: now,
          periodCode: 'D',
        );
        final quote =
            response['output1'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final currentValue = _firstNonZeroDouble([
          quote['ovrs_nmix_prpr'],
          quote['optn_prpr'],
        ]);
        if (currentValue > 0) {
          return {...quote, 'symbol': symbol};
        }
      } on KisApiException {
        continue;
      }
    }

    return <String, dynamic>{'symbol': target.symbolCandidates.first};
  }

  Future<({Map<String, dynamic>? summary, List<StockChartEntry> entries})>
  _fetchDomesticChartDetail({
    required _MarketIndexTarget target,
    required StockChartPeriod period,
  }) async {
    if (period == StockChartPeriod.oneDay) {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/inquire-time-indexchartprice',
        trId: 'FHKUP03500200',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'U',
          'FID_ETC_CLS_CODE': '0',
          'FID_INPUT_ISCD': target.code,
          'FID_INPUT_HOUR_1': '60',
          'FID_PW_DATA_INCU_YN': 'Y',
        },
      );

      final entries = _mapChartEntries(
        response['output2'] as List<dynamic>? ?? const <dynamic>[],
        dateKey: 'stck_bsop_date',
        timeKey: 'stck_cntg_hour',
        closeKeys: const ['bstp_nmix_prpr'],
        openKeys: const ['bstp_nmix_oprc'],
        highKeys: const ['bstp_nmix_hgpr'],
        lowKeys: const ['bstp_nmix_lwpr'],
        volumeKeys: const ['cntg_vol', 'acml_vol'],
        intraday: true,
      );
      return (
        summary: response['output1'] as Map<String, dynamic>?,
        entries: entries,
      );
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
      path: '/uapi/domestic-stock/v1/quotations/inquire-daily-indexchartprice',
      trId: 'FHKUP03500100',
      queryParameters: {
        'FID_COND_MRKT_DIV_CODE': 'U',
        'FID_INPUT_DATE_1': _formatDate(startDate),
        'FID_INPUT_DATE_2': _formatDate(now),
        'FID_INPUT_ISCD': target.code,
        'FID_PERIOD_DIV_CODE': periodCode,
      },
    );

    return (
      summary: response['output1'] as Map<String, dynamic>?,
      entries: _mapChartEntries(
        response['output2'] as List<dynamic>? ?? const <dynamic>[],
        dateKey: 'stck_bsop_date',
        timeKey: 'stck_bsop_date',
        closeKeys: const ['bstp_nmix_prpr'],
        openKeys: const ['bstp_nmix_oprc'],
        highKeys: const ['bstp_nmix_hgpr'],
        lowKeys: const ['bstp_nmix_lwpr'],
        volumeKeys: const ['acml_vol'],
        intraday: false,
      ),
    );
  }

  Future<List<StockChartEntry>> _fetchOverseasChartEntries({
    required _MarketIndexTarget target,
    required StockChartPeriod period,
  }) async {
    if (period == StockChartPeriod.oneDay) {
      for (final symbol in target.symbolCandidates) {
        try {
          final response = await _apiClient.get(
            path:
                '/uapi/overseas-price/v1/quotations/inquire-time-indexchartprice',
            trId: 'FHKST03030200',
            queryParameters: {
              'FID_COND_MRKT_DIV_CODE': 'N',
              'FID_INPUT_ISCD': symbol,
              'FID_HOUR_CLS_CODE': '0',
              'FID_PW_DATA_INCU_YN': 'Y',
            },
          );

          final entries = _mapChartEntries(
            response['output2'] as List<dynamic>? ?? const <dynamic>[],
            dateKey: 'stck_bsop_date',
            timeKey: 'stck_cntg_hour',
            closeKeys: const ['optn_prpr', 'ovrs_nmix_prpr'],
            openKeys: const [
              'optn_oprc',
              'ovrs_nmix_oprc',
              'optn_prpr',
              'ovrs_nmix_prpr',
            ],
            highKeys: const [
              'optn_hgpr',
              'ovrs_nmix_hgpr',
              'optn_prpr',
              'ovrs_nmix_prpr',
            ],
            lowKeys: const [
              'optn_lwpr',
              'ovrs_nmix_lwpr',
              'optn_prpr',
              'ovrs_nmix_prpr',
            ],
            volumeKeys: const ['cntg_vol', 'acml_vol'],
            intraday: true,
          );
          if (entries.isNotEmpty) {
            return entries;
          }
        } on KisApiException {
          continue;
        }
      }
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
      StockChartPeriod.oneDay => ('D', now.subtract(const Duration(days: 30))),
    };

    for (final symbol in target.symbolCandidates) {
      try {
        final response = await _fetchOverseasDailyResponse(
          symbol: symbol,
          from: startDate,
          to: now,
          periodCode: periodCode,
        );

        final entries = _mapChartEntries(
          response['output2'] as List<dynamic>? ?? const <dynamic>[],
          dateKey: 'xymd',
          timeKey: 'xymd',
          closeKeys: const ['clos', 'ovrs_nmix_prpr'],
          openKeys: const ['open', 'clos', 'ovrs_nmix_prpr'],
          highKeys: const ['high', 'clos', 'ovrs_nmix_prpr'],
          lowKeys: const ['low', 'clos', 'ovrs_nmix_prpr'],
          volumeKeys: const ['tvol', 'acml_vol'],
          intraday: false,
        );
        if (entries.isNotEmpty) {
          return entries;
        }
      } on KisApiException {
        continue;
      }
    }

    return const [];
  }

  Future<Map<String, dynamic>> _fetchOverseasDailyResponse({
    required String symbol,
    required DateTime from,
    required DateTime to,
    required String periodCode,
  }) {
    return _apiClient.get(
      path: '/uapi/overseas-price/v1/quotations/inquire-daily-chartprice',
      trId: 'FHKST03030100',
      queryParameters: {
        'FID_COND_MRKT_DIV_CODE': 'N',
        'FID_INPUT_ISCD': symbol,
        'FID_INPUT_DATE_1': _formatDate(from),
        'FID_INPUT_DATE_2': _formatDate(to),
        'FID_PERIOD_DIV_CODE': periodCode,
      },
    );
  }

  List<StockChartEntry> _mapChartEntries(
    List<dynamic> rawItems, {
    required String dateKey,
    required String timeKey,
    required List<String> closeKeys,
    required List<String> openKeys,
    required List<String> highKeys,
    required List<String> lowKeys,
    required List<String> volumeKeys,
    required bool intraday,
  }) {
    return rawItems
        .whereType<Map<String, dynamic>>()
        .toList()
        .reversed
        .map((item) {
          final close = closeKeys
              .map((key) => _toDouble(item[key]))
              .firstWhere((value) => value != 0, orElse: () => 0);
          final open = openKeys
              .map((key) => _toDouble(item[key]))
              .firstWhere((value) => value != 0, orElse: () => close);
          final high = highKeys
              .map((key) => _toDouble(item[key]))
              .firstWhere((value) => value != 0, orElse: () => close);
          final low = lowKeys
              .map((key) => _toDouble(item[key]))
              .firstWhere((value) => value != 0, orElse: () => close);
          final volume = volumeKeys
              .map((key) => _toInt(item[key]))
              .firstWhere((value) => value != 0, orElse: () => 0);
          final rawDate = item[dateKey] as String? ?? '';
          final rawTime = item[timeKey] as String? ?? '';

          return StockChartEntry(
            date: rawDate,
            timeLabel: intraday
                ? _formatTimeLabel(rawTime)
                : _formatDateLabel(rawTime),
            openPrice: open.round(),
            highPrice: high.round(),
            lowPrice: low.round(),
            closePrice: close.round(),
            volume: volume,
          );
        })
        .where((entry) => entry.closePrice > 0)
        .toList(growable: false);
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

  int _toInt(dynamic value) {
    return _toDouble(value).round();
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
    return double.tryParse('${value ?? ''}'.replaceAll(',', '').trim()) ?? 0.0;
  }

  double _firstNonZeroDouble(List<dynamic> values) {
    for (final value in values) {
      final parsed = _toDouble(value);
      if (parsed != 0) {
        return parsed;
      }
    }
    return 0.0;
  }

  double _chartHigh(List<StockChartEntry> entries) {
    var value = 0.0;
    for (final entry in entries) {
      if (entry.highPrice > value) {
        value = entry.highPrice.toDouble();
      }
    }
    return value;
  }

  double _chartLow(List<StockChartEntry> entries) {
    double? value;
    for (final entry in entries) {
      if (entry.lowPrice <= 0) {
        continue;
      }
      value = value == null
          ? entry.lowPrice.toDouble()
          : entry.lowPrice < value
          ? entry.lowPrice.toDouble()
          : value;
    }
    return value ?? 0.0;
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

  String _formatNumberString(dynamic value) {
    final parsed = _toDouble(value);
    if (parsed == 0) {
      return '0';
    }

    final fixed = parsed.truncateToDouble() == parsed
        ? parsed.toStringAsFixed(0)
        : parsed.toStringAsFixed(2);
    final parts = fixed.split('.');
    final integer = parts.first;
    final decimals = parts.length > 1 ? parts[1] : '';
    final buffer = StringBuffer();

    for (var index = 0; index < integer.length; index++) {
      buffer.write(integer[index]);
      final fromEnd = integer.length - index - 1;
      if (fromEnd > 0 && fromEnd % 3 == 0) {
        buffer.write(',');
      }
    }

    if (decimals.isNotEmpty && decimals != '00') {
      buffer.write('.$decimals');
    }

    return buffer.toString();
  }

  String _formatSignedNumberString(dynamic value) {
    final parsed = _toDouble(value);
    final absolute = _formatNumberString(parsed.abs());
    return '${parsed >= 0 ? '+' : '-'}$absolute';
  }
}

class _MarketIndexTarget {
  const _MarketIndexTarget.domestic({required this.name, required this.code})
    : isDomestic = true,
      symbolCandidates = const [];

  const _MarketIndexTarget.overseas({
    required this.name,
    required this.symbolCandidates,
  }) : isDomestic = false,
       code = '';

  final String name;
  final String code;
  final bool isDomestic;
  final List<String> symbolCandidates;
}

const Map<String, _MarketIndexTarget> _targets = {
  '코스피': _MarketIndexTarget.domestic(name: '코스피', code: '0001'),
  '코스닥': _MarketIndexTarget.domestic(name: '코스닥', code: '1001'),
  '나스닥': _MarketIndexTarget.overseas(
    name: '나스닥',
    symbolCandidates: ['.IXIC', 'IXIC', 'COMP'],
  ),
};
