part of 'home_screen.dart';

String _format(int value) {
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

String _formatHoldingAmountHome(
  int amount, {
  required HoldingStock stock,
  required bool showKrw,
  required double? exchangeRate,
}) {
  final rate = exchangeRate ?? stock.exchangeRate;
  if (showKrw ||
      stock.marketType != StockMarketType.overseas ||
      rate == null ||
      rate <= 0) {
    return '₩${_format(amount)}';
  }

  final usd = amount / rate;
  return '\$${usd.toStringAsFixed(2)}';
}

String _formatHoldingsTotalHome(
  List<HoldingStock> stocks, {
  required bool showKrw,
  required double? exchangeRate,
}) {
  final total = stocks.fold<int>(
    0,
    (sum, stock) => sum + stock.evaluationAmount,
  );
  final hasOnlyOverseas =
      stocks.isNotEmpty &&
      stocks.every((stock) => stock.marketType == StockMarketType.overseas);

  if (showKrw ||
      !hasOnlyOverseas ||
      exchangeRate == null ||
      exchangeRate <= 0) {
    return '₩${_format(total)}';
  }

  final usd = total / exchangeRate;
  return '\$${usd.toStringAsFixed(2)}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute 갱신';
}

String _formatDateTime(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month/$day $hour:$minute';
}

String _formatSignedAmount(int value) {
  final sign = value > 0
      ? '+'
      : value < 0
      ? '-'
      : '';
  final absValue = value.abs();
  if (absValue >= 100) {
    final eok = absValue / 100.0;
    return '$sign${eok.toStringAsFixed(eok >= 1000 ? 0 : 1)}억';
  }
  return '$sign${_format(absValue)}백만';
}

String _syncStatusLabel(HomeSyncStatus status) {
  switch (status) {
    case HomeSyncStatus.authenticating:
      return '인증 중';
    case HomeSyncStatus.loadingAccount:
      return '계좌 조회 중';
    case HomeSyncStatus.idle:
      return '갱신 중';
  }
}
