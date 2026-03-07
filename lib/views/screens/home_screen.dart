import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/home_provider.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/common_widgets.dart';
import 'alarm_screen.dart';
import 'detail_screens.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final notifier = ref.read(homeViewModelProvider.notifier);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: notifier.refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      Text(
                        '모두투자',
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(fontSize: 26),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AlarmScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.notifications_none,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const InfoBanner(message: '수익률부터 중요한 건 꾸준함과 투자 습관입니다.'),
                  const SizedBox(height: 12),
                  _ChipRow(),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    summary: state.summary,
                    lastUpdated: state.lastUpdated,
                    onRefresh: notifier.refreshRealtimeSections,
                  ),
                  const SizedBox(height: 16),
                  _AiAdviceCard(),
                  const SizedBox(height: 16),
                  _MarketSummaryCard(
                    indexes: state.marketIndexes,
                    lastUpdated: state.lastUpdated,
                    onRefresh: notifier.refreshRealtimeSections,
                  ),
                  const SizedBox(height: 16),
                  _HoldingsPreviewCard(
                    title: '국내 보유주식',
                    stocks: state.domesticHoldings,
                    onMore: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HoldingsDetailScreen(
                          holdings: state.domesticHoldings,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HoldingsPreviewCard(
                    title: '해외 보유주식',
                    stocks: state.usHoldings,
                    onMore: () {},
                  ),
                  const SizedBox(height: 16),
                  _ShortSellPreviewCard(
                    rankings: state.shortSellRankings.take(3).toList(),
                    onMore: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ShortSellDetailScreen(
                          rankings: state.shortSellRankings,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _TipsCard(tips: state.tips),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const chips = [
      (Icons.trending_up, '급등 종목'),
      (Icons.attach_money, '거래대금 상위'),
      (Icons.psychology_outlined, 'AI 추천'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (chip) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(chip.$1, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        chip.$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.lastUpdated,
    required this.onRefresh,
  });

  final PortfolioSummary summary;
  final DateTime lastUpdated;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '보유 자산',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(lastUpdated),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '₩${_format(summary.asset)}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 18),
          Text(
            '총 투자 금액',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '₩${_format(summary.invested)}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '총 수익률',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '▲ +${summary.profitRate.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 22,
                            color: const Color(0xFF18AD5A),
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '📈 최근 1주 수익률 변화',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const MiniBarChart(),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiAdviceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0D168)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFE8A3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: Color(0xFFDA9B20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI의 오늘의 투자 조언',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFA45C27),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '2차전지 관련 종목 거래량 급증. 단기적 주가 변동성 주의하며, 분산투자를 통한 리스크 관리를 권장합니다.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFB0602C),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketSummaryCard extends StatelessWidget {
  const _MarketSummaryCard({
    required this.indexes,
    required this.lastUpdated,
    required this.onRefresh,
  });

  final List<MarketIndex> indexes;
  final DateTime lastUpdated;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: '마켓 요약',
                  leading: Icon(
                    Icons.bar_chart_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                _formatTime(lastUpdated),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: indexes
                .map(
                  (index) => Expanded(
                    child: Column(
                      children: [
                        Text(
                          index.name,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          index.value,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        PercentageText(
                          value: index.changeRate
                              .replaceAll('+', '')
                              .replaceAll('-', ''),
                          isPositive: index.isPositive,
                          fontSize: 16,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: _OrderFlowColumn(
                    title: '외국인',
                    action: '순매수',
                    amount: '₩28.5억',
                    isPositive: true,
                  ),
                ),
                Expanded(
                  child: _OrderFlowColumn(
                    title: '기관',
                    action: '순매도',
                    amount: '₩12.0억',
                    isPositive: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderFlowColumn extends StatelessWidget {
  const _OrderFlowColumn({
    required this.title,
    required this.action,
    required this.amount,
    required this.isPositive,
  });

  final String title;
  final String action;
  final String amount;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge,
            children: [
              TextSpan(
                text: action,
                style: TextStyle(
                  color: isPositive ? AppColors.positive : AppColors.negative,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: ' $amount',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HoldingsPreviewCard extends StatelessWidget {
  const _HoldingsPreviewCard({
    required this.title,
    required this.stocks,
    required this.onMore,
  });

  final String title;
  final List<HoldingStock> stocks;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: SectionHeader(
              title: title,
              actionLabel: '더보기',
              onAction: onMore,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...stocks.map(
            (stock) => InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StockDetailScreen(stock: stock),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  stock.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                stock.code,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${stock.quantity}주  •  ₩${_format(stock.buyPrice)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PercentageText(
                          value:
                              '${stock.profitRate.abs().toStringAsFixed(2)}%',
                          isPositive: stock.isPositive,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₩${_format(stock.evaluationAmount)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Row(
              children: [
                Text(
                  '총 ${stocks.length}종목',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '₩${_format(stocks.fold<int>(0, (sum, stock) => sum + stock.evaluationAmount))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortSellPreviewCard extends StatelessWidget {
  const _ShortSellPreviewCard({required this.rankings, required this.onMore});

  final List<RankingStock> rankings;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: SectionHeader(
              title: '공매도 순위',
              leading: const Icon(
                Icons.south_east,
                color: AppColors.positive,
                size: 18,
              ),
              actionLabel: '더보기',
              onAction: onMore,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          ...rankings.map(
            (stock) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F0),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${stock.rank}',
                      style: const TextStyle(
                        color: AppColors.positive,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          stock.code,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stock.changeRate.abs().toStringAsFixed(2)}%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.positive),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stock.isPositive ? '▲' : '▼'} ${stock.extraValue.replaceAll('주', '')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: stock.isPositive
                              ? AppColors.positive
                              : AppColors.negative,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Text(
              '전일 기준 공매도 거래 비중 상위 종목',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.tips});

  final List<TipCard> tips;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '투자 팁 💡'),
          const SizedBox(height: 14),
          ...tips.map(
            (tip) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute 갱신';
}
