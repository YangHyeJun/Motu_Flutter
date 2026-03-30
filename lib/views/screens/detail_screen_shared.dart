part of 'detail_screens.dart';

class _QuantityStepButton extends StatelessWidget {
  const _QuantityStepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 18,
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

class _RealtimeConnectionBanner extends StatelessWidget {
  const _RealtimeConnectionBanner({
    required this.connectionState,
    required this.onRetry,
  });

  final KisRealtimeConnectionState connectionState;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attemptedAt = connectionState.lastAttemptedAt;
    final isMarketClosed = (connectionState.errorMessage ?? '').contains(
      '시간이 아닙니다.',
    );
    final message = switch (connectionState.status) {
      KisRealtimeConnectionStatus.connecting => '실시간 연결을 시도하고 있습니다.',
      KisRealtimeConnectionStatus.failed =>
        connectionState.errorMessage ?? '실시간 연결이 끊어졌습니다.',
      KisRealtimeConnectionStatus.disconnected =>
        connectionState.errorMessage ?? '실시간 연결이 끊어졌습니다.',
      KisRealtimeConnectionStatus.connected => '실시간 연결 중',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkWarningSoft : const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF6B5330) : const Color(0xFFF3D3A1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.wifi_tethering_error_rounded,
            color: isDark ? const Color(0xFFF0B45B) : const Color(0xFFC27A11),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? const Color(0xFFFFE0A8)
                        : const Color(0xFF8F5B0D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (attemptedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '마지막 시도 ${_formatRetryTime(attemptedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? const Color(0xFFE8C98F)
                          : const Color(0xFF8F5B0D),
                    ),
                  ),
                ],
                if (!isMarketClosed) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed:
                        connectionState.status ==
                            KisRealtimeConnectionStatus.connecting
                        ? null
                        : onRetry,
                    icon:
                        connectionState.status ==
                            KisRealtimeConnectionStatus.connecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(
                      connectionState.status ==
                              KisRealtimeConnectionStatus.connecting
                          ? '연결 중'
                          : '다시 연결',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFFF0B45B)
                          : const Color(0xFFC27A11),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TradeStatChip extends StatelessWidget {
  const _TradeStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSoft : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TradeSummaryRow extends StatelessWidget {
  const _TradeSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _IndexMetricRow extends StatelessWidget {
  const _IndexMetricRow({
    required this.openValue,
    required this.highValue,
    required this.lowValue,
  });

  final String openValue;
  final String highValue;
  final String lowValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(label: '시가', value: openValue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: '고가', value: highValue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: '저가', value: lowValue),
        ),
      ],
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.isPositive,
  });

  final String title;
  final String value;
  final String subtitle;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isPositive ? AppColors.positive : AppColors.negative,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.chartEntries,
    required this.isLoading,
    required this.errorText,
    required this.valueSuffix,
    required this.valueFormatter,
    required this.referencePrice,
  });

  final List<StockChartEntry> chartEntries;
  final bool isLoading;
  final String? errorText;
  final String valueSuffix;
  final String Function(int value) valueFormatter;
  final int? referencePrice;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chartEntries.isEmpty) {
      return Center(
        child: Text(
          errorText ?? '차트 데이터가 없습니다.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return SizedBox.expand(
      child: StockLineChart(
        entries: chartEntries,
        valueSuffix: valueSuffix,
        valueFormatter: valueFormatter,
        referencePrice: referencePrice,
      ),
    );
  }
}

class _ChartRangeSummary extends StatelessWidget {
  const _ChartRangeSummary({
    required this.highLabel,
    required this.highValue,
    required this.lowLabel,
    required this.lowValue,
  });

  final String highLabel;
  final String highValue;
  final String lowLabel;
  final String lowValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(label: highLabel, value: highValue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: lowLabel, value: lowValue),
        ),
      ],
    );
  }
}

