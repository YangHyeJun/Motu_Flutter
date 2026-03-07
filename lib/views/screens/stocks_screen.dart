import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home_provider.dart';
import '../widgets/common_widgets.dart';
import 'detail_screens.dart';

class StocksScreen extends ConsumerWidget {
  const StocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final notifier = ref.read(homeViewModelProvider.notifier);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: notifier.refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '주식',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 16),
            const AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: '오늘의 급등 후보'),
                  SizedBox(height: 12),
                  Text('2차전지 관련 종목 거래량 급증. 단기 변동성 주의 구간입니다.'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...state.domesticHoldings.map(
              (stock) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(stock.name),
                    subtitle: Text(stock.code),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${stock.currentPrice}원',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        PercentageText(
                          value: '${stock.profitRate.abs()}%',
                          isPositive: stock.isPositive,
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => StockDetailScreen(stock: stock),
                      ),
                    ),
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
