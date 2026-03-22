import '../models/models.dart';

enum HomeSyncStatus {
  idle,
  authenticating,
  loadingAccount,
}

class HomeViewState {
  const HomeViewState({
    required this.summary,
    required this.marketIndexes,
    required this.domesticHoldings,
    required this.usHoldings,
    required this.shortSellRankings,
    required this.tips,
    required this.chartPoints,
    required this.lastUpdated,
    required this.isSyncing,
    required this.syncStatus,
    required this.accountSyncErrorTitle,
    required this.accountSyncErrorMessage,
  });

  final PortfolioSummary summary;
  final List<MarketIndex> marketIndexes;
  final List<HoldingStock> domesticHoldings;
  final List<HoldingStock> usHoldings;
  final List<RankingStock> shortSellRankings;
  final List<TipCard> tips;
  final List<double> chartPoints;
  final DateTime lastUpdated;
  final bool isSyncing;
  final HomeSyncStatus syncStatus;
  final String? accountSyncErrorTitle;
  final String? accountSyncErrorMessage;

  HomeViewState copyWith({
    PortfolioSummary? summary,
    List<MarketIndex>? marketIndexes,
    List<HoldingStock>? domesticHoldings,
    List<HoldingStock>? usHoldings,
    List<RankingStock>? shortSellRankings,
    List<TipCard>? tips,
    List<double>? chartPoints,
    DateTime? lastUpdated,
    bool? isSyncing,
    HomeSyncStatus? syncStatus,
    String? accountSyncErrorTitle,
    String? accountSyncErrorMessage,
    bool clearAccountSyncErrorMessage = false,
  }) {
    return HomeViewState(
      summary: summary ?? this.summary,
      marketIndexes: marketIndexes ?? this.marketIndexes,
      domesticHoldings: domesticHoldings ?? this.domesticHoldings,
      usHoldings: usHoldings ?? this.usHoldings,
      shortSellRankings: shortSellRankings ?? this.shortSellRankings,
      tips: tips ?? this.tips,
      chartPoints: chartPoints ?? this.chartPoints,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSyncing: isSyncing ?? this.isSyncing,
      syncStatus: syncStatus ?? this.syncStatus,
      accountSyncErrorTitle: clearAccountSyncErrorMessage
          ? null
          : accountSyncErrorTitle ?? this.accountSyncErrorTitle,
      accountSyncErrorMessage: clearAccountSyncErrorMessage
          ? null
          : accountSyncErrorMessage ?? this.accountSyncErrorMessage,
    );
  }
}