class _PriceSummaryRow extends StatelessWidget {
  const _PriceSummaryRow({
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.currencySymbol,
    required this.priceDecimals,
  });

  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final String currencySymbol;
  final int priceDecimals;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: '시가',
            value: _formatMoney(
              openPrice,
              currencySymbol: currencySymbol,
              decimals: priceDecimals,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: '고가',
            value: _formatMoney(
              highPrice,
              currencySymbol: currencySymbol,
              decimals: priceDecimals,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: '저가',
            value: _formatMoney(
              lowPrice,
              currencySymbol: currencySymbol,
              decimals: priceDecimals,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderBookCard extends StatelessWidget {
  const _OrderBookCard({
    required this.orderBook,
    required this.currencySymbol,
    required this.priceDecimals,
  });

  final List<StockOrderBookLevel> orderBook;
  final String currencySymbol;
  final int priceDecimals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '호가',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...orderBook.map((level) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatNumber(level.askVolume)}주',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatMoney(
                        level.askPrice,
                        currencySymbol: currencySymbol,
                        decimals: priceDecimals,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.negative,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatMoney(
                        level.bidPrice,
                        currencySymbol: currencySymbol,
                        decimals: priceDecimals,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.positive,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_formatNumber(level.bidVolume)}주',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoGridCard extends StatelessWidget {
  const _InfoGridCard({required this.items, this.title = '기본 정보'});

  final List<StockInfoItem> items;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _VolumeSection extends StatelessWidget {
  const _VolumeSection({
    required this.entries,
    required this.volume,
    required this.isLoading,
  });

  final List<StockChartEntry> entries;
  final int volume;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('거래량', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${_currency(volume)}주',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    '거래량 데이터가 없습니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : VolumeBarChart(entries: entries),
        ),
      ],
    );
  }
}

class _OverseasCurrencyToggle extends StatelessWidget {
  const _OverseasCurrencyToggle({
    required this.selected,
    required this.exchangeRate,
    required this.onSelected,
  });

  final _OverseasDisplayCurrency selected;
  final double? exchangeRate;
  final ValueChanged<_OverseasDisplayCurrency> onSelected;

  @override
  Widget build(BuildContext context) {
    final krwAvailable = exchangeRate != null && exchangeRate! > 0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CurrencyChip(
          label: '달러',
          selected: selected == _OverseasDisplayCurrency.usd,
          onTap: () => onSelected(_OverseasDisplayCurrency.usd),
        ),
        _CurrencyChip(
          label: '원화',
          selected: selected == _OverseasDisplayCurrency.krw,
          enabled: krwAvailable,
          onTap: krwAvailable
              ? () => onSelected(_OverseasDisplayCurrency.krw)
              : null,
        ),
      ],
    );
  }
}

class _OverseasHoldingsCurrencyToggle extends StatelessWidget {
  const _OverseasHoldingsCurrencyToggle({
    required this.showKrw,
    required this.exchangeRate,
    required this.onChanged,
  });

  final bool showKrw;
  final double? exchangeRate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final canShowUsd = exchangeRate != null && exchangeRate! > 0;

    return Row(
      children: [
        _CurrencyChip(
          label: '원화',
          selected: showKrw,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 8),
        _CurrencyChip(
          label: '달러',
          selected: !showKrw,
          enabled: canShowUsd,
          onTap: canShowUsd ? () => onChanged(false) : null,
        ),
      ],
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 56,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? (isDark ? AppColors.darkAccentSoft : Colors.black)
                : (isDark
                      ? AppColors.darkSurfaceSoft
                      : const Color(0xFFF0F1F4)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? (isDark ? AppColors.darkAccent : Colors.black)
                  : (isDark ? AppColors.darkBorder : Colors.transparent),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSoft : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.selectedPeriod, required this.onSelect});

