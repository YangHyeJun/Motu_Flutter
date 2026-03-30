import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_exception.dart';
import '../models/models.dart';
import 'stocks_market_repository.dart';
import '../viewmodels/home_view_state.dart';

class HomeRepository {
  HomeRepository(this._apiClient, this._account, this._stocksMarketRepository);

  final KisApiClient _apiClient;
  final AccountProfile _account;
  final StocksMarketRepository _stocksMarketRepository;

  Future<HomeViewState?> fetchHomeState({
    required HomeViewState fallback,
  }) async {
    if (!_apiClient.isConfigured || !_account.isConfigured) {
      throw const KisApiException('KIS API 설정이 없어 계좌를 연동할 수 없습니다.');
    }

    String? syncErrorMessage;
    var domesticHoldings = const <HoldingStock>[];
    var usHoldings = fallback.usHoldings;

    try {
      domesticHoldings = await fetchDomesticHoldings();
    } on KisApiException catch (error) {
      syncErrorMessage = _mapAccountSyncError(error);
    }

    final marketIndexes = await fetchMarketIndexes(fallback.marketIndexes);

    try {
      usHoldings = await fetchUsHoldings(fallback.usHoldings);
    } on KisApiException {
      // Overseas holdings can be unavailable even when the selected account itself is linked.
      usHoldings = fallback.usHoldings;
    }

    final summary = _buildPortfolioSummary(
      domesticHoldings: domesticHoldings,
      usHoldings: usHoldings,
      fallback: fallback.summary,
    );

    return fallback.copyWith(
      summary: summary,
      marketIndexes: marketIndexes,
      domesticHoldings: domesticHoldings,
      usHoldings: usHoldings,
      lastUpdated: DateTime.now(),
      accountSyncErrorMessage: syncErrorMessage,
    );
  }

  Future<PortfolioSummary> fetchPortfolioSummary() async {
    List<HoldingStock> domesticHoldings = const <HoldingStock>[];
    try {
      domesticHoldings = await fetchDomesticHoldings();
    } on KisApiException {
      domesticHoldings = const <HoldingStock>[];
    }
    List<HoldingStock> usHoldings = const <HoldingStock>[];
    try {
      usHoldings = await fetchUsHoldings(const <HoldingStock>[]);
    } on KisApiException {
      usHoldings = const <HoldingStock>[];
    }

    return _buildPortfolioSummary(
      domesticHoldings: domesticHoldings,
      usHoldings: usHoldings,
      fallback: const PortfolioSummary(
        asset: 0,
        invested: 0,
        profitRate: 0,
        profitAmount: 0,
      ),
    );
  }

