import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/api_provider.dart';
import '../../providers/home_provider.dart';
import '../../viewmodels/home_view_state.dart';
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
    final selectedAccount = ref.watch(selectedAccountProvider);

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
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 22),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const AlarmScreen())),
                        icon: const Icon(Icons.notifications_none, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (state.accountSyncErrorMessage != null) ...[
                    _AccountSyncErrorBanner(
                      title: state.accountSyncErrorTitle ?? '계좌 연동이 원활하지 않습니다',
                      message: state.accountSyncErrorMessage!,
                      onRetry: notifier.refreshAll,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _ChipRow(),
                  const SizedBox(height: 16),
                  _SummaryCard(
                    summary: state.summary,
                    lastUpdated: state.lastUpdated,
                    onRefresh: notifier.refreshRealtimeSections,
                    isSyncing: state.isSyncing,
                    syncStatus: state.syncStatus,
                  ),
                  const SizedBox(height: 16),
                  _MarketSummaryCard(
                    indexes: state.marketIndexes,
                    lastUpdated: state.lastUpdated,
                    onRefresh: notifier.refreshRealtimeSections,
                    isSyncing: state.isSyncing,
                    syncStatus: state.syncStatus,
                  ),
                  const SizedBox(height: 16),
                  if (selectedAccount?.isIsa == true) ...[
                    const SizedBox(height: 16),
                    _IsaAccountNoticeCard(
                      onRetry: notifier.refreshAll,
                      message: state.accountSyncErrorMessage,
                      isSyncing: state.isSyncing,
                    ),
                  ] else ...[
                    _HoldingsPreviewCard(
                      title: '국내 보유주식',
                      stocks: state.domesticHoldings,
                      onRetry: notifier.refreshAll,
                      isSyncing: state.isSyncing,
                      onMore: state.domesticHoldings.isEmpty
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    HoldingsDetailScreen(holdings: state.domesticHoldings),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    _HoldingsPreviewCard(
                      title: '해외 보유주식',
                      stocks: state.usHoldings,
                      onRetry: notifier.refreshAll,
                      isSyncing: state.isSyncing,
                      onMore: state.usHoldings.isEmpty ? null : () {},
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ShortSellPreviewCard(
                    rankings: state.shortSellRankings.take(3).toList(),
                    onRetry: notifier.refreshAll,
                    isSyncing: state.isSyncing,
                    onMore: state.shortSellRankings.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ShortSellDetailScreen(rankings: state.shortSellRankings),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _TipsCard(
                    tips: state.tips,
                    onRetry: notifier.refreshAll,
                    isSyncing: state.isSyncing,
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
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

class _AccountSyncErrorBanner extends StatelessWidget {
  const _AccountSyncErrorBanner({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0C1BA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.error_outline, color: Color(0xFFD15445), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF9E3C30),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9E3C30),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 시도'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD15445),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.summary,
    required this.lastUpdated,
    required this.onRefresh,
    required this.isSyncing,
    required this.syncStatus,
  });

  final PortfolioSummary summary;
  final DateTime lastUpdated;
  final Future<void> Function() onRefresh;
  final bool isSyncing;
  final HomeSyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final isPositive = summary.profitRate >= 0;
    final rateText = summary.profitRate.abs().toStringAsFixed(1);
    final profitAmountText = _format(summary.profitAmount.abs());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '보유 자산',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              _SectionRefreshStatus(
                lastUpdated: lastUpdated,
                isSyncing: isSyncing,
                syncStatus: syncStatus,
                onRefresh: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '₩${_format(summary.asset)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '총 투자 금액',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '₩${_format(summary.invested)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 18),
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${isPositive ? '▲' : '▼'} ${isPositive ? '+' : '-'}$rateText%  (${isPositive ? '+' : '-'}₩$profitAmountText)',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 18,
                        color: isPositive ? const Color(0xFF18AD5A) : AppColors.negative,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('📈 최근 1주 수익률 변화', style: Theme.of(context).textTheme.bodySmall),
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

class _IsaAccountNoticeCard extends StatelessWidget {
  const _IsaAccountNoticeCard({
    required this.onRetry,
    required this.message,
    required this.isSyncing,
  });

  final Future<void> Function() onRetry;
  final String? message;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'ISA 중개형 계좌'),
          const SizedBox(height: 12),
          Text(
            message ??
                '현재 선택한 ISA 중개형 계좌는 계좌 잔고/자산 OpenAPI 지원 범위를 확인 중입니다.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          _RetryButton(onRetry: onRetry, isSyncing: isSyncing),
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
    required this.isSyncing,
    required this.syncStatus,
  });

  final List<MarketIndex> indexes;
  final DateTime lastUpdated;
  final Future<void> Function() onRefresh;
  final bool isSyncing;
  final HomeSyncStatus syncStatus;

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
                  leading: Icon(Icons.bar_chart_outlined, color: AppColors.textSecondary),
                ),
              ),
              _SectionRefreshStatus(
                lastUpdated: lastUpdated,
                isSyncing: isSyncing,
                syncStatus: syncStatus,
                onRefresh: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (indexes.isEmpty)
            _RetryEmptyState(
              message: '마켓 데이터를 불러오지 못했습니다.',
              onRetry: onRefresh,
              isSyncing: isSyncing,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: indexes
                  .map(
                    (index) => Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MarketIndexDetailScreen(index: index),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              Text(
                                index.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  index.value,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              PercentageText(
                                value: index.changeRate.replaceAll('+', '').replaceAll('-', ''),
                                isPositive: index.isPositive,
                                fontSize: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _HoldingsPreviewCard extends StatelessWidget {
  const _HoldingsPreviewCard({
    required this.title,
    required this.stocks,
    required this.onMore,
    required this.onRetry,
    required this.isSyncing,
  });

  final String title;
  final List<HoldingStock> stocks;
  final VoidCallback? onMore;
  final Future<void> Function() onRetry;
  final bool isSyncing;

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
              actionLabel: stocks.isEmpty ? null : '더보기',
              onAction: onMore,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (stocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: _RetryEmptyState(
                message: '$title 데이터를 불러오지 못했거나 지원하지 않는 계좌 유형입니다.',
                onRetry: onRetry,
                isSyncing: isSyncing,
              ),
            )
          else
            ...stocks.map(
              (stock) => InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen.fromHolding(stock: stock),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(stock.code, style: Theme.of(context).textTheme.bodySmall),
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
                            value: '${stock.profitRate.abs().toStringAsFixed(2)}%',
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
  const _ShortSellPreviewCard({
    required this.rankings,
    required this.onMore,
    required this.onRetry,
    required this.isSyncing,
  });

  final List<RankingStock> rankings;
  final VoidCallback? onMore;
  final Future<void> Function() onRetry;
  final bool isSyncing;

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
              leading: const Icon(Icons.south_east, color: AppColors.positive, size: 18),
              actionLabel: '더보기',
              onAction: onMore,
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (rankings.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: _RetryEmptyState(
                message: '공매도 데이터를 불러오지 못했습니다.',
                onRetry: onRetry,
                isSyncing: isSyncing,
              ),
            )
          else ...[
            ...rankings.map(
              (stock) => InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen.fromRanking(stock: stock),
                  ),
                ),
                child: Padding(
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
                            Text(stock.name, style: Theme.of(context).textTheme.titleMedium),
                            Text(stock.code, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${stock.changeRate.abs().toStringAsFixed(2)}%',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(color: AppColors.positive),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stock.isPositive ? '▲' : '▼'} ${stock.extraValue.replaceAll('주', '')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: stock.isPositive ? AppColors.positive : AppColors.negative,
                            ),
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
              child: Text('전일 기준 공매도 거래 비중 상위 종목', style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({
    required this.tips,
    required this.onRetry,
    required this.isSyncing,
  });

  final List<TipCard> tips;
  final Future<void> Function() onRetry;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '투자 팁 💡'),
          const SizedBox(height: 14),
          if (tips.isEmpty)
            _RetryEmptyState(
              message: '표시할 투자 팁이 없습니다.',
              onRetry: onRetry,
              isSyncing: isSyncing,
            )
          else
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
                    Text(tip.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      tip.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
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

class _RetryEmptyState extends StatelessWidget {
  const _RetryEmptyState({
    required this.message,
    required this.onRetry,
    required this.isSyncing,
  });

  final String message;
  final Future<void> Function() onRetry;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        _RetryButton(onRetry: onRetry, isSyncing: isSyncing),
      ],
    );
  }
}

class _SectionRefreshStatus extends StatelessWidget {
  const _SectionRefreshStatus({
    required this.lastUpdated,
    required this.isSyncing,
    required this.syncStatus,
    required this.onRefresh,
  });

  final DateTime lastUpdated;
  final bool isSyncing;
  final HomeSyncStatus syncStatus;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isSyncing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            _syncStatusLabel(syncStatus),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_formatTime(lastUpdated), style: Theme.of(context).textTheme.bodySmall),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh, size: 20),
          color: AppColors.textSecondary,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.onRetry,
    required this.isSyncing,
  });

  final Future<void> Function() onRetry;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: isSyncing ? null : onRetry,
      icon: isSyncing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: Text(isSyncing ? '갱신 중' : '재시도'),
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
