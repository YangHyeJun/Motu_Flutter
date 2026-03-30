import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../providers/api_provider.dart';
import 'favorites_view_state.dart';
import 'stocks_screen_view_model.dart';

class FavoritesViewModel extends Notifier<FavoritesViewState> {
  late final StocksScreenViewModel _stocksScreenViewModel;

  @override
  FavoritesViewState build() {
    _stocksScreenViewModel = StocksScreenViewModel()
      ..bind(
        stocksMarketRepository: ref.read(stocksMarketRepositoryProvider),
        realtimeService: ref.read(kisRealtimeServiceProvider),
      );
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
  }) async {
    final realtimeKeys = visibleStocks.map(stockKey).toSet();
    if (!sameCodes(state.subscribedRealtimeKeys, realtimeKeys)) {
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