  Future<PortfolioProfitHistory> fetchPortfolioProfitHistory({
    required PortfolioSummary currentSummary,
    Duration range = const Duration(days: 90),
  }) async {
    final end = DateTime.now();
    final start = end.subtract(range);
    final messages = <String>[];
    final entries = <PortfolioProfitHistoryEntry>[];
    var totalProfitRate = 0.0;
    var totalRealizedProfitAmount = 0;

    if (_apiClient.useMockServer) {
      messages.add('모의투자에서는 기간별 손익 API가 제한되어 현재 자산 위주로 표시합니다.');
    } else {
      try {
        final periodProfitResponse = await _apiClient.get(
          path: '/uapi/domestic-stock/v1/trading/inquire-period-profit',
          trId: 'TTTC8708R',
          queryParameters: {
            'CANO': _account.accountNumber,
            'ACNT_PRDT_CD': _account.accountProductCode,
            'INQR_STRT_DT': _formatDate(start),
            'INQR_END_DT': _formatDate(end),
            'PDNO': '',
            'SORT_DVSN': '00',
            'INQR_DVSN': '00',
            'CBLC_DVSN': '00',
            'CTX_AREA_FK100': '',
            'CTX_AREA_NK100': '',
          },
        );
        final tradeProfitResponse = await _apiClient.get(
          path: '/uapi/domestic-stock/v1/trading/inquire-period-trade-profit',
          trId: 'TTTC8715R',
          queryParameters: {
            'CANO': _account.accountNumber,
            'ACNT_PRDT_CD': _account.accountProductCode,
            'INQR_STRT_DT': _formatDate(start),
            'INQR_END_DT': _formatDate(end),
            'SORT_DVSN': '00',
            'CBLC_DVSN': '00',
            'CTX_AREA_FK100': '',
            'CTX_AREA_NK100': '',
          },
        );

        final rawEntries =
            periodProfitResponse['output1'] as List<dynamic>? ??
            const <dynamic>[];
        final summaryOutput =
            periodProfitResponse['output2'] as Map<String, dynamic>? ??
            <String, dynamic>{};
        final tradeSummaryOutput =
            tradeProfitResponse['output2'] as Map<String, dynamic>? ??
            <String, dynamic>{};

        for (final item in rawEntries.whereType<Map<String, dynamic>>()) {
          final tradeDate = _parseApiDate(item['trad_dt'] as String?);
          if (tradeDate == null) {
            continue;
          }

          entries.add(
            PortfolioProfitHistoryEntry(
              date: tradeDate,
              realizedProfitAmount: _toInt(item['rlzt_pfls']),
              profitRate: _toDouble(item['pfls_rt']),
              buyAmount: _toInt(item['buy_amt']),
              sellAmount: _toInt(item['sll_amt']),
              fee: _toInt(item['fee']) + _toInt(item['loan_int']),
              tax: _toInt(item['tl_tax']),
            ),
          );
        }
        entries.sort((left, right) => right.date.compareTo(left.date));
        totalProfitRate = _toDouble(tradeSummaryOutput['tot_pftrt']);
        totalRealizedProfitAmount = _toInt(summaryOutput['tot_rlzt_pfls']);
      } on KisApiException catch (error) {
        messages.add('기간별 손익 API를 불러오지 못해 현재 자산 정보만 표시합니다. (${error.message})');
      } catch (_) {
        messages.add('기간별 손익 데이터를 불러오지 못해 현재 자산 정보만 표시합니다.');
      }
    }

    final balanceSnapshot = await _fetchDomesticBalanceSnapshot();
    final assetCategories = await _fetchAccountAssetCategories();

    return PortfolioProfitHistory(
      totalProfitRate: totalProfitRate,
      totalRealizedProfitAmount: totalRealizedProfitAmount,
      currentAssetAmount: currentSummary.asset,
      currentInvestedAmount: currentSummary.invested,
      currentProfitRate: currentSummary.profitRate,
      currentProfitAmount: currentSummary.profitAmount,
      depositAmount: balanceSnapshot?.depositAmount ?? 0,
      nextDayDepositAmount: balanceSnapshot?.nextDayDepositAmount ?? 0,
      d2DepositAmount: balanceSnapshot?.d2DepositAmount ?? 0,
      securityEvaluationAmount: balanceSnapshot?.securityEvaluationAmount ?? 0,
      totalEvaluationAmount:
          balanceSnapshot?.totalEvaluationAmount ?? currentSummary.asset,
      netAssetAmount: balanceSnapshot?.netAssetAmount ?? currentSummary.asset,
      evaluationProfitAmount:
          balanceSnapshot?.evaluationProfitAmount ??
          currentSummary.profitAmount,
      purchaseAmount:
          balanceSnapshot?.purchaseAmount ?? currentSummary.invested,
      previousTotalAssetAmount: balanceSnapshot?.previousTotalAssetAmount ?? 0,
      assetChangeAmount: balanceSnapshot?.assetChangeAmount ?? 0,
      assetCategories: assetCategories,
      messages: messages,
      entries: entries,
    );
  }

