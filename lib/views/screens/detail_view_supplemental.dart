part of 'detail_views.dart';

class PortfolioProfitHistoryScreen extends ConsumerWidget {
  const PortfolioProfitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(portfolioProfitHistoryProvider);

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('내 자산')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(portfolioProfitHistoryProvider);
          await ref.read(portfolioProfitHistoryProvider.future);
        },
        child: historyAsync.when(
          data: (history) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const InfoBanner(
                message:
                    'API 정의서 기준으로 현재 자산, 예수금, 자산 구성, 기간별 실현손익 정보를 함께 표시합니다.',
              ),
              if (history.messages.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final message in history.messages) ...[
                  AppCard(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ProfitSummaryMetricCard(
                      title: '현재 수익률',
                      rate: history.currentProfitRate,
                      amount: history.currentProfitAmount,
                      amountLabel: '평가손익',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfitSummaryMetricCard(
                      title: '총 수익률',
                      rate: history.totalProfitRate,
                      amount: history.totalRealizedProfitAmount,
                      amountLabel: '누적 실현손익',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _AssetMetricCard(
                      title: '현재 자산',
                      value: '${_currency(history.currentAssetAmount)}원',
                      subtitle:
                          '투자원금 ${_currency(history.currentInvestedAmount)}원',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AssetMetricCard(
                      title: '순자산',
                      value: '${_currency(history.netAssetAmount)}원',
                      subtitle:
                          '총평가 ${_currency(history.totalEvaluationAmount)}원',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AssetMetricCard(
                      title: '예수금',
                      value: '${_currency(history.depositAmount)}원',
                      subtitle:
                          'D+1 ${_currency(history.nextDayDepositAmount)}원  •  D+2 ${_currency(history.d2DepositAmount)}원',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AssetMetricCard(
                      title: '유가 평가',
                      value: '${_currency(history.securityEvaluationAmount)}원',
                      subtitle:
                          '평가손익 ${history.evaluationProfitAmount >= 0 ? '+' : '-'}${_currency(history.evaluationProfitAmount.abs())}원',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: '자산 구성'),
              const SizedBox(height: 10),
              if (history.assetCategories.isEmpty)
                const AppCard(child: Text('표시할 자산 구성 데이터가 없습니다.'))
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < history.assetCategories.length;
                        index++
                      )
                        _AssetCategoryTile(
                          category: history.assetCategories[index],
                          showDivider:
                              index < history.assetCategories.length - 1,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const SectionHeader(title: '기간별 실현손익'),
              const SizedBox(height: 10),
              if (history.entries.isEmpty)
                const AppCard(child: Text('조회 기간 내 손익 데이터가 없습니다.'))
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < history.entries.length;
                        index++
                      )
                        _ProfitHistoryTile(
                          entry: history.entries[index],
                          showDivider: index < history.entries.length - 1,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: const [
              SizedBox(height: 120),
              Center(child: CircularProgressIndicator()),
            ],
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '수익률 데이터를 불러오지 못했습니다.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$error',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: () =>
                          ref.invalidate(portfolioProfitHistoryProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    return _ShortSellDetailContent(rankings: rankings);
  }
}

class _ProfitSummaryMetricCard extends StatelessWidget {
  const _ProfitSummaryMetricCard({
    required this.title,
    required this.rate,
    required this.amount,
    required this.amountLabel,
  });

  final String title;
  final double rate;
  final int amount;
  final String amountLabel;

  @override
  Widget build(BuildContext context) {
    final isPositive = rate >= 0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            '${isPositive ? '+' : '-'}${rate.abs().toStringAsFixed(2)}%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: isPositive ? AppColors.positive : AppColors.negative,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$amountLabel ${amount >= 0 ? '+' : '-'}${_currency(amount.abs())}원',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ProfitHistoryTile extends StatelessWidget {
  const _ProfitHistoryTile({required this.entry, required this.showDivider});

  final PortfolioProfitHistoryEntry entry;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isPositive = entry.profitRate >= 0;
    final dateLabel = _formatHistoryDate(entry.date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '매수 ${_currency(entry.buyAmount)}원  •  매도 ${_currency(entry.sellAmount)}원',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '수수료 ${_currency(entry.fee)}원  •  세금 ${_currency(entry.tax)}원',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.realizedProfitAmount >= 0 ? '+' : '-'}${_currency(entry.realizedProfitAmount.abs())}원',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: entry.realizedProfitAmount >= 0
                      ? AppColors.positive
                      : AppColors.negative,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${isPositive ? '+' : '-'}${entry.profitRate.abs().toStringAsFixed(2)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isPositive ? AppColors.positive : AppColors.negative,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetMetricCard extends StatelessWidget {
  const _AssetMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetCategoryTile extends StatelessWidget {
  const _AssetCategoryTile({required this.category, required this.showDivider});

  final PortfolioAssetCategory category;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isPositive = category.profitAmount >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppColors.border))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${category.weightRate.toStringAsFixed(2)}%',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '매입 ${_currency(category.purchaseAmount)}원  •  평가 ${_currency(category.evaluationAmount)}원',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            '손익 ${isPositive ? '+' : '-'}${_currency(category.profitAmount.abs())}원  •  순자산 ${_currency(category.netAssetAmount)}원',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isPositive ? AppColors.positive : AppColors.negative,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortSellDetailContent extends ConsumerStatefulWidget {
  const _ShortSellDetailContent({required this.rankings});

  final List<RankingStock> rankings;

  @override
  ConsumerState<_ShortSellDetailContent> createState() =>
      _ShortSellDetailContentState();
}

class _ShortSellDetailContentState
    extends ConsumerState<_ShortSellDetailContent> {
  bool _showSourceBanner = true;
  bool _showDelayBanner = true;

  @override
  Widget build(BuildContext context) {
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
      body: RefreshIndicator(
        onRefresh: ref.read(homeViewModelProvider.notifier).refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_showSourceBanner)
              InfoBanner(
                message: '데이터는 한국투자증권 API 기준입니다.',
                onDismiss: () {
                  setState(() {
                    _showSourceBanner = false;
                  });
                },
              ),
            if (_showSourceBanner && _showDelayBanner)
              const SizedBox(height: 10),
            if (_showDelayBanner)
              InfoBanner(
                message: '공매도 정보는 20분 지연 제공 됩니다.',
                onDismiss: () {
                  setState(() {
                    _showDelayBanner = false;
                  });
                },
              ),
            const SizedBox(height: 12),
            ...widget.rankings.map(
              (stock) => InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen.fromRanking(stock: stock),
                  ),
                ),
                child: Container(
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
            ),
          ],
        ),
      ),
    );
  }
}
