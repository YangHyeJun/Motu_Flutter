class PortfolioProfitHistoryEntry {
  const PortfolioProfitHistoryEntry({
    required this.date,
    required this.realizedProfitAmount,
    required this.profitRate,
    required this.buyAmount,
    required this.sellAmount,
    required this.fee,
    required this.tax,
  });

  final DateTime date;
  final int realizedProfitAmount;
  final double profitRate;
  final int buyAmount;
  final int sellAmount;
  final int fee;
  final int tax;
}

class PortfolioProfitHistory {
  const PortfolioProfitHistory({
    required this.totalProfitRate,
    required this.totalRealizedProfitAmount,
    required this.currentAssetAmount,
    required this.currentInvestedAmount,
    required this.currentProfitRate,
    required this.currentProfitAmount,
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
    required this.assetCategories,
    this.messages = const [],
    required this.entries,
  });

  final double totalProfitRate;
  final int totalRealizedProfitAmount;
  final int currentAssetAmount;
  final int currentInvestedAmount;
  final double currentProfitRate;
  final int currentProfitAmount;
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
  final List<PortfolioAssetCategory> assetCategories;
  final List<String> messages;
  final List<PortfolioProfitHistoryEntry> entries;
}

class PortfolioAssetCategory {
  const PortfolioAssetCategory({
    required this.name,
    required this.purchaseAmount,
    required this.evaluationAmount,
    required this.profitAmount,
    required this.netAssetAmount,
    required this.weightRate,
  });

  final String name;
  final int purchaseAmount;
  final int evaluationAmount;
  final int profitAmount;
  final int netAssetAmount;
  final double weightRate;
}
