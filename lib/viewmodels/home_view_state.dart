import '../models/models.dart';

enum HomeSyncStatus {
  idle,
  authenticating,
  loadingAccount,
}

enum HomeSection {
  summary,
  market,
  domesticHoldings,
  usHoldings,
  shortSell,
}

class HomeSectionSyncState {
  const HomeSectionSyncState({
    required this.lastUpdated,
    required this.isSyncing,
    this.errorMessage,
  });

  final DateTime lastUpdated;
  final bool isSyncing;
  final String? errorMessage;

  HomeSectionSyncState copyWith({
    DateTime? lastUpdated,
    bool? isSyncing,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return HomeSectionSyncState(
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class HomeViewState {
  const HomeViewState({
    required this.summary,
    required this.marketIndexes,
    required this.domesticHoldings,
    required this.usHoldings,
    required this.shortSellRankings,
    required this.lastUpdated,
    required this.isSyncing,
    required this.syncStatus,
    required this.accountSyncErrorTitle,
    required this.accountSyncErrorMessage,
    required this.sectionSyncStates,
  });

  final PortfolioSummary summary;
  final List<MarketIndex> marketIndexes;
  final List<HoldingStock> domesticHoldings;
  final List<HoldingStock> usHoldings;
  final List<RankingStock> shortSellRankings;
  final DateTime lastUpdated;
  final bool isSyncing;
  final HomeSyncStatus syncStatus;
  final String? accountSyncErrorTitle;
  final String? accountSyncErrorMessage;
  final Map<HomeSection, HomeSectionSyncState> sectionSyncStates;

  HomeSectionSyncState sectionState(HomeSection section) {
    return sectionSyncStates[section] ??
        HomeSectionSyncState(
          lastUpdated: lastUpdated,
          isSyncing: false,
        );
  }

  HomeViewState copyWith({
    PortfolioSummary? summary,
    List<MarketIndex>? marketIndexes,
    List<HoldingStock>? domesticHoldings,
    List<HoldingStock>? usHoldings,
    List<RankingStock>? shortSellRankings,
    DateTime? lastUpdated,
    bool? isSyncing,
    HomeSyncStatus? syncStatus,
    String? accountSyncErrorTitle,
    String? accountSyncErrorMessage,
    Map<HomeSection, HomeSectionSyncState>? sectionSyncStates,
    bool clearAccountSyncErrorMessage = false,
  }) {
    return HomeViewState(
      summary: summary ?? this.summary,
      marketIndexes: marketIndexes ?? this.marketIndexes,
      domesticHoldings: domesticHoldings ?? this.domesticHoldings,
      usHoldings: usHoldings ?? this.usHoldings,
      shortSellRankings: shortSellRankings ?? this.shortSellRankings,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isSyncing: isSyncing ?? this.isSyncing,
      syncStatus: syncStatus ?? this.syncStatus,
      accountSyncErrorTitle: clearAccountSyncErrorMessage
          ? null
          : accountSyncErrorTitle ?? this.accountSyncErrorTitle,
      accountSyncErrorMessage: clearAccountSyncErrorMessage
          ? null
          : accountSyncErrorMessage ?? this.accountSyncErrorMessage,
      sectionSyncStates: sectionSyncStates ?? this.sectionSyncStates,
    );
  }
}
