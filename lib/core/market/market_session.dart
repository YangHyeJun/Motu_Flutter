import '../../models/holding_stock.dart';
import '../../models/stock_market_type.dart';

enum HoldingMarketSessionStatus { open, closed }

HoldingMarketSessionStatus holdingMarketSessionStatus(
  HoldingStock holding, [
  DateTime? now,
]) {
  final current = now ?? DateTime.now();
  final isOpen = switch (holding.marketType) {
    StockMarketType.domestic => _isDomesticMarketOpen(current),
    StockMarketType.overseas => _isOverseasMarketOpen(current),
  };
  return isOpen
      ? HoldingMarketSessionStatus.open
      : HoldingMarketSessionStatus.closed;
}

bool _isDomesticMarketOpen(DateTime now) {
  if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
    return false;
  }

  final minuteOfDay = (now.hour * 60) + now.minute;
  const marketOpenMinute = 9 * 60;
  const marketCloseMinute = (15 * 60) + 30;
  return minuteOfDay >= marketOpenMinute && minuteOfDay < marketCloseMinute;
}

bool _isOverseasMarketOpen(DateTime now) {
  if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
    return false;
  }

  final koreaMinuteOfDay = (now.hour * 60) + now.minute;
  const daytimeStartMinute = 10 * 60;
  const daytimeEndMinute = 18 * 60;
  if (koreaMinuteOfDay >= daytimeStartMinute &&
      koreaMinuteOfDay < daytimeEndMinute) {
    return true;
  }

  final utcNow = now.toUtc();
  final easternOffsetHours = _isUsDaylightSavingTime(utcNow) ? -4 : -5;
  final easternNow = utcNow.add(Duration(hours: easternOffsetHours));
  if (easternNow.weekday == DateTime.saturday ||
      easternNow.weekday == DateTime.sunday) {
    return false;
  }

  final minuteOfDay = (easternNow.hour * 60) + easternNow.minute;
  const premarketOpenMinute = 4 * 60;
  const marketOpenMinute = (9 * 60) + 30;
  const marketCloseMinute = 16 * 60;
  const afterHoursCloseMinute = 20 * 60;
  return (minuteOfDay >= premarketOpenMinute &&
          minuteOfDay < marketOpenMinute) ||
      (minuteOfDay >= marketOpenMinute && minuteOfDay < marketCloseMinute) ||
      (minuteOfDay >= marketCloseMinute && minuteOfDay < afterHoursCloseMinute);
}

bool _isUsDaylightSavingTime(DateTime utcNow) {
  final year = utcNow.year;
  final dstStartDay = _nthWeekdayOfMonth(
    year: year,
    month: 3,
    weekday: DateTime.sunday,
    occurrence: 2,
  );
  final dstEndDay = _nthWeekdayOfMonth(
    year: year,
    month: 11,
    weekday: DateTime.sunday,
    occurrence: 1,
  );
  final dstStartUtc = DateTime.utc(year, 3, dstStartDay, 7);
  final dstEndUtc = DateTime.utc(year, 11, dstEndDay, 6);
  return !utcNow.isBefore(dstStartUtc) && utcNow.isBefore(dstEndUtc);
}

int _nthWeekdayOfMonth({
  required int year,
  required int month,
  required int weekday,
  required int occurrence,
}) {
  final firstDay = DateTime.utc(year, month, 1);
  final offset = (weekday - firstDay.weekday + 7) % 7;
  return 1 + offset + ((occurrence - 1) * 7);
}