  final StockChartPeriod selectedPeriod;
  final ValueChanged<StockChartPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StockChartPeriod.values.map((period) {
        final selected = period == selectedPeriod;
        return GestureDetector(
          onTap: () => onSelect(period),
          child: Container(
            width: 52,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? AppColors.darkAccentSoft : Colors.black)
                  : (isDark
                        ? AppColors.darkSurfaceSoft
                        : const Color(0xFFF0F1F4)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? (isDark ? AppColors.darkAccent : Colors.black)
                    : (isDark ? AppColors.darkBorder : Colors.transparent),
              ),
            ),
            child: Text(
              period.label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

int _convertForeignPriceToKrw(
  int value, {
  required int decimals,
  required double exchangeRate,
}) {
  final scale = _pow10(decimals);
  return ((value / scale) * exchangeRate).round();
}

List<StockChartEntry> _convertChartEntriesToKrw(
  List<StockChartEntry> entries, {
  required int decimals,
  required double exchangeRate,
}) {
  return entries
      .map(
        (entry) => StockChartEntry(
          date: entry.date,
          timeLabel: entry.timeLabel,
          openPrice: _convertForeignPriceToKrw(
            entry.openPrice,
            decimals: decimals,
            exchangeRate: exchangeRate,
          ),
          highPrice: _convertForeignPriceToKrw(
            entry.highPrice,
            decimals: decimals,
            exchangeRate: exchangeRate,
          ),
          lowPrice: _convertForeignPriceToKrw(
            entry.lowPrice,
            decimals: decimals,
            exchangeRate: exchangeRate,
          ),
          closePrice: _convertForeignPriceToKrw(
            entry.closePrice,
            decimals: decimals,
            exchangeRate: exchangeRate,
          ),
          volume: entry.volume,
        ),
      )
      .toList(growable: false);
}

List<StockOrderBookLevel> _convertOrderBookToKrw(
  List<StockOrderBookLevel> levels, {
  required int decimals,
  required double exchangeRate,
}) {
  return levels
      .map(
        (level) => StockOrderBookLevel(
          askPrice: _convertForeignPriceToKrw(
            level.askPrice,
            decimals: decimals,
            exchangeRate: exchangeRate,
          ),
          askVolume: level.askVolume,
          bidPrice: _convertForeignPriceToKrw(
            level.bidPrice,
            decimals: decimals,
            exchangeRate: exchangeRate,
          ),
          bidVolume: level.bidVolume,
        ),
      )
      .toList(growable: false);
}

List<StockChartEntry> _convertIndexChartEntriesToKrw(
  List<StockChartEntry> entries,
  double exchangeRate,
) {
  return entries
      .map(
        (entry) => StockChartEntry(
          date: entry.date,
          timeLabel: entry.timeLabel,
          openPrice: (entry.openPrice * exchangeRate).round(),
          highPrice: (entry.highPrice * exchangeRate).round(),
          lowPrice: (entry.lowPrice * exchangeRate).round(),
          closePrice: (entry.closePrice * exchangeRate).round(),
          volume: entry.volume,
        ),
      )
      .toList(growable: false);
}

String _formatConvertedIndexValue(String value, double exchangeRate) {
  final parsed = _parseNumericValue(value);
  return '${_currency((parsed * exchangeRate).round())}원';
}

String _formatConvertedSignedIndexValue(String value, double exchangeRate) {
  final parsed = _parseNumericValue(value);
  final converted = (parsed.abs() * exchangeRate).round();
  return '${parsed >= 0 ? '+' : '-'}${_currency(converted)}원';
}

double _parseNumericValue(String value) {
  return double.tryParse(
        value.replaceAll(',', '').replaceAll('원', '').trim(),
      ) ??
      0.0;
}

String _formatHoldingAmount(
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
    return '${_currency(amount)}원';
  }

  final usd = amount / rate;
  return '\$${usd.toStringAsFixed(2)}';
}

String _currency(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final fromEnd = digits.length - i - 1;
    if (fromEnd > 0 && fromEnd % 3 == 0) {
      buffer.write(',');
    }
  }
  return '${negative ? '-' : ''}${buffer.toString()}';
}

String _formatMoney(
  int value, {
  required String currencySymbol,
  required int decimals,
}) {
  final negative = value < 0;
  final scale = _pow10(decimals);
  final absolute = value.abs();
  final whole = decimals == 0 ? absolute : absolute ~/ scale;
  final rawFraction = decimals == 0
      ? ''
      : (absolute % scale).toString().padLeft(decimals, '0');
  final fraction = currencySymbol == r'$'
      ? _trimTrailingZeros(rawFraction)
      : rawFraction;
  final numberText = _formatNumber(whole);
  final amount = fraction.isEmpty ? numberText : '$numberText.$fraction';
  final prefix = currencySymbol == '원' ? '' : currencySymbol;
  final suffix = currencySymbol == '원' ? currencySymbol : '';
  return '${negative ? '-' : ''}$prefix$amount$suffix';
}

String _formatNumber(int value) {
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

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

String _trimTrailingZeros(String value) {
  var end = value.length;
  while (end > 0 && value[end - 1] == '0') {
    end--;
  }
  return value.substring(0, end);
}

List<StockChartEntry> _mergeRealtimeChartEntries({
  required List<StockChartEntry> entries,
  required int? realtimePrice,
  required int? realtimeVolume,
  required bool applyRealtime,
}) {
  if (!applyRealtime || realtimePrice == null) {
    return entries;
  }

  final nextEntries = List<StockChartEntry>.from(entries);
  final now = DateTime.now();
  final timeLabel =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final date =
      '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

  final nextEntry = StockChartEntry(
    date: date,
    timeLabel: timeLabel,
    openPrice: nextEntries.isEmpty ? realtimePrice : nextEntries.last.openPrice,
    highPrice: nextEntries.isEmpty
        ? realtimePrice
        : math.max(nextEntries.last.highPrice, realtimePrice),
    lowPrice: nextEntries.isEmpty
        ? realtimePrice
        : math.min(nextEntries.last.lowPrice, realtimePrice),
    closePrice: realtimePrice,
    volume:
        realtimeVolume ?? (nextEntries.isEmpty ? 0 : nextEntries.last.volume),
  );

  if (nextEntries.isEmpty) {
    return [nextEntry];
  }

  if (nextEntries.last.timeLabel == timeLabel) {
    final previousEntry = nextEntries.last;
    nextEntries[nextEntries.length - 1] = StockChartEntry(
      date: date,
      timeLabel: timeLabel,
      openPrice: previousEntry.openPrice,
      highPrice: math.max(previousEntry.highPrice, realtimePrice),
      lowPrice: math.min(previousEntry.lowPrice, realtimePrice),
      closePrice: realtimePrice,
      volume: realtimeVolume ?? previousEntry.volume,
    );
  } else {
    nextEntries.add(nextEntry);
  }

  return nextEntries;
}

(int, int)? _chartRange(List<StockChartEntry> entries) {
  if (entries.isEmpty) {
    return null;
  }

  var high = entries.first.highPrice;
  var low = entries.first.lowPrice;

  for (final entry in entries) {
    if (entry.highPrice > high) {
      high = entry.highPrice;
    }
    if (entry.lowPrice < low) {
      low = entry.lowPrice;
    }
  }

  return (high, low);
}

String _formatCompactNumber(int value) {
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

double _parseSignedPercent(String value) {
  return double.tryParse(
        value.replaceAll('%', '').replaceAll('+', '').replaceAll(',', ''),
      ) ??
      0.0;
}

String _formatSignedPercent(double value) {
  return '${value >= 0 ? '+' : '-'}${value.abs().toStringAsFixed(2)}';
}

String _formatRetryTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatHistoryDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year.$month.$day';
}

int? _referencePriceFromChangeRate({
  required int currentPrice,
  required double changeRate,
}) {
  if (currentPrice <= 0) {
    return null;
  }

  final denominator = 1 + (changeRate / 100);
  if (!denominator.isFinite || denominator <= 0) {
    return null;
  }

  return (currentPrice / denominator).round();
}
