import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_exception.dart';
import '../models/models.dart';
import '../viewmodels/home_view_state.dart';

class HomeRepository {
  HomeRepository(this._apiClient, this._account);

  final KisApiClient _apiClient;
  final AccountProfile _account;

  Future<HomeViewState?> fetchHomeState({
    required HomeViewState fallback,
  }) async {
    if (!_apiClient.isConfigured || !_account.isConfigured) {
      throw const KisApiException('KIS API 설정이 없어 계좌를 연동할 수 없습니다.');
    }

    String? syncErrorMessage;
    var summary = const PortfolioSummary(
      asset: 0,
      invested: 0,
      profitRate: 0,
      profitAmount: 0,
    );
    var domesticHoldings = const <HoldingStock>[];
    var usHoldings = fallback.usHoldings;

    try {
      summary = await fetchPortfolioSummary();
      domesticHoldings = await fetchDomesticHoldings();
    } on KisApiException catch (error) {
      syncErrorMessage = _mapAccountSyncError(error);
    }

    final marketIndexes = await fetchMarketIndexes(fallback.marketIndexes);
    final shortSellRankings = await fetchShortSellRankings(
      fallback.shortSellRankings,
    );

    try {
      usHoldings = await fetchUsHoldings(fallback.usHoldings);
    } on KisApiException {
      // Overseas holdings can be unavailable even when the selected account itself is linked.
      usHoldings = fallback.usHoldings;
    }

    return fallback.copyWith(
      summary: summary,
      marketIndexes: marketIndexes,
      domesticHoldings: domesticHoldings,
      usHoldings: usHoldings,
      shortSellRankings: shortSellRankings,
      lastUpdated: DateTime.now(),
      accountSyncErrorMessage: syncErrorMessage,
    );
  }

  Future<PortfolioSummary> fetchPortfolioSummary() async {
    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/trading/inquire-account-balance',
      trId: 'CTRP6548R',
      queryParameters: {
        'CANO': _account.accountNumber,
        'ACNT_PRDT_CD': _account.accountProductCode,
        'INQR_DVSN_1': '',
        'BSPR_BF_DT_APLY_YN': '',
      },
    );

    final output = (response['output2'] as Map<String, dynamic>? ?? <String, dynamic>{});
    final asset = _toInt(output['tot_asst_amt']);
    final invested = _toInt(output['pchs_amt_smtl']);
    final profitAmount = _toInt(output['evlu_pfls_amt_smtl']);
    final profitRate = invested == 0 ? 0.0 : (profitAmount / invested) * 100.0;

