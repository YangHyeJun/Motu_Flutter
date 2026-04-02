import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';

class StocksScreenViewState {
  const StocksScreenViewState({
    required this.selectedMarket,
    required this.selectedCategory,
    required this.searchQuery,
    required this.showKrwForOverseas,
    required this.visibleCount,
    required this.isRefreshing,
    required this.lastRefreshTime,
    required this.errorMessage,
    required this.connectionState,
    required this.subscribedRealtimeKeys,
    required this.requestedLiveQuoteKeys,
    required this.visibleRealtimeSignature,
    required this.displayVisibleStocks,
    required this.liveDomesticPrices,
    required this.liveOverseasPrices,
    required this.liveQuoteStocks,
  });

  final String selectedMarket;
  final String selectedCategory;
  final String searchQuery;
  final bool showKrwForOverseas;
  final int visibleCount;
  final bool isRefreshing;
  final DateTime lastRefreshTime;
  final String? errorMessage;
  final KisRealtimeConnectionState connectionState;
  final Set<String> subscribedRealtimeKeys;
  final Set<String> requestedLiveQuoteKeys;
  final String visibleRealtimeSignature;
  final List<RankingStock> displayVisibleStocks;
  final Map<String, RealtimeDomesticPrice> liveDomesticPrices;
  final Map<String, RealtimeOverseasPrice> liveOverseasPrices;
  final Map<String, RankingStock> liveQuoteStocks;

  StocksScreenViewState copyWith({
    String? selectedMarket,
    String? selectedCategory,
    String? searchQuery,
    bool? showKrwForOverseas,
    int? visibleCount,
    bool? isRefreshing,
    DateTime? lastRefreshTime,
    String? errorMessage,
    bool clearErrorMessage = false,
    KisRealtimeConnectionState? connectionState,
    Set<String>? subscribedRealtimeKeys,
    Set<String>? requestedLiveQuoteKeys,
    String? visibleRealtimeSignature,
    List<RankingStock>? displayVisibleStocks,
    Map<String, RealtimeDomesticPrice>? liveDomesticPrices,
    Map<String, RealtimeOverseasPrice>? liveOverseasPrices,
    Map<String, RankingStock>? liveQuoteStocks,
  }) {
    return StocksScreenViewState(
      selectedMarket: selectedMarket ?? this.selectedMarket,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      showKrwForOverseas: showKrwForOverseas ?? this.showKrwForOverseas,
      visibleCount: visibleCount ?? this.visibleCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      connectionState: connectionState ?? this.connectionState,
      subscribedRealtimeKeys:
          subscribedRealtimeKeys ?? this.subscribedRealtimeKeys,
      requestedLiveQuoteKeys:
          requestedLiveQuoteKeys ?? this.requestedLiveQuoteKeys,
      visibleRealtimeSignature:
          visibleRealtimeSignature ?? this.visibleRealtimeSignature,
      displayVisibleStocks: displayVisibleStocks ?? this.displayVisibleStocks,
      liveDomesticPrices: liveDomesticPrices ?? this.liveDomesticPrices,
      liveOverseasPrices: liveOverseasPrices ?? this.liveOverseasPrices,
      liveQuoteStocks: liveQuoteStocks ?? this.liveQuoteStocks,
    );
  }
}
