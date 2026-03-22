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

    final quote = quoteResponse['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final chartEntries = await _fetchDomesticChartEntries(target: target, period: period);

    return MarketIndexDetail(
      name: target.name,
      code: target.code,
      currentValue: _formatNumberString(quote['bstp_nmix_prpr']),
      changeAmount: _formatSignedNumberString(quote['bstp_nmix_prdy_vrss']),
      changeRate: _toDouble(quote['bstp_nmix_prdy_ctrt']),
      isPositive: _isPositive(quote['prdy_vrss_sign'] as String?, _toDouble(quote['bstp_nmix_prdy_ctrt'])),
      openValue: _formatNumberString(quote['bstp_nmix_oprc']),
      highValue: _formatNumberString(quote['bstp_nmix_hgpr']),
      lowValue: _formatNumberString(quote['bstp_nmix_lwpr']),
      volume: _toInt(quote['acml_vol']),
      chartEntries: chartEntries,
    );
  }

  Future<MarketIndexDetail> _fetchOverseasDetail({
    required _MarketIndexTarget target,
    required StockChartPeriod period,
  }) async {
    final quoteResponse = await _fetchOverseasDailyResponse(
      symbol: target.symbolCandidates.first,
      from: DateTime.now().subtract(const Duration(days: 7)),
      to: DateTime.now(),
      periodCode: 'D',
    );

    final quote = quoteResponse['output1'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final chartEntries = await _fetchOverseasChartEntries(target: target, period: period);

    return MarketIndexDetail(
      name: target.name,
      code: target.symbolCandidates.first,
      currentValue: _formatNumberString(quote['ovrs_nmix_prpr']),
      changeAmount: _formatSignedNumberString(quote['ovrs_nmix_prdy_vrss']),
      changeRate: _toDouble(quote['prdy_ctrt']),
      isPositive: _isPositive(quote['prdy_vrss_sign'] as String?, _toDouble(quote['prdy_ctrt'])),
      openValue: _formatNumberString(quote['ovrs_prod_oprc']),
      highValue: _formatNumberString(quote['ovrs_prod_hgpr']),
      lowValue: _formatNumberString(quote['ovrs_prod_lwpr']),
      volume: _toInt(quote['acml_vol']),
      chartEntries: chartEntries,
    );
  }

  Future<List<StockChartEntry>> _fetchDomesticChartEntries({
    required _MarketIndexTarget target,
    required StockChartPeriod period,
  }) async {
    if (period == StockChartPeriod.oneDay) {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/inquire-time-indexchartprice',
        trId: 'FHKUP03500200',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'U',
          'FID_INPUT_ISCD': target.code,
          'FID_INPUT_HOUR_1': '60',
        },
      );

      return _mapChartEntries(
        response['output'] as List<dynamic>? ?? const <dynamic>[],
        dateKey: 'stck_bsop_date',
        timeKey: 'bsop_hour',
        closeKeys: const ['bstp_nmix_prpr'],
        volumeKeys: const ['cntg_vol', 'acml_vol'],
        intraday: true,
      );
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

    return _mapChartEntries(
      response['output2'] as List<dynamic>? ?? const <dynamic>[],
      dateKey: 'stck_bsop_date',
      timeKey: 'stck_bsop_date',
      closeKeys: const ['bstp_nmix_prpr'],
      volumeKeys: const ['acml_vol'],
      intraday: false,
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
            path: '/uapi/overseas-price/v1/quotations/inquire-time-indexchartprice',
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
      StockChartPeriod.oneMonth => ('D', now.subtract(const Duration(days: 30))),
      StockChartPeriod.oneYear => ('W', now.subtract(const Duration(days: 365))),
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
          final volume = volumeKeys
              .map((key) => _toInt(item[key]))
              .firstWhere((value) => value != 0, orElse: () => 0);
          final rawDate = item[dateKey] as String? ?? '';
          final rawTime = item[timeKey] as String? ?? '';

          return StockChartEntry(
            date: rawDate,
            timeLabel: intraday ? _formatTimeLabel(rawTime) : _formatDateLabel(rawTime),
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

  double _toDouble(dynamic value) {
    return double.tryParse('${value ?? ''}'.replaceAll(',', '').trim()) ?? 0.0;
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

    return '${value.substring(0, 4)}.${value.substring(4, 6)}.${value.substring(6, 8)}';
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
  const _MarketIndexTarget.domestic({
    required this.name,
    required this.code,
  }) : isDomestic = true,
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
  '나스닥': _MarketIndexTarget.overseas(name: '나스닥', symbolCandidates: ['.IXIC', 'IXIC', 'COMP']),
};
