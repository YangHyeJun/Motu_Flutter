import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../providers/api_provider.dart';
import 'favorites_view_state.dart';
import 'stocks_screen_view_model.dart';

class FavoritesViewModel extends Notifier<FavoritesViewState> {
  late final StocksScreenViewModel _stocksScreenViewModel;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  Timer? _visibleQuoteRefreshTimer;
  String? _subscriptionOwnerId;
  List<RankingStock> _visibleStocks = const <RankingStock>[];

  @override
  FavoritesViewState build() {
    _stocksScreenViewModel = StocksScreenViewModel()
      ..bind(
        stocksMarketRepository: ref.read(stocksMarketRepositoryProvider),
        realtimeService: ref.read(kisRealtimeServiceProvider),
      );
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _connectionSubscription?.cancel();
      _visibleQuoteRefreshTimer?.cancel();
    });
    return FavoritesViewState(
      showKrwForOverseas: false,
      lastRefreshTime: DateTime.now(),
      errorMessage: null,
      connectionState: const KisRealtimeConnectionState(
        status: KisRealtimeConnectionStatus.disconnected,
      ),
      subscribedRealtimeKeys: const <String>{},
      requestedLiveQuoteKeys: const <String>{},
      liveDomesticPrices: const <String, RealtimeDomesticPrice>{},
      liveOverseasPrices: const <String, RealtimeOverseasPrice>{},
      liveQuoteStocks: const <String, RankingStock>{},
    );
  }

  void attachRealtime(String ownerId) {
    if (_subscriptionOwnerId == ownerId) {
      return;
    }

    _subscriptionOwnerId = ownerId;
    final realtimeService = ref.read(kisRealtimeServiceProvider);
    applyRealtimeSnapshot(realtimeService.snapshot);
    updateConnectionState(realtimeService.connectionState);
    _realtimeSubscription?.cancel();
    _connectionSubscription?.cancel();
    _visibleQuoteRefreshTimer?.cancel();

    _realtimeSubscription = realtimeService.stream.listen(applyRealtimeSnapshot);
    _connectionSubscription = realtimeService.connectionStateStream.listen((
      nextState,
    ) {
      final previousStatus = state.connectionState.status;
      updateConnectionState(nextState);
      if (nextState.status == KisRealtimeConnectionStatus.connected &&
          previousStatus != KisRealtimeConnectionStatus.connected &&
          _visibleStocks.isNotEmpty) {
        unawaited(
          handleVisibleStocksChanged(
            ownerId: ownerId,
            visibleStocks: _visibleStocks,
            forceQuoteRefresh: true,
            forceSubscriptionSync: true,
          ),
        );
      }
    });
    _visibleQuoteRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_visibleStocks.isEmpty || _subscriptionOwnerId != ownerId) {
        return;
      }
      final connectionStatus = state.connectionState.status;
      unawaited(
        handleVisibleStocksChanged(
          ownerId: ownerId,
          visibleStocks: _visibleStocks,
          forceQuoteRefresh: true,
          forceSubscriptionSync:
              connectionStatus != KisRealtimeConnectionStatus.connected,
        ),
      );
    });
  }

  Future<void> detachRealtime() async {
    final ownerId = _subscriptionOwnerId;
    _subscriptionOwnerId = null;
    _visibleStocks = const <RankingStock>[];
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _visibleQuoteRefreshTimer?.cancel();
    _visibleQuoteRefreshTimer = null;
    if (ownerId != null) {
      await syncRealtimeSubscription(ownerId: ownerId, visibleStocks: const []);
    }
  }

  Future<void> syncDisplayedStocks({
    required String ownerId,
    required List<RankingStock> visibleStocks,
    bool forceQuoteRefresh = false,
    bool forceSubscriptionSync = false,
  }) {
    _visibleStocks = visibleStocks;
    return handleVisibleStocksChanged(
      ownerId: ownerId,
      visibleStocks: visibleStocks,
      forceQuoteRefresh: forceQuoteRefresh,
      forceSubscriptionSync: forceSubscriptionSync,
    );
  }

  Future<void> handleAppResumed(List<RankingStock> visibleStocks) async {
    final ownerId = _subscriptionOwnerId;
    if (ownerId == null || visibleStocks.isEmpty) {
      return;
    }
    _visibleStocks = visibleStocks;
    await handleVisibleStocksChanged(
      ownerId: ownerId,
      visibleStocks: visibleStocks,
      forceQuoteRefresh: true,
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

  Future<void> handleVisibleStocksChanged({
    required String ownerId,
    required List<RankingStock> visibleStocks,
    bool forceQuoteRefresh = false,
    bool forceSubscriptionSync = false,
  }) async {
    final realtimeKeys = visibleStocks.map(stockKey).toSet();
    if (forceSubscriptionSync ||
        !sameCodes(state.subscribedRealtimeKeys, realtimeKeys)) {
      state = state.copyWith(subscribedRealtimeKeys: realtimeKeys);
      await syncRealtimeSubscription(
        ownerId: ownerId,
        visibleStocks: visibleStocks,
      );
    }

    await refreshFavoriteQuotes(visibleStocks, forceRefresh: forceQuoteRefresh);
  }

  List<RankingStock> applyRealtimeStocks(
    List<RankingStock> stocks, {
    required Map<String, RealtimeDomesticPrice> liveDomesticPrices,
    required Map<String, RealtimeOverseasPrice> liveOverseasPrices,
    required Map<String, RankingStock> liveQuoteStocks,
  }) {
    return _stocksScreenViewModel.applyRealtimeStocks(
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
    return _stocksScreenViewModel.applyDisplayCurrency(
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
        lastRefreshTime: DateTime.now(),
      );
      return;
    }

    final liveQuotes = await _stocksScreenViewModel.refreshVisibleQuotes(
      visibleStocks,
    );
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
    required String ownerId,
    required List<RankingStock> visibleStocks,
  }) {
    return _stocksScreenViewModel.syncRealtimeSubscription(
      ownerId: ownerId,
      visibleStocks: visibleStocks,
    );
  }

  bool sameCodes(Set<String> current, Set<String> next) {
    return _stocksScreenViewModel.sameCodes(current, next);
  }

  String stockKey(RankingStock stock) {
    return _stocksScreenViewModel.stockKey(stock);
  }
}
