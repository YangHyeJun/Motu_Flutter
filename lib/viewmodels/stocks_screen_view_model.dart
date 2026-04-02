import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/kis_realtime_conf.dart';
import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../providers/api_provider.dart';
import '../repositories/stocks_market_repository.dart';
import 'stocks_screen_view_state.dart';

class StocksScreenViewModel extends AutoDisposeNotifier<StocksScreenViewState> {
  static const pageSize = 30;
  static const _subscriptionOwnerId = 'stocks_view';

  late final StocksMarketRepository _stocksMarketRepository;
  late final KisRealtimeConf _realtimeConf;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  double? _currentExchangeRate;
  List<RankingStock> _visibleStocks = const <RankingStock>[];

  void bind({
    required StocksMarketRepository stocksMarketRepository,
    required KisRealtimeConf realtimeConf,
  }) {
    _stocksMarketRepository = stocksMarketRepository;
    _realtimeConf = realtimeConf;
  }

  @override
  StocksScreenViewState build() {
    bind(
      stocksMarketRepository: ref.read(stocksMarketRepositoryProvider),
      realtimeConf: ref.read(kisRealtimeConfProvider),
    );
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _connectionSubscription?.cancel();
      unawaited(clearRealtimeSubscription());
    });
    Future<void>.microtask(_attachRealtime);
    return StocksScreenViewState(
      selectedMarket: 'domestic',
      selectedCategory: 'tradeAmount',
      searchQuery: '',
      showKrwForOverseas: false,
      visibleCount: pageSize,
      isRefreshing: false,
      lastRefreshTime: DateTime.now(),
      errorMessage: null,
      connectionState: const KisRealtimeConnectionState(
        status: KisRealtimeConnectionStatus.disconnected,
      ),
      subscribedRealtimeKeys: const <String>{},
      requestedLiveQuoteKeys: const <String>{},
      visibleRealtimeSignature: '',
      displayVisibleStocks: const <RankingStock>[],
      liveDomesticPrices: const <String, RealtimeDomesticPrice>{},
      liveOverseasPrices: const <String, RealtimeOverseasPrice>{},
      liveQuoteStocks: const <String, RankingStock>{},
    );
  }

  void _attachRealtime() {
    if (_realtimeSubscription != null) {
      return;
    }

    applyRealtimeSnapshot(_realtimeConf.snapshot);
    updateConnectionState(_realtimeConf.connectionState);
    _realtimeSubscription = _realtimeConf.stream.listen(applyRealtimeSnapshot);
    _connectionSubscription = _realtimeConf.connectionStateStream.listen((
      nextState,
    ) {
      final previousStatus = state.connectionState.status;
      updateConnectionState(nextState);
      if (nextState.status == KisRealtimeConnectionStatus.connected &&
          previousStatus != KisRealtimeConnectionStatus.connected &&
          _visibleStocks.isNotEmpty) {
        unawaited(
          _handleVisibleStocksChanged(
            visibleStocks: _visibleStocks,
            forceSubscriptionSync: true,
          ),
        );
      }
    });
  }

  Future<void> handleAppResumed() async {
    if (_visibleStocks.isEmpty) {
      return;
    }
    await _handleVisibleStocksChanged(
      visibleStocks: _visibleStocks,
      forceSubscriptionSync: true,
    );
  }

  void updateSearchQuery(String query) {
    if (state.searchQuery == query) {
      return;
    }
    state = state.copyWith(searchQuery: query, visibleCount: pageSize);
  }

  void clearSearchQuery() {
    updateSearchQuery('');
  }

  void updateMarket(String market) {
    if (state.selectedMarket == market) {
      return;
    }
    state = state.copyWith(selectedMarket: market, visibleCount: pageSize);
  }

  void updateCategory(String category) {
    if (state.selectedCategory == category) {
      return;
    }
    state = state.copyWith(selectedCategory: category, visibleCount: pageSize);
  }

  void toggleShowKrwForOverseas(bool value) {
    if (state.showKrwForOverseas == value) {
      return;
    }
    state = state.copyWith(showKrwForOverseas: value);
    _rebuildDisplayVisibleStocks();
  }

  void loadMore(int totalCount) {
    if (totalCount <= state.visibleCount) {
      return;
    }
    state = state.copyWith(
      visibleCount: (state.visibleCount + pageSize).clamp(0, totalCount),
    );
  }

  void applyRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    state = state.copyWith(
      liveDomesticPrices: Map<String, RealtimeDomesticPrice>.from(
        snapshot.domesticStockPrices,
      ),
      liveOverseasPrices: Map<String, RealtimeOverseasPrice>.from(
        snapshot.overseasStockPrices,
      ),
      lastRefreshTime: DateTime.now(),
    );
    _rebuildDisplayVisibleStocks();
  }

  void updateConnectionState(KisRealtimeConnectionState connectionState) {
    state = state.copyWith(connectionState: connectionState);
  }

  Future<void> refresh() async {
    final trimmedSearchQuery = state.searchQuery.trim();
    state = state.copyWith(isRefreshing: true, clearErrorMessage: true);

    if (trimmedSearchQuery.isNotEmpty) {
      try {
        ref.invalidate(stockSearchProvider(trimmedSearchQuery));
        await ref.read(stockSearchProvider(trimmedSearchQuery).future);
        state = state.copyWith(
          isRefreshing: false,
          lastRefreshTime: DateTime.now(),
        );
      } catch (_) {
        state = state.copyWith(
          isRefreshing: false,
          errorMessage: '검색 결과를 다시 불러오지 못했습니다.',
        );
      }
      return;
    }

    final query = (
      market: state.selectedMarket,
      category: state.selectedCategory,
    );
    try {
      ref.invalidate(marketStocksProvider(query));
      await ref.read(marketStocksProvider(query).future);
      state = state.copyWith(
        isRefreshing: false,
        lastRefreshTime: DateTime.now(),
      );
    } catch (_) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: '주식 목록을 다시 불러오지 못했습니다.',
      );
    }
  }

  Future<void> syncDisplayedStocks({
    required List<RankingStock> visibleStocks,
    required double? exchangeRate,
    bool forceQuoteRefresh = false,
    bool forceSubscriptionSync = false,
    bool preserveExistingWhenLoading = false,
  }) async {
    if (preserveExistingWhenLoading) {
      return;
    }

    _currentExchangeRate = exchangeRate;
    final nextSignature = visibleStocks.map(stockKey).join('|');
    if (!forceSubscriptionSync &&
        state.visibleRealtimeSignature == nextSignature) {
      _visibleStocks = visibleStocks;
      _rebuildDisplayVisibleStocks();
      return;
    }

    _visibleStocks = visibleStocks;
    state = state.copyWith(visibleRealtimeSignature: nextSignature);
    _rebuildDisplayVisibleStocks();
    await _handleVisibleStocksChanged(
      visibleStocks: visibleStocks,
      forceQuoteRefresh: forceQuoteRefresh,
      forceSubscriptionSync: forceSubscriptionSync,
    );
  }

  Future<void> _handleVisibleStocksChanged({
    required List<RankingStock> visibleStocks,
    bool forceQuoteRefresh = false,
    bool forceSubscriptionSync = false,
  }) async {
    final realtimeKeys = visibleStocks.map(stockKey).toSet();
    if (forceSubscriptionSync ||
        !sameCodes(state.subscribedRealtimeKeys, realtimeKeys)) {
      state = state.copyWith(subscribedRealtimeKeys: realtimeKeys);
      await syncRealtimeSubscription(visibleStocks: visibleStocks);
    }

    await refreshVisibleQuotesIfNeeded(
      visibleStocks,
      forceRefresh: forceQuoteRefresh,
    );
  }

  Future<void> refreshVisibleQuotesIfNeeded(
    List<RankingStock> visibleStocks, {
    bool forceRefresh = false,
  }) async {
    final quoteKeys = visibleStocks.map(stockKey).toSet();
    if (!forceRefresh && sameCodes(state.requestedLiveQuoteKeys, quoteKeys)) {
      return;
    }

    state = state.copyWith(requestedLiveQuoteKeys: quoteKeys);
    try {
      final liveQuotes = await refreshVisibleQuotes(visibleStocks);
      state = state.copyWith(
        liveQuoteStocks: Map<String, RankingStock>.from(liveQuotes),
      );
      _rebuildDisplayVisibleStocks();
    } catch (_) {}
  }

  Future<void> clearRealtimeSubscription() {
    state = state.copyWith(
      subscribedRealtimeKeys: const <String>{},
      requestedLiveQuoteKeys: const <String>{},
      visibleRealtimeSignature: '',
      displayVisibleStocks: const <RankingStock>[],
    );
    return _realtimeConf.clearSubscription(_subscriptionOwnerId);
  }

  void _rebuildDisplayVisibleStocks() {
    final liveVisibleStocks = applyRealtimeStocks(
      _visibleStocks,
      liveDomesticPrices: state.liveDomesticPrices,
      liveOverseasPrices: state.liveOverseasPrices,
      liveQuoteStocks: state.liveQuoteStocks,
    );
    final displayVisibleStocks = applyDisplayCurrency(
      liveVisibleStocks,
      showKrwForOverseas: state.showKrwForOverseas,
      exchangeRate: _currentExchangeRate,
    );
    state = state.copyWith(displayVisibleStocks: displayVisibleStocks);
  }

  List<RankingStock> sliceVisibleStocks(
    List<RankingStock> stocks, {
    required int visibleCount,
  }) {
    final end = visibleCount.clamp(0, stocks.length);
    return stocks.take(end).toList(growable: false);
  }

  List<RankingStock> applyRealtimeStocks(
    List<RankingStock> stocks, {
    required Map<String, RealtimeDomesticPrice> liveDomesticPrices,
    required Map<String, RealtimeOverseasPrice> liveOverseasPrices,
    required Map<String, RankingStock> liveQuoteStocks,
  }) {
    return stocks
        .map((stock) {
          final liveQuote = liveQuoteStocks[stockKey(stock)];
          if (stock.marketType == StockMarketType.domestic) {
            final live = liveDomesticPrices[stock.code];
            if (live == null) {
              return liveQuote ?? stock;
            }

            return RankingStock(
              rank: stock.rank,
              name: stock.name,
              code: stock.code,
              price: live.currentPrice,
              changeRate: live.changeRate,
              extraLabel: stock.extraLabel,
              extraValue: stock.extraValue,
              isPositive: live.isPositive,
              marketType: stock.marketType,
              exchangeCode: stock.exchangeCode,
              productTypeCode: stock.productTypeCode,
              marketLabel: stock.marketLabel,
              currencySymbol: stock.currencySymbol,
              priceDecimals: stock.priceDecimals,
            );
          }

          final liveOverseas = liveOverseasPrices[stockKey(stock)];
          if (liveOverseas == null) {
            return liveQuote ?? stock;
          }

          return RankingStock(
            rank: stock.rank,
            name: stock.name,
            code: stock.code,
            price: liveOverseas.currentPrice,
            changeRate: liveOverseas.changeRate,
            extraLabel: stock.extraLabel,
            extraValue: stock.extraValue,
            isPositive: liveOverseas.isPositive,
            marketType: stock.marketType,
            exchangeCode: stock.exchangeCode,
            productTypeCode: stock.productTypeCode,
            marketLabel: stock.marketLabel,
            currencySymbol: stock.currencySymbol,
            priceDecimals: liveOverseas.priceDecimals,
          );
        })
        .toList(growable: false);
  }

  List<RankingStock> applyDisplayCurrency(
    List<RankingStock> stocks, {
    required bool showKrwForOverseas,
    required double? exchangeRate,
  }) {
    if (!showKrwForOverseas || exchangeRate == null || exchangeRate <= 0) {
      return stocks;
    }

    return stocks
        .map((stock) {
          if (stock.marketType != StockMarketType.overseas) {
            return stock;
          }

          final krwPrice = _convertForeignStockPriceToKrw(
            stock.price,
            decimals: stock.priceDecimals,
            exchangeRate: exchangeRate,
          );
          return RankingStock(
            rank: stock.rank,
            name: stock.name,
            code: stock.code,
            price: krwPrice,
            changeRate: stock.changeRate,
            extraLabel: stock.extraLabel,
            extraValue: stock.extraValue,
            isPositive: stock.isPositive,
            marketType: stock.marketType,
            exchangeCode: stock.exchangeCode,
            productTypeCode: stock.productTypeCode,
            marketLabel: stock.marketLabel,
            currencySymbol: '원',
            priceDecimals: 0,
          );
        })
        .toList(growable: false);
  }

  Future<Map<String, RankingStock>> refreshVisibleQuotes(
    List<RankingStock> visibleStocks,
  ) {
    return _stocksMarketRepository.fetchLiveStocks(visibleStocks);
  }

  Future<void> syncRealtimeSubscription({
    required List<RankingStock> visibleStocks,
  }) async {
    final domesticCodes = visibleStocks
        .where((stock) => stock.marketType == StockMarketType.domestic)
        .map((stock) => stock.code);
    final overseasTargets = visibleStocks
        .where((stock) => stock.marketType == StockMarketType.overseas)
        .map(
          (stock) => OverseasRealtimeTarget(
            code: stock.code,
            exchangeCode: _normalizeOverseasExchangeCode(stock.exchangeCode),
          ),
        )
        .toList(growable: false);

    if (domesticCodes.isEmpty && overseasTargets.isEmpty) {
      await _realtimeConf.clearSubscription(_subscriptionOwnerId);
      return;
    }

    await _realtimeConf.setSubscription(
      ownerId: _subscriptionOwnerId,
      domesticCodes: domesticCodes,
      overseasTargets: overseasTargets,
      includeKospi: false,
    );
  }

  bool sameCodes(Set<String> current, Set<String> next) {
    if (current.length != next.length) {
      return false;
    }
    for (final code in current) {
      if (!next.contains(code)) {
        return false;
      }
    }
    return true;
  }

  String stockKey(RankingStock stock) {
    if (stock.marketType == StockMarketType.domestic) {
      return stock.code;
    }
    return '${_normalizeOverseasExchangeCode(stock.exchangeCode)}:${stock.code.toUpperCase()}';
  }

  String _normalizeOverseasExchangeCode(String? exchangeCode) {
    switch ((exchangeCode ?? 'NAS').trim().toUpperCase()) {
      case 'NASD':
      case 'BAQ':
        return 'NAS';
      case 'NYSE':
      case 'BAY':
        return 'NYS';
      case 'AMEX':
      case 'BAA':
        return 'AMS';
      default:
        return (exchangeCode ?? 'NAS').trim().toUpperCase();
    }
  }

  String marketTitle(String market) {
    switch (market) {
      case 'all':
        return '전체 주식';
      case 'overseas':
        return '해외 주식';
      case 'domestic':
      default:
        return '국내 주식';
    }
  }

  String categoryTitle(String category) {
    switch (category) {
      case 'volume':
        return '거래량';
      case 'changeRate':
        return '등락률';
      case 'marketCap':
        return '시가총액';
      case 'tradeAmount':
      default:
        return '실시간 거래대금';
    }
  }

  int convertForeignStockPriceToKrw(
    int value, {
    required int decimals,
    required double exchangeRate,
  }) {
    return _convertForeignStockPriceToKrw(
      value,
      decimals: decimals,
      exchangeRate: exchangeRate,
    );
  }
}

int _convertForeignStockPriceToKrw(
  int value, {
  required int decimals,
  required double exchangeRate,
}) {
  final scale = _pow10(decimals);
  return ((value / scale) * exchangeRate).round();
}

int _pow10(int exponent) {
  var value = 1;
  for (var index = 0; index < exponent; index++) {
    value *= 10;
  }
  return value;
}