    return PortfolioSummary(
      asset: asset,
      invested: invested,
      profitRate: profitRate,
      profitAmount: profitAmount,
    );
  }

  Future<List<HoldingStock>> fetchDomesticHoldings() async {
    final response = await _apiClient.get(
      path: '/uapi/domestic-stock/v1/trading/inquire-balance',
      trId: _apiClient.useMockServer ? 'VTTC8434R' : 'TTTC8434R',
      queryParameters: {
        'CANO': _account.accountNumber,
        'ACNT_PRDT_CD': _account.accountProductCode,
        'AFHR_FLPR_YN': 'N',
        'OFL_YN': '',
        'INQR_DVSN': '02',
        'UNPR_DVSN': '01',
        'FUND_STTL_ICLD_YN': 'N',
        'FNCG_AMT_AUTO_RDPT_YN': 'N',
        'PRCS_DVSN': '01',
        'CTX_AREA_FK100': '',
        'CTX_AREA_NK100': '',
      },
    );

    final output = (response['output1'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where((item) => _toInt(item['hldg_qty']) > 0)
        .toList();

    return Future.wait(
      output.map((item) async {
        final code = item['pdno'] as String? ?? '';
        final quote = await _fetchCurrentPrice(code);
        return HoldingStock(
          name: item['prdt_name'] as String? ?? '',
          code: code,
          quantity: _toInt(item['hldg_qty']),
          buyPrice: _toInt(item['pchs_avg_pric']),
          currentPrice: quote.$1,
          evaluationAmount: _toInt(item['evlu_amt']),
          profitAmount: _toInt(item['evlu_pfls_amt']),
          profitRate: _toDouble(item['evlu_pfls_rt']),
          isPositive: _toDouble(item['evlu_pfls_rt']) >= 0,
        );
      }),
    );
  }

  Future<(int, double, bool)> _fetchCurrentPrice(String code) async {
    try {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/inquire-price',
        trId: 'FHKST01010100',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'J',
          'FID_INPUT_ISCD': code,
        },
      );

      final output = response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final changeRate = _toDouble(output['prdy_ctrt']);
      return (
        _toInt(output['stck_prpr']),
        changeRate,
        _isPositiveBySign(output['prdy_vrss_sign'] as String?, changeRate),
      );
    } catch (_) {
      return (0, 0.0, true);
    }
  }

  Future<List<MarketIndex>> fetchMarketIndexes(
    List<MarketIndex> fallback,
  ) async {
    const targets = [
      ('코스피', '0001'),
      ('코스닥', '1001'),
    ];

    try {
      final items = <MarketIndex?>[
        ...await Future.wait(
          targets.map(
            (target) => _fetchMarketIndex(name: target.$1, code: target.$2),
          ),
        ),
        await _fetchOverseasIndex(name: '나스닥', symbol: '.IXIC'),
      ];

      final indexes = items.whereType<MarketIndex>().toList();
      return indexes.isEmpty ? fallback : indexes;
    } catch (_) {
      return fallback;
    }
  }

  Future<MarketIndex?> _fetchOverseasIndex({
    required String name,
    required String symbol,
  }) async {
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 7));
      final response = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/inquire-daily-chartprice',
        trId: 'FHKST03030100',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'N',
          'FID_INPUT_ISCD': symbol,
          'FID_INPUT_DATE_1': _formatDate(from),
          'FID_INPUT_DATE_2': _formatDate(now),
          'FID_PERIOD_DIV_CODE': 'D',
        },
      );

      final output = response['output1'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final rate = _toDouble(output['prdy_ctrt']);

      return MarketIndex(
        name: name,
        value: _formatNumericString(output['ovrs_nmix_prpr'] as String? ?? '0'),
        changeRate: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
        isPositive: _isPositiveBySign(output['prdy_vrss_sign'] as String?, rate),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<HoldingStock>> fetchUsHoldings(List<HoldingStock> fallback) async {
    const exchanges = [
      ('NASD', 'USD'),
      ('NYSE', 'USD'),
      ('AMEX', 'USD'),
    ];

    try {
      final responses = await Future.wait(
        exchanges.map(
          (exchange) => _apiClient.get(
            path: '/uapi/overseas-stock/v1/trading/inquire-balance',
            trId: _apiClient.useMockServer ? 'VTTS3012R' : 'TTTS3012R',
            queryParameters: {
              'CANO': _account.accountNumber,
              'ACNT_PRDT_CD': _account.accountProductCode,
              'OVRS_EXCG_CD': exchange.$1,
              'TR_CRCY_CD': exchange.$2,
              'CTX_AREA_FK200': '',
              'CTX_AREA_NK200': '',
            },
          ),
        ),
      );

      final items = responses
          .expand((response) => response['output1'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .where((item) => _toInt(item['ovrs_cblc_qty']) > 0)
          .toList();

      final holdings = await Future.wait(
        items.map((item) async {
          final detail = await _fetchOverseasPriceDetail(
            exchangeCode: item['ovrs_excg_cd'] as String? ?? '',
            symbol: item['ovrs_pdno'] as String? ?? '',
          );
          final exchangeRate = detail.$2 == 0 ? 1.0 : detail.$2;
          final buyPrice = (_toDouble(item['pchs_avg_pric']) * exchangeRate).round();
          final currentPrice = detail.$1 == 0
              ? (_toDouble(item['now_pric2']) * exchangeRate).round()
              : detail.$1;
          final evaluationAmount =
              (_toDouble(item['ovrs_stck_evlu_amt']) * exchangeRate).round();
          final profitAmount =
              (_toDouble(item['frcr_evlu_pfls_amt']) * exchangeRate).round();

          return HoldingStock(
            name: item['ovrs_item_name'] as String? ?? '',
            code: item['ovrs_pdno'] as String? ?? '',
            quantity: _toInt(item['ovrs_cblc_qty']),
            buyPrice: buyPrice,
            currentPrice: currentPrice,
            evaluationAmount: evaluationAmount,
            profitAmount: profitAmount,
            profitRate: _toDouble(item['evlu_pfls_rt']),
            isPositive: _toDouble(item['evlu_pfls_rt']) >= 0,
          );
        }),
      );

      return holdings.isEmpty ? fallback : holdings;
    } on KisApiException {
      rethrow;
    } catch (_) {
      return fallback;
    }
  }

  Future<(int, double)> _fetchOverseasPriceDetail({
    required String exchangeCode,
    required String symbol,
  }) async {
    try {
      final response = await _apiClient.get(
        path: '/uapi/overseas-price/v1/quotations/price-detail',
        trId: 'HHDFS76200200',
        queryParameters: {
          'AUTH': '',
          'EXCD': _mapOverseasPriceExchangeCode(exchangeCode),
          'SYMB': symbol,
        },
      );

      final output = response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return (
        _toInt(output['t_xprc']),
        _toDouble(output['t_rate']),
      );
    } catch (_) {
      return (0, 0.0);
    }
  }

  Future<List<RankingStock>> fetchShortSellRankings(
    List<RankingStock> fallback,
  ) async {
    try {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/ranking/short-sale',
        trId: 'FHPST04820000',
        queryParameters: {
          'FID_APLY_RANG_VOL': '0',
          'FID_COND_MRKT_DIV_CODE': 'J',
          'FID_COND_SCR_DIV_CODE': '20482',
          'FID_INPUT_ISCD': '0000',
          'FID_PERIOD_DIV_CODE': 'D',
          'FID_INPUT_CNT_1': '0',
          'FID_TRGT_EXLS_CLS_CODE': '0',
          'FID_TRGT_CLS_CODE': '0',
          'FID_APLY_RANG_PRC_1': '',
          'FID_APLY_RANG_PRC_2': '',
        },
      );

      final items = (response['output'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .take(10)
          .toList();

      if (items.isEmpty) {
        return fallback;
      }

      return [
        for (var index = 0; index < items.length; index++)
          RankingStock(
            rank: index + 1,
            name: items[index]['hts_kor_isnm'] as String? ?? '',
            code: items[index]['mksc_shrn_iscd'] as String? ?? '',
            price: _toInt(items[index]['stck_prpr']),
            changeRate: _toDouble(items[index]['prdy_ctrt']),
            extraLabel: '공매도 비중',
            extraValue: '${_toDouble(items[index]['ssts_vol_rlim']).toStringAsFixed(2)}%',
            isPositive: _isPositiveBySign(
              items[index]['prdy_vrss_sign'] as String?,
              _toDouble(items[index]['prdy_ctrt']),
            ),
          ),
      ];
    } catch (_) {
      return fallback;
    }
  }

  String _mapOverseasPriceExchangeCode(String exchangeCode) {
    switch (exchangeCode) {
      case 'NASD':
        return 'NAS';
      case 'NYSE':
        return 'NYS';
      case 'AMEX':
        return 'AMS';
      case 'SEHK':
        return 'HKS';
      case 'TKSE':
        return 'TSE';
      default:
        return exchangeCode;
    }
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _mapAccountSyncError(KisApiException error) {
    if (error.apiCode == 'OPSQ2000' || error.message.contains('INVALID_CHECK_ACNO')) {
      return _account.isIsa
          ? '현재 선택한 ISA 중개형 계좌는 한국투자 OpenAPI의 일반 잔고/자산 조회 API에서 지원되지 않거나 별도 계좌 권한 확인이 필요합니다.'
          : '현재 선택한 계좌는 한국투자 OpenAPI 계좌 조회 검증에서 거절되었습니다. 계좌번호와 상품코드를 확인해주세요.';
    }
    return error.message;
  }

  Future<MarketIndex?> _fetchMarketIndex({
    required String name,
    required String code,
  }) async {
    try {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/inquire-index-price',
        trId: 'FHPUP02100000',
        queryParameters: {
          'FID_COND_MRKT_DIV_CODE': 'U',
          'FID_INPUT_ISCD': code,
        },
      );

      final output = response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final rate = _toDouble(output['bstp_nmix_prdy_ctrt']);

      return MarketIndex(
        name: name,
        value: _formatNumericString(output['bstp_nmix_prpr'] as String? ?? '0'),
        changeRate: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
        isPositive: _isPositiveBySign(output['prdy_vrss_sign'] as String?, rate),
      );
    } catch (_) {
      return null;
    }
  }

  bool _isPositiveBySign(String? sign, double fallbackRate) {
    if (sign == '1' || sign == '2') {
      return true;
    }
    if (sign == '4' || sign == '5') {
      return false;
    }
    return fallbackRate >= 0;
  }

  int _toInt(Object? value) {
    return _toDouble(value).round();
  }

  double _toDouble(Object? value) {
    return double.tryParse('${value ?? 0}'.replaceAll(',', '')) ?? 0;
  }

  String _formatNumericString(String value) {
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) {
      return value;
    }

    final fixed = parsed.toStringAsFixed(parsed.truncateToDouble() == parsed ? 0 : 2);
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
}