  Future<_DomesticBalanceSnapshot?> _fetchDomesticBalanceSnapshot() async {
    try {
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

      final output =
          (response['output2'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .firstOrNull;
      if (output == null) {
        return null;
      }

      return _DomesticBalanceSnapshot(
        depositAmount: _toInt(output['dnca_tot_amt']),
        nextDayDepositAmount: _toInt(output['nxdy_excc_amt']),
        d2DepositAmount: _toInt(output['prvs_rcdl_excc_amt']),
        securityEvaluationAmount: _toInt(output['scts_evlu_amt']),
        totalEvaluationAmount: _toInt(output['tot_evlu_amt']),
        netAssetAmount: _toInt(output['nass_amt']),
        evaluationProfitAmount: _toInt(output['evlu_pfls_smtl_amt']),
        purchaseAmount: _toInt(output['pchs_amt_smtl_amt']),
        previousTotalAssetAmount: _toInt(output['bfdy_tot_asst_evlu_amt']),
        assetChangeAmount: _toInt(output['asst_icdc_amt']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<PortfolioAssetCategory>> _fetchAccountAssetCategories() async {
    if (_apiClient.useMockServer) {
      return const <PortfolioAssetCategory>[];
    }

    try {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/trading/inquire-account-balance',
        trId: 'CTRP6548R',
        queryParameters: {
          'CANO': _account.accountNumber,
          'ACNT_PRDT_CD': _account.accountProductCode,
        },
      );

      final output = response['output1'] as List<dynamic>? ?? const <dynamic>[];
      final categories = <PortfolioAssetCategory>[];
      for (var index = 0; index < output.length; index++) {
        final item = output[index];
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final evaluationAmount = _toInt(item['evlu_amt']);
        final purchaseAmount = _toInt(item['pchs_amt']);
        final profitAmount = _toInt(item['evlu_pfls_amt']);
        final netAssetAmount = _toInt(item['real_nass_amt']);
        final weightRate = _toDouble(item['whol_weit_rt']);
        if (purchaseAmount == 0 &&
            evaluationAmount == 0 &&
            profitAmount == 0 &&
            netAssetAmount == 0 &&
            weightRate == 0) {
          continue;
        }

        categories.add(
          PortfolioAssetCategory(
            name: _assetCategoryName(index),
            purchaseAmount: purchaseAmount,
            evaluationAmount: evaluationAmount,
            profitAmount: profitAmount,
            netAssetAmount: netAssetAmount,
            weightRate: weightRate,
          ),
        );
      }
      return categories;
    } catch (_) {
      return const <PortfolioAssetCategory>[];
    }
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
          marketType: StockMarketType.domestic,
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

      final output =
          response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
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
    const targets = [('코스피', '0001'), ('코스닥', '1001')];

    try {
      final items = <MarketIndex?>[
        ...await Future.wait(
          targets.map(
            (target) => _fetchMarketIndex(name: target.$1, code: target.$2),
          ),
        ),
        await _fetchOverseasIndex(
          name: '나스닥',
          symbolCandidates: const ['.IXIC', 'IXIC', 'COMP'],
        ),
        await _fetchOverseasIndex(
          name: 'S&P500',
          symbolCandidates: const ['.INX', 'INX', 'SPX'],
        ),
      ];

      final indexes = items.whereType<MarketIndex>().toList();
      return indexes.isEmpty ? fallback : indexes;
    } catch (_) {
      return fallback;
    }
  }

  Future<MarketIndex?> _fetchOverseasIndex({
    required String name,
    required List<String> symbolCandidates,
  }) async {
    for (final symbol in symbolCandidates) {
      try {
        final intraday = await _fetchOverseasIndexIntraday(
          name: name,
          symbol: symbol,
        );
        if (intraday != null) {
          return intraday;
        }
      } catch (_) {
        continue;
      }
    }

    for (final symbol in symbolCandidates) {
      try {
        final daily = await _fetchOverseasIndexDaily(
          name: name,
          symbol: symbol,
        );
        if (daily != null) {
          return daily;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<MarketIndex?> _fetchOverseasIndexIntraday({
    required String name,
    required String symbol,
  }) async {
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

    final chartItems =
        response['output2'] as List<dynamic>? ?? const <dynamic>[];
    final latestValue = _latestOverseasIndexValue(
      chartItems,
      keys: const ['optn_prpr', 'ovrs_nmix_prpr', 'clos'],
    );
    final previousValue = _previousOverseasIndexValue(
      chartItems,
      keys: const ['optn_prpr', 'ovrs_nmix_prpr', 'clos'],
    );
    if (latestValue <= 0 || previousValue <= 0) {
      return null;
    }

    final rate = ((latestValue - previousValue) / previousValue) * 100;
    return MarketIndex(
      name: name,
      value: _formatNumericString(latestValue.toStringAsFixed(2)),
      changeRate: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
      isPositive: rate >= 0,
    );
  }

  Future<MarketIndex?> _fetchOverseasIndexDaily({
    required String name,
    required String symbol,
  }) async {
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

    final output =
        response['output1'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final chartItems =
        response['output2'] as List<dynamic>? ?? const <dynamic>[];
    final latestClose = _latestOverseasIndexValue(
      chartItems,
      keys: const ['clos', 'ovrs_nmix_prpr', 'optn_prpr'],
    );
    final previousClose = _previousOverseasIndexValue(
      chartItems,
      keys: const ['clos', 'ovrs_nmix_prpr', 'optn_prpr'],
    );
    final currentValue = _toDouble(output['ovrs_nmix_prpr']) == 0
        ? latestClose
        : _toDouble(output['ovrs_nmix_prpr']);
    if (currentValue <= 0) {
      return null;
    }
    final rate = _toDouble(output['prdy_ctrt']) == 0 && previousClose > 0
        ? ((currentValue - previousClose) / previousClose) * 100
        : _toDouble(output['prdy_ctrt']);

    return MarketIndex(
      name: name,
      value: _formatNumericString(currentValue.toStringAsFixed(2)),
      changeRate: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
      isPositive: _isPositiveBySign(output['prdy_vrss_sign'] as String?, rate),
    );
  }

  Future<List<HoldingStock>> fetchUsHoldings(
    List<HoldingStock> fallback,
  ) async {
    const exchanges = [('NASD', 'USD'), ('NYSE', 'USD'), ('AMEX', 'USD')];

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
          .expand(
            (response) =>
                response['output1'] as List<dynamic>? ?? const <dynamic>[],
          )
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
          final buyPrice = (_toDouble(item['pchs_avg_pric']) * exchangeRate)
              .round();
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
            marketType: StockMarketType.overseas,
            exchangeCode: _mapOverseasPriceExchangeCode(
              item['ovrs_excg_cd'] as String? ?? '',
            ),
            currencySymbol: r'$',
            priceDecimals: 2,
            exchangeRate: exchangeRate,
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

      final output =
          response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return (_toInt(output['t_xprc']), _toDouble(output['t_rate']));
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
            extraValue:
                '${_toDouble(items[index]['ssts_vol_rlim']).toStringAsFixed(2)}%',
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

  Future<List<HomeNewsItem>> fetchHomeNews(List<HomeNewsItem> fallback) async {
    try {
      final response = await _apiClient.get(
        path: '/uapi/domestic-stock/v1/quotations/news-title',
        trId: 'FHKST01011800',
        queryParameters: const {
          'FID_NEWS_OFER_ENTP_CODE': '',
          'FID_COND_MRKT_CLS_CODE': '',
          'FID_INPUT_ISCD': '',
          'FID_TITL_CNTT': '',
          'FID_INPUT_DATE_1': '',
          'FID_INPUT_HOUR_1': '',
          'FID_RANK_SORT_CLS_CODE': '',
          'FID_INPUT_SRNO': '',
        },
      );

      final items = (response['output'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .take(20)
          .map(
            (item) => HomeNewsItem(
              id: item['cntt_usiq_srno'] as String? ?? '',
              title: item['hts_pbnt_titl_cntt'] as String? ?? '',
              source: item['dorg'] as String? ?? '',
              publishedAt:
                  _parseNewsDateTime(
                    item['data_dt'] as String?,
                    item['data_tm'] as String?,
                  ) ??
                  DateTime.now(),
              linkUrl: _buildNewsSearchUrl(
                title: item['hts_pbnt_titl_cntt'] as String? ?? '',
                source: item['dorg'] as String? ?? '',
              ),
              primaryCode: _firstNonBlank([
                item['iscd1'] as String?,
                item['iscd2'] as String?,
                item['iscd3'] as String?,
              ]),
              primaryName: _firstNonBlank([
                item['kor_isnm1'] as String?,
                item['kor_isnm2'] as String?,
                item['kor_isnm3'] as String?,
              ]),
              categoryCode: item['news_lrdv_code'] as String?,
            ),
          )
          .where((item) => item.title.trim().isNotEmpty)
          .toList(growable: false);

      return items.isEmpty ? fallback : items;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<HomeInvestorFlow>> fetchInvestorFlows(
    List<HomeInvestorFlow> fallback,
  ) async {
    try {
      final responses = await Future.wait([
        _apiClient.get(
          path:
              '/uapi/domestic-stock/v1/quotations/inquire-investor-time-by-market',
          trId: 'FHPTJ04030000',
          queryParameters: const {
            'fid_input_iscd': 'KSP',
            'fid_input_iscd_2': '0001',
          },
        ),
        _apiClient.get(
          path:
              '/uapi/domestic-stock/v1/quotations/inquire-investor-time-by-market',
          trId: 'FHPTJ04030000',
          queryParameters: const {
            'fid_input_iscd': 'KSQ',
            'fid_input_iscd_2': '1001',
          },
        ),
      ]);

      final markets = ['코스피', '코스닥'];
      final items = <HomeInvestorFlow>[];
      for (var index = 0; index < responses.length; index++) {
        final output =
            (responses[index]['output2'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .firstOrNull;
        if (output == null || output.isEmpty) {
          continue;
        }

        items.add(
          HomeInvestorFlow(
            marketLabel: markets[index],
            foreignNetBuyAmount: _toInt(output['frgn_ntby_tr_pbmn']),
            institutionNetBuyAmount: _toInt(output['orgn_ntby_tr_pbmn']),
            individualNetBuyAmount: _toInt(output['prsn_ntby_tr_pbmn']),
          ),
        );
      }

      return items.isEmpty ? fallback : items;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<RankingStock>> fetchDomesticTopMovers(
    List<RankingStock> fallback,
  ) async {
    try {
      final items = await _stocksMarketRepository.fetchDomesticTopMovers(
        limit: 30,
      );
      return items.isEmpty ? fallback : items;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<RankingStock>> fetchDomesticVolumeLeaders(
    List<RankingStock> fallback,
  ) async {
    try {
      final items = await _stocksMarketRepository.fetchDomesticVolumeLeaders(
        limit: 30,
      );
      return items.isEmpty ? fallback : items;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<RankingStock>> fetchOverseasTopMovers(
    List<RankingStock> fallback,
  ) async {
    try {
      final items = await _stocksMarketRepository.fetchOverseasTopMovers(
        limit: 30,
      );
      return items.isEmpty ? fallback : items;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<RankingStock>> fetchOverseasVolumeLeaders(
    List<RankingStock> fallback,
  ) async {
    try {
      final items = await _stocksMarketRepository.fetchOverseasVolumeLeaders(
        limit: 30,
      );
      return items.isEmpty ? fallback : items;
    } catch (_) {
      return fallback;
    }
  }

  String _buildNewsSearchUrl({
    required String title,
    required String source,
  }) {
    final normalizedTitle = title.trim();
    final normalizedSource = source.trim();
    final query = [
      if (normalizedTitle.isNotEmpty) '"$normalizedTitle"',
      if (normalizedSource.isNotEmpty) normalizedSource,
    ].join(' ');
    final encodedQuery = Uri.encodeQueryComponent(query.isEmpty ? title : query);
    return 'https://www.google.com/search?tbm=nws&q=$encodedQuery';
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

  DateTime? _parseNewsDateTime(String? date, String? time) {
    if (date == null || date.length != 8) {
      return null;
    }
    final normalizedTime = (time ?? '').padRight(6, '0');
    if (normalizedTime.length < 6) {
      return null;
    }

    final year = int.tryParse(date.substring(0, 4));
    final month = int.tryParse(date.substring(4, 6));
    final day = int.tryParse(date.substring(6, 8));
    final hour = int.tryParse(normalizedTime.substring(0, 2));
    final minute = int.tryParse(normalizedTime.substring(2, 4));
    final second = int.tryParse(normalizedTime.substring(4, 6));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute, second);
  }

  String? _firstNonBlank(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String _mapAccountSyncError(KisApiException error) {
    if (error.apiCode == 'OPSQ2000' ||
        error.message.contains('INVALID_CHECK_ACNO')) {
      return _account.isIsa
          ? '현재 선택한 ISA 중개형 계좌는 한국투자 OpenAPI의 일반 잔고/자산 조회 API에서 지원되지 않거나 별도 계좌 권한 확인이 필요합니다.'
          : '현재 선택한 계좌는 한국투자 OpenAPI 계좌 조회 검증에서 거절되었습니다. 계좌번호와 상품코드를 확인해주세요.';
    }
    return error.message;
  }

  DateTime? _parseApiDate(String? value) {
    if (value == null || value.length != 8) {
      return null;
    }

    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(4, 6));
    final day = int.tryParse(value.substring(6, 8));
    if (year == null || month == null || day == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  PortfolioSummary _buildPortfolioSummary({
    required List<HoldingStock> domesticHoldings,
    required List<HoldingStock> usHoldings,
    required PortfolioSummary fallback,
  }) {
    final allHoldings = <HoldingStock>[...domesticHoldings, ...usHoldings];

    if (allHoldings.isEmpty) {
      return fallback;
    }

    final invested = allHoldings.fold<int>(
      0,
      (sum, stock) => sum + stock.investedAmount,
    );
    final asset = allHoldings.fold<int>(
      0,
      (sum, stock) => sum + stock.currentAmount,
    );
    final profitAmount = asset - invested;
    final profitRate = invested == 0 ? 0.0 : (profitAmount / invested) * 100.0;

    return PortfolioSummary(
      asset: asset,
      invested: invested,
      profitRate: profitRate,
      profitAmount: profitAmount,
    );
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

      final output =
          response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final rate = _toDouble(output['bstp_nmix_prdy_ctrt']);

      return MarketIndex(
        name: name,
        value: _formatNumericString(output['bstp_nmix_prpr'] as String? ?? '0'),
        changeRate: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
        isPositive: _isPositiveBySign(
          output['prdy_vrss_sign'] as String?,
          rate,
        ),
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

  double _latestOverseasIndexValue(
    List<dynamic> items, {
    required List<String> keys,
  }) {
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      for (final key in keys) {
        final value = _toDouble(raw[key]);
        if (value > 0) {
          return value;
        }
      }
    }

    return 0;
  }

  double _previousOverseasIndexValue(
    List<dynamic> items, {
    required List<String> keys,
  }) {
    var seenLatest = false;
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }

      double value = 0;
      for (final key in keys) {
        value = _toDouble(raw[key]);
        if (value > 0) {
          break;
        }
      }

      if (value <= 0) {
        continue;
      }

      if (!seenLatest) {
        seenLatest = true;
        continue;
      }

      return value;
    }

    return 0;
  }

  String _formatNumericString(String value) {
    final parsed = double.tryParse(value.replaceAll(',', ''));
    if (parsed == null) {
      return value;
    }

    final fixed = parsed.toStringAsFixed(
      parsed.truncateToDouble() == parsed ? 0 : 2,
    );
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

  String _assetCategoryName(int index) {
    const names = [
      '주식',
      '펀드/MMW',
      'IMA',
      '채권',
      'ELS/DLS',
      'WRAP',
      '신탁',
      'RP/발행어음',
      '해외주식',
      '해외채권',
      '금현물',
      'CD/CP',
      '전자단기사채',
      '타사상품',
      '외화전자단기사채',
      '외화 ELS/DLS',
      '외화',
      '예수금',
      '청약자예수금',
      '합계',
    ];
    if (index >= 0 && index < names.length) {
      return names[index];
    }
    return '자산 항목 ${index + 1}';
  }
}

class _DomesticBalanceSnapshot {
  const _DomesticBalanceSnapshot({
    required this.depositAmount,
    required this.nextDayDepositAmount,
    required this.d2DepositAmount,
    required this.securityEvaluationAmount,
    required this.totalEvaluationAmount,
    required this.netAssetAmount,
    required this.evaluationProfitAmount,
    required this.purchaseAmount,
    required this.previousTotalAssetAmount,
    required this.assetChangeAmount,
  });

  final int depositAmount;
  final int nextDayDepositAmount;
  final int d2DepositAmount;
  final int securityEvaluationAmount;
  final int totalEvaluationAmount;
  final int netAssetAmount;
  final int evaluationProfitAmount;
  final int purchaseAmount;
  final int previousTotalAssetAmount;
  final int assetChangeAmount;
}
