import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';

class FavoritesViewState {
  const FavoritesViewState({
    required this.showKrwForOverseas,
    required this.lastRefreshTime,
    required this.errorMessage,
    required this.connectionState,
    required this.subscribedRealtimeKeys,
    required this.requestedLiveQuoteKeys,
    required this.visibleRealtimeSignature,
    required this.liveDomesticPrices,
    required this.liveOverseasPrices,
    required this.liveQuoteStocks,
  });

  final bool showKrwForOverseas;
  final DateTime lastRefreshTime;
  final String? errorMessage;
  final KisRealtimeConnectionState connectionState;
  final Set<String> subscribedRealtimeKeys;
  final Set<String> requestedLiveQuoteKeys;
  final String visibleRealtimeSignature;
  final Map<String, RealtimeDomesticPrice> liveDomesticPrices;
  final Map<String, RealtimeOverseasPrice> liveOverseasPrices;
  final Map<String, RankingStock> liveQuoteStocks;

  FavoritesViewState copyWith({
    bool? showKrwForOverseas,
    DateTime? lastRefreshTime,
    String? errorMessage,
    bool clearErrorMessage = false,
    KisRealtimeConnectionState? connectionState,
    Set<String>? subscribedRealtimeKeys,
    Set<String>? requestedLiveQuoteKeys,
    String? visibleRealtimeSignature,
    Map<String, RealtimeDomesticPrice>? liveDomesticPrices,
    Map<String, RealtimeOverseasPrice>? liveOverseasPrices,
    Map<String, RankingStock>? liveQuoteStocks,
  }) {
    return FavoritesViewState(
      showKrwForOverseas: showKrwForOverseas ?? this.showKrwForOverseas,
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
      liveDomesticPrices: liveDomesticPrices ?? this.liveDomesticPrices,
      liveOverseasPrices: liveOverseasPrices ?? this.liveOverseasPrices,
      liveQuoteStocks: liveQuoteStocks ?? this.liveQuoteStocks,
    );
  }
}
