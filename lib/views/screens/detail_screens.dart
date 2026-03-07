import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/common_widgets.dart';

class HoldingsDetailScreen extends ConsumerWidget {
  const HoldingsDetailScreen({super.key, required this.holdings});

  final List<HoldingStock> holdings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('국내 보유주식'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomBar(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: ref.read(homeViewModelProvider.notifier).refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const InfoBanner(
              message: '데이터는 한국투자증권 API 기준입니다.',
              trailing: Icon(Icons.close, color: AppColors.accent),
            ),
            const SizedBox(height: 12),
            ...holdings.map(
              (stock) => InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen(stock: stock),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '내 평균 ${_currency(stock.buyPrice)}원',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${stock.quantity}주',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _PriceColumn(
                          title: '현재가',
                          value: '${_currency(stock.currentPrice)}원',
                          isPositive: stock.isPositive,
                          subtitle:
                              '${stock.profitRate > 0 ? '+' : ''}${stock.profitRate.toStringAsFixed(1)}%',
                        ),
                      ),
                      Expanded(
                        child: _PriceColumn(
                          title: '평가금',
                          value: '${_currency(stock.evaluationAmount)}원',
                          isPositive: stock.isPositive,
                          subtitle:
                              '${stock.profitAmount > 0 ? '+' : ''}${_currency(stock.profitAmount)}원 (${stock.profitRate.toStringAsFixed(1)}%)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShortSellDetailScreen extends ConsumerWidget {
  const ShortSellDetailScreen({super.key, required this.rankings});

  final List<RankingStock> rankings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('국내 공매도 순위'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search),
          ),
        ],
      ),
      bottomNavigationBar: const _BottomBar(currentIndex: 2),
      body: RefreshIndicator(
        onRefresh: ref.read(homeViewModelProvider.notifier).refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const InfoBanner(
              message: '데이터는 한국투자증권 API 기준입니다.',
              trailing: Icon(Icons.close, color: AppColors.accent),
            ),
            const SizedBox(height: 10),
            const InfoBanner(
              message: '공매도 정보는 20분 지연 제공 됩니다.',
              trailing: Icon(Icons.close, color: AppColors.accent),
            ),
            const SizedBox(height: 12),
            ...rankings.map(
              (stock) => Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${stock.rank}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '(${stock.code})    ${stock.extraLabel}: ${stock.extraValue}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_currency(stock.price)}원',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontSize: 18),
                        ),
                        PercentageText(
                          value: '${stock.changeRate.abs()}%',
                          isPositive: stock.isPositive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StockDetailScreen extends ConsumerWidget {
  const StockDetailScreen({super.key, required this.stock});

  final HoldingStock stock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartPoints = ref.watch(homeViewModelProvider).chartPoints;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(homeViewModelProvider.notifier).refreshAll(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ref.read(homeViewModelProvider.notifier).refreshAll,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 120,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${stock.name} (${stock.code})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${_currency(stock.currentPrice)}원',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '지난주보다 ',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        PercentageText(
                          value:
                              '${_currency((stock.currentPrice - stock.buyPrice).abs())}원 (${stock.profitRate.abs()}%)',
                          isPositive: stock.isPositive,
                        ),
                        const Spacer(),
                        Text(
                          '거래량: 12,345,678주\n거래대금: 965억',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _TabLabel('차트', true),
                        _TabLabel('매수', false),
                        _TabLabel('매도', false),
                        _TabLabel('정보', false),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 220,
                      child: AppCard(
                        child: SizedBox.expand(
                          child: StockLineChart(points: chartPoints),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _PeriodRow(),
                    const SizedBox(height: 18),
                    const SizedBox(
                      height: 180,
                      child: AppCard(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            '거래량',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {},
                        child: const Text(
                          '구매하기',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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

class _PeriodRow extends StatelessWidget {
  const _PeriodRow();

  @override
  Widget build(BuildContext context) {
    const periods = ['1일', '1주', '1달', '3달', '1년', '전체'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: periods.map((period) {
        final selected = period == '1일';
        return Container(
          width: 48,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.black : const Color(0xFFF0F1F4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            period,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.label, this.selected);

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, '홈'),
      (Icons.show_chart, '주식'),
      (Icons.menu, '더보기'),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final selected = index == currentIndex;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    items[index].$1,
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[index].$2,
                    style: TextStyle(
                      color: selected
                          ? AppColors.accent
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
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
