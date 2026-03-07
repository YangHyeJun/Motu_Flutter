import '../models/models.dart';

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
  });

  final PortfolioSummary summary;
  final List<MarketIndex> marketIndexes;
  final List<HoldingStock> domesticHoldings;
  final List<HoldingStock> usHoldings;
  final List<RankingStock> shortSellRankings;
  final List<TipCard> tips;
  final List<double> chartPoints;
  final DateTime lastUpdated;

  HomeViewState copyWith({
    PortfolioSummary? summary,
    List<MarketIndex>? marketIndexes,
    List<HoldingStock>? domesticHoldings,
    List<HoldingStock>? usHoldings,
    List<RankingStock>? shortSellRankings,
    List<TipCard>? tips,
    List<double>? chartPoints,
    DateTime? lastUpdated,
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
    );
  }
}
