import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../providers/api_provider.dart';
import 'favorites_view_state.dart';
import 'stocks_screen_view_model.dart';

class FavoritesViewModel extends AutoDisposeNotifier<FavoritesViewState> {
  static const _subscriptionOwnerId = 'favorites_view';

  late final StocksScreenViewModel _stocksViewModel;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  List<RankingStock> _visibleStocks = const <RankingStock>[];

  @override
  FavoritesViewState build() {
    _stocksViewModel = StocksScreenViewModel()
      ..bind(
        stocksMarketRepository: ref.read(stocksMarketRepositoryProvider),
        realtimeConf: ref.read(kisRealtimeConfProvider),
      );
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _connectionSubscription?.cancel();
      unawaited(clearRealtimeSubscription());
    });
    Future<void>.microtask(_attachRealtime);
    return FavoritesViewState(
      showKrwForOverseas: false,
      lastRefreshTime: DateTime.now(),
      errorMessage: null,
      connectionState: const KisRealtimeConnectionState(
        status: KisRealtimeConnectionStatus.disconnected,
      ),
      subscribedRealtimeKeys: const <String>{},
      requestedLiveQuoteKeys: const <String>{},
      visibleRealtimeSignature: '',
      liveDomesticPrices: const <String, RealtimeDomesticPrice>{},
      liveOverseasPrices: const <String, RealtimeOverseasPrice>{},
      liveQuoteStocks: const <String, RankingStock>{},
    );
  }

  void _attachRealtime() {
    if (_realtimeSubscription != null) {
      return;
    }

    final realtimeConf = ref.read(kisRealtimeConfProvider);
    applyRealtimeSnapshot(realtimeConf.snapshot);
    updateConnectionState(realtimeConf.connectionState);
    _realtimeSubscription = realtimeConf.stream.listen(applyRealtimeSnapshot);
    _connectionSubscription = realtimeConf.connectionStateStream.listen((
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

  Future<void> handleAppResumed(List<RankingStock> visibleStocks) async {
    if (visibleStocks.isEmpty) {
      return;
    }
    _visibleStocks = visibleStocks;
    await _handleVisibleStocksChanged(
      visibleStocks: visibleStocks,
      forceSubscriptionSync: true,
    );
  }

  void toggleShowKrwForOverseas(bool value) {
    if (state.showKrwForOverseas == value) {
      return;
    }
    state = state.copyWith(showKrwForOverseas: value);
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
  }

  void updateConnectionState(KisRealtimeConnectionState connectionState) {
    state = state.copyWith(connectionState: connectionState);
  }

  Future<void> refreshFavorites(List<RankingStock> stocks) async {
    state = state.copyWith(clearErrorMessage: true);
    try {
      await refreshFavoriteQuotes(stocks, forceRefresh: true);
      state = state.copyWith(lastRefreshTime: DateTime.now());
    } catch (_) {
      state = state.copyWith(errorMessage: '즐겨찾기 종목을 다시 불러오지 못했습니다.');
    }
  }

  Future<void> syncDisplayedStocks({
    required List<RankingStock> visibleStocks,
    bool forceQuoteRefresh = false,
    bool forceSubscriptionSync = false,
  }) async {
    final nextSignature = visibleStocks.map(stockKey).join('|');
    if (!forceSubscriptionSync &&
        state.visibleRealtimeSignature == nextSignature) {
      return;
    }

    _visibleStocks = visibleStocks;
    state = state.copyWith(visibleRealtimeSignature: nextSignature);
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

    await refreshFavoriteQuotes(visibleStocks, forceRefresh: forceQuoteRefresh);
  }

  List<RankingStock> applyRealtimeStocks(
    List<RankingStock> stocks, {
    required Map<String, RealtimeDomesticPrice> liveDomesticPrices,
    required Map<String, RealtimeOverseasPrice> liveOverseasPrices,
    required Map<String, RankingStock> liveQuoteStocks,
  }) {
    return _stocksViewModel.applyRealtimeStocks(
      stocks,
      liveDomesticPrices: liveDomesticPrices,
      liveOverseasPrices: liveOverseasPrices,
      liveQuoteStocks: liveQuoteStocks,
    );
  }

  List<RankingStock> applyDisplayCurrency(
    List<RankingStock> stocks, {
    required bool showKrwForOverseas,
    required double? exchangeRate,
  }) {
    return _stocksViewModel.applyDisplayCurrency(
      stocks,
      showKrwForOverseas: showKrwForOverseas,
      exchangeRate: exchangeRate,
    );
  }

  Future<void> refreshFavoriteQuotes(
    List<RankingStock> visibleStocks, {
    bool forceRefresh = false,
  }) async {
    final quoteKeys = visibleStocks.map(stockKey).toSet();
    if (!forceRefresh && sameCodes(state.requestedLiveQuoteKeys, quoteKeys)) {
      return;
    }

    state = state.copyWith(requestedLiveQuoteKeys: quoteKeys);
    if (visibleStocks.isEmpty) {
      state = state.copyWith(
        liveQuoteStocks: const <String, RankingStock>{},
        visibleRealtimeSignature: '',
        lastRefreshTime: DateTime.now(),
      );
      return;
    }

    final liveQuotes = await _stocksViewModel.refreshVisibleQuotes(visibleStocks);
    state = state.copyWith(
      liveQuoteStocks: Map<String, RankingStock>.from(liveQuotes),
      lastRefreshTime: DateTime.now(),
    );

    final notifier = ref.read(favoriteStocksProvider.notifier);
    for (final stock in liveQuotes.values) {
      await notifier.upsert(FavoriteStock.fromRankingStock(stock));
    }
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

    final realtimeConf = ref.read(kisRealtimeConfProvider);
    if (domesticCodes.isEmpty && overseasTargets.isEmpty) {
      await realtimeConf.clearSubscription(_subscriptionOwnerId);
      return;
    }

    await realtimeConf.setSubscription(
      ownerId: _subscriptionOwnerId,
      domesticCodes: domesticCodes,
      overseasTargets: overseasTargets,
      includeKospi: false,
    );
  }

  Future<void> clearRealtimeSubscription() {
    state = state.copyWith(
      subscribedRealtimeKeys: const <String>{},
      requestedLiveQuoteKeys: const <String>{},
      visibleRealtimeSignature: '',
    );
    return ref.read(kisRealtimeConfProvider).clearSubscription(
      _subscriptionOwnerId,
    );
  }

  bool sameCodes(Set<String> current, Set<String> next) {
    return _stocksViewModel.sameCodes(current, next);
  }

  String stockKey(RankingStock stock) {
    return _stocksViewModel.stockKey(stock);
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
}
