import '../models/models.dart';

class MoreMenuItemViewData {
  const MoreMenuItemViewData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final int icon;
}

class AveragingDownTargetPlan {
  const AveragingDownTargetPlan({
    required this.requiredQuantity,
    required this.requiredAmount,
    required this.estimatedAveragePrice,
    this.message,
  });

  final int requiredQuantity;
  final int requiredAmount;
  final int estimatedAveragePrice;
  final String? message;
}

class AveragingDownCalculation {
  const AveragingDownCalculation({
    required this.additionalQuantity,
    required this.additionalPrice,
    required this.targetAveragePrice,
    required this.additionalInvested,
    required this.totalQuantity,
    required this.nextAveragePrice,
    required this.nextProfitAmount,
    required this.nextProfitRate,
    required this.breakEvenRate,
    required this.targetPlan,
  });

  final int additionalQuantity;
  final int additionalPrice;
  final int targetAveragePrice;
  final int additionalInvested;
  final int totalQuantity;
  final int nextAveragePrice;
  final int nextProfitAmount;
  final double nextProfitRate;
  final double breakEvenRate;
  final AveragingDownTargetPlan targetPlan;
}

class MoreViewModel {
  const MoreViewModel();

  List<HoldingStock> sortedHoldings(List<HoldingStock> holdings) {
    final nextHoldings = [...holdings];
    nextHoldings.sort((left, right) => left.name.compareTo(right.name));
    return nextHoldings;
  }

  AveragingDownCalculation buildAveragingDownCalculation({
    required HoldingStock stock,
    required String quantityText,
    required String priceText,
    required String targetAveragePriceText,
  }) {
    final additionalQuantity = parsePositiveInt(quantityText);
    final additionalPrice = parsePositiveInt(priceText);
    final targetAveragePrice = parsePositiveInt(targetAveragePriceText);
    final currentInvested = stock.buyPrice * stock.quantity;
    final additionalInvested = additionalQuantity * additionalPrice;
    final totalQuantity = stock.quantity + additionalQuantity;
    final nextAveragePrice = totalQuantity == 0
        ? 0
        : ((currentInvested + additionalInvested) / totalQuantity).round();
    final currentValuation = stock.currentPrice * totalQuantity;
    final nextProfitAmount =
        currentValuation - (currentInvested + additionalInvested);
    final nextProfitRate = (currentInvested + additionalInvested) == 0
        ? 0.0
        : (nextProfitAmount / (currentInvested + additionalInvested)) * 100;
    final breakEvenRate = stock.currentPrice <= 0
        ? 0.0
        : ((nextAveragePrice - stock.currentPrice) / stock.currentPrice) * 100;

    return AveragingDownCalculation(
      additionalQuantity: additionalQuantity,
      additionalPrice: additionalPrice,
      targetAveragePrice: targetAveragePrice,
      additionalInvested: additionalInvested,
      totalQuantity: totalQuantity,
      nextAveragePrice: nextAveragePrice,
      nextProfitAmount: nextProfitAmount,
      nextProfitRate: nextProfitRate,
      breakEvenRate: breakEvenRate,
      targetPlan: buildTargetAveragePlan(
        stock: stock,
        targetAveragePrice: targetAveragePrice,
        buyPrice: additionalPrice,
      ),
    );
  }

  String formatHoldingPrice(int amount, HoldingStock stock) {
    return '₩${formatWithComma(amount)}';
  }

  AveragingDownTargetPlan buildTargetAveragePlan({
    required HoldingStock stock,
    required int targetAveragePrice,
    required int buyPrice,
  }) {
    if (targetAveragePrice <= 0) {
      return const AveragingDownTargetPlan(
        requiredQuantity: 0,
        requiredAmount: 0,
        estimatedAveragePrice: 0,
        message: '목표 평균단가를 입력하면 필요한 매수 수량과 금액을 계산합니다.',
      );
    }

    if (buyPrice <= 0) {
      return const AveragingDownTargetPlan(
        requiredQuantity: 0,
        requiredAmount: 0,
        estimatedAveragePrice: 0,
        message: '추가 매수 단가를 먼저 입력해 주세요.',
      );
    }

    if (targetAveragePrice >= stock.buyPrice) {
      return const AveragingDownTargetPlan(
        requiredQuantity: 0,
        requiredAmount: 0,
        estimatedAveragePrice: 0,
        message: '목표 평균단가는 현재 평균단가보다 낮게 입력해야 합니다.',
      );
    }

    if (buyPrice >= targetAveragePrice) {
      return const AveragingDownTargetPlan(
        requiredQuantity: 0,
        requiredAmount: 0,
        estimatedAveragePrice: 0,
        message: '지정한 매수 단가가 목표 평균단가 이상이면 물타기로 도달할 수 없습니다.',
      );
    }

    final numerator = stock.quantity * (stock.buyPrice - targetAveragePrice);
    final denominator = targetAveragePrice - buyPrice;
    if (denominator <= 0) {
      return const AveragingDownTargetPlan(
        requiredQuantity: 0,
        requiredAmount: 0,
        estimatedAveragePrice: 0,
        message: '입력한 조건으로는 계산할 수 없습니다.',
      );
    }

    final requiredQuantity = (numerator / denominator).ceil();
    final requiredAmount = requiredQuantity * buyPrice;
    final totalQuantity = stock.quantity + requiredQuantity;
    final estimatedAveragePrice = totalQuantity == 0
        ? 0
        : ((stock.buyPrice * stock.quantity) + requiredAmount) ~/ totalQuantity;

    return AveragingDownTargetPlan(
      requiredQuantity: requiredQuantity,
      requiredAmount: requiredAmount,
      estimatedAveragePrice: estimatedAveragePrice,
    );
  }

  int parsePositiveInt(String value) {
    return int.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }

  String formatWithComma(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final fromEnd = digits.length - i - 1;
      if (fromEnd > 0 && fromEnd % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }
}
