part of 'home_screen.dart';

class _MarketTickerEntry {
  const _MarketTickerEntry({
    required this.title,
    required this.value,
    required this.detail,
    required this.isPositive,
  });

  final String title;
  final String value;
  final String detail;
  final bool? isPositive;
}

class _MarketSummaryTickerBar extends ConsumerStatefulWidget {
  const _MarketSummaryTickerBar({
    required this.indexes,
    required this.usdKrwRateAsync,
    required this.sectionState,
    required this.onRefresh,
    required this.syncStatus,
  });

  final List<MarketIndex> indexes;
  final AsyncValue<double> usdKrwRateAsync;
  final HomeSectionSyncState sectionState;
  final Future<void> Function() onRefresh;
  final HomeSyncStatus syncStatus;

  @override
  ConsumerState<_MarketSummaryTickerBar> createState() =>
      _MarketSummaryTickerBarState();
}

class _MarketSummaryTickerBarState
    extends ConsumerState<_MarketSummaryTickerBar> {
  Timer? _tickerTimer;
  int _currentIndex = 0;
  int _entryCount = 0;

  @override
  void initState() {
    super.initState();
    _configureTicker();
  }

  @override
  void didUpdateWidget(covariant _MarketSummaryTickerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCount = _buildMarketTickerEntries(
      indexes: widget.indexes,
      usdKrwRateAsync: widget.usdKrwRateAsync,
    ).length;
    if (nextCount != _entryCount) {
      _configureTicker();
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildMarketTickerEntries(
      indexes: widget.indexes,
      usdKrwRateAsync: widget.usdKrwRateAsync,
    );
    if (_currentIndex >= entries.length) {
      _currentIndex = 0;
    }
    final currentEntry = entries[_currentIndex];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _MarketSummaryOverviewSheet(),
        ),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '마켓 요약',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _tickerStatusLabel(
                              widget.sectionState,
                              widget.syncStatus,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 22,
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0, 1),
                              end: Offset.zero,
                            ).animate(animation);
                            return SlideTransition(
                              position: offset,
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: _MarketTickerRow(
                            key: ValueKey(
                              '${currentEntry.title}-${currentEntry.value}-${currentEntry.detail}',
                            ),
                            entry: currentEntry,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.sectionState.isSyncing
                    ? null
                    : widget.onRefresh,
                icon: widget.sectionState.isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 20),
                color: AppColors.textSecondary,
                visualDensity: VisualDensity.compact,
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _configureTicker() {
    _tickerTimer?.cancel();
    final count = _buildMarketTickerEntries(
      indexes: widget.indexes,
      usdKrwRateAsync: widget.usdKrwRateAsync,
    ).length;
    _entryCount = count;
    if (count <= 1) {
      if (_currentIndex != 0) {
        setState(() {
          _currentIndex = 0;
        });
      }
      return;
    }

    _tickerTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % count;
      });
    });
  }
}

class _MarketTickerRow extends StatelessWidget {
  const _MarketTickerRow({super.key, required this.entry});

  final _MarketTickerEntry entry;

  @override
  Widget build(BuildContext context) {
    final detailColor = switch (entry.isPositive) {
      true => AppColors.accent,
      false => AppColors.negative,
      null => AppColors.textSecondary,
    };

    return Row(
      children: [
        Text(
          entry.title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            entry.value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            entry.detail,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: detailColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _MarketSummaryOverviewSheet extends ConsumerWidget {
  const _MarketSummaryOverviewSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final usdKrwRateAsync = ref.watch(usdKrwRateProvider);
    final notifier = ref.read(homeViewModelProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
        child: _MarketSummaryCard(
          indexes: state.marketIndexes,
          usdKrwRateAsync: usdKrwRateAsync,
          sectionState: state.sectionState(HomeSection.market),
          onRefresh: () => notifier.refreshSection(HomeSection.market),
          syncStatus: state.syncStatus,
        ),
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
            child: Icon(
              Icons.error_outline,
              color: Color(0xFFD15445),
              size: 18,
            ),
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
    required this.portfolioHistoryAsync,
    required this.sectionState,
    required this.onRefresh,
    required this.syncStatus,
    required this.onMore,
  });

  final PortfolioSummary summary;
  final AsyncValue<PortfolioProfitHistory> portfolioHistoryAsync;
  final HomeSectionSyncState sectionState;
  final Future<void> Function() onRefresh;
  final HomeSyncStatus syncStatus;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final totalProfitHistory = portfolioHistoryAsync.valueOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  title: '보유 자산',
                  actionLabel: '더보기',
                  onAction: onMore,
                ),
              ),
              _SectionRefreshStatus(
                sectionState: sectionState,
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
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontSize: 26),
            ),
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
            ).textTheme.headlineSmall?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ProfitMetricPanel(
                  label: '현재 수익률',
                  profitRate: summary.profitRate,
                  profitAmount: summary.profitAmount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: totalProfitHistory != null
                    ? _ProfitMetricPanel(
                        label: '총 수익률',
                        profitRate: totalProfitHistory.totalProfitRate,
                        profitAmount:
                            totalProfitHistory.totalRealizedProfitAmount,
                      )
                    : _ProfitMetricPlaceholder(
                        label: '총 수익률',
                        isLoading: portfolioHistoryAsync.isLoading,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfitMetricPanel extends StatelessWidget {
  const _ProfitMetricPanel({
    required this.label,
    required this.profitRate,
    required this.profitAmount,
  });

  final String label;
  final double profitRate;
  final int profitAmount;

  @override
  Widget build(BuildContext context) {
    final isPositive = profitRate >= 0;
    final rateText = profitRate.abs().toStringAsFixed(1);
    final profitAmountText = _format(profitAmount.abs());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          '${isPositive ? '▲' : '▼'} ${isPositive ? '+' : '-'}$rateText%',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            color: isPositive ? const Color(0xFF18AD5A) : AppColors.negative,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${isPositive ? '+' : '-'}₩$profitAmountText',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isPositive ? const Color(0xFF18AD5A) : AppColors.negative,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfitMetricPlaceholder extends StatelessWidget {
  const _ProfitMetricPlaceholder({
    required this.label,
    required this.isLoading,
  });

  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          isLoading ? '불러오는 중' : '데이터 없음',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: 18,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '-',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
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
            message ?? '현재 선택한 ISA 중개형 계좌는 계좌 잔고/자산 OpenAPI 지원 범위를 확인 중입니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _RetryButton(
            onRetry: onRetry,
            sectionState: HomeSectionSyncState(
              lastUpdated: DateTime.now(),
              isSyncing: isSyncing,
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
    required this.usdKrwRateAsync,
    required this.sectionState,
    required this.onRefresh,
    required this.syncStatus,
  });

  final List<MarketIndex> indexes;
  final AsyncValue<double> usdKrwRateAsync;
  final HomeSectionSyncState sectionState;
  final Future<void> Function() onRefresh;
  final HomeSyncStatus syncStatus;

  @override
  Widget build(BuildContext context) {
    final orderedIndexes = _orderedMarketIndexes(indexes);
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
              _SectionRefreshStatus(
                sectionState: sectionState,
                syncStatus: syncStatus,
                onRefresh: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (orderedIndexes.isEmpty && usdKrwRateAsync.valueOrNull == null)
            _RetryEmptyState(
              message: '마켓 데이터를 불러오지 못했습니다.',
              onRetry: onRefresh,
              sectionState: sectionState,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tiles = <Widget>[
                  for (final index in orderedIndexes)
                    _MarketSummaryTile(
                      title: index.name,
                      value: index.value,
                      footer: PercentageText(
                        value: index.changeRate
                            .replaceAll('+', '')
                            .replaceAll('-', ''),
                        isPositive: index.isPositive,
                        fontSize: 14,
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MarketIndexDetailScreen(index: index),
                        ),
                      ),
                    ),
                  _ExchangeRateSummaryTile(usdKrwRateAsync: usdKrwRateAsync),
                ];

                final crossAxisCount = constraints.maxWidth >= 520 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: crossAxisCount >= 4 ? 1.05 : 1.4,
                  children: tiles,
                );
              },
            ),
        ],
      ),
    );
  }
}

List<_MarketTickerEntry> _buildMarketTickerEntries({
  required List<MarketIndex> indexes,
  required AsyncValue<double> usdKrwRateAsync,
}) {
  final orderedIndexes = _orderedMarketIndexes(indexes);
  final indexByName = {
    for (final index in orderedIndexes) index.name: index,
  };
  final entries = <_MarketTickerEntry>[
    for (final name in const ['코스피', '코스닥', '나스닥', 'S&P500'])
      if (indexByName[name] case final index?)
        _MarketTickerEntry(
          title: index.name,
          value: index.value,
          detail: index.changeRate,
          isPositive: index.isPositive,
        )
      else
        _MarketTickerEntry(
          title: name,
          value: '-',
          detail: '실시간 대기 중',
          isPositive: null,
        ),
  ];
  final rate = usdKrwRateAsync.valueOrNull;
  entries.add(
    _MarketTickerEntry(
      title: '환율',
      value: rate == null ? '-' : '${_format(rate.round())}원',
      detail: rate == null ? '실시간 대기 중' : 'USD/KRW 실시간',
      isPositive: null,
    ),
  );

  return entries;
}

List<MarketIndex> _orderedMarketIndexes(List<MarketIndex> indexes) {
  const orderedNames = ['코스피', '코스닥', '나스닥', 'S&P500'];
  final byName = {for (final index in indexes) index.name: index};
  return [
    for (final name in orderedNames)
      if (byName[name] != null) byName[name]!,
  ];
}

String _tickerStatusLabel(
  HomeSectionSyncState sectionState,
  HomeSyncStatus syncStatus,
) {
  if (sectionState.isSyncing) {
    return _syncStatusLabel(syncStatus);
  }
  return '${_formatTime(sectionState.lastUpdated)} 기준';
}

class _MarketSummaryTile extends StatelessWidget {
  const _MarketSummaryTile({
    required this.title,
    required this.value,
    required this.footer,
    this.onTap,
  });

  final String title;
  final String value;
  final Widget footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: 8),
          footer,
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: content,
    );
  }
}

class _ExchangeRateSummaryTile extends StatelessWidget {
  const _ExchangeRateSummaryTile({required this.usdKrwRateAsync});

  final AsyncValue<double> usdKrwRateAsync;

  @override
  Widget build(BuildContext context) {
    final rate = usdKrwRateAsync.valueOrNull;
    return _MarketSummaryTile(
      title: '환율',
      value: rate == null ? '-' : '${_format(rate.round())}원',
      footer: Text(
        rate == null ? '실시간 환율 대기 중' : 'USD/KRW 실시간 반영',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _HoldingsPreviewCard extends ConsumerStatefulWidget {
  const _HoldingsPreviewCard({
    required this.title,
    required this.stocks,
    required this.onMore,
    required this.onRetry,
    required this.sectionState,
  });

  final String title;
  final List<HoldingStock> stocks;
  final VoidCallback? onMore;
  final Future<void> Function() onRetry;
  final HomeSectionSyncState sectionState;

  @override
  ConsumerState<_HoldingsPreviewCard> createState() =>
      _HoldingsPreviewCardState();
}

class _HoldingsPreviewCardState extends ConsumerState<_HoldingsPreviewCard> {
  bool _showKrw = true;

  @override
  Widget build(BuildContext context) {
    final hasOverseas = widget.stocks.any(
      (stock) => stock.marketType == StockMarketType.overseas,
    );
    final exchangeRate = hasOverseas
        ? ref.watch(usdKrwRateProvider).valueOrNull
        : null;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: widget.title,
                    actionLabel: widget.stocks.isEmpty ? null : '더보기',
                    onAction: widget.onMore,
                  ),
                ),
                if (hasOverseas)
                  _CompactCurrencyToggle(
                    showKrw: _showKrw,
                    exchangeRate: exchangeRate,
                    onChanged: (value) {
                      setState(() {
                        _showKrw = value;
                      });
                    },
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (widget.stocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: _RetryEmptyState(
                message: '${widget.title} 데이터를 불러오지 못했거나 지원하지 않는 계좌 유형입니다.',
                onRetry: widget.onRetry,
                sectionState: widget.sectionState,
              ),
            )
          else
            ...widget.stocks.map(
              (stock) => InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen.fromHolding(stock: stock),
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
                              '${stock.quantity}주  •  ${_formatHoldingAmountHome(stock.buyPrice, stock: stock, showKrw: _showKrw, exchangeRate: exchangeRate)}',
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
                            _formatHoldingAmountHome(
                              stock.evaluationAmount,
                              stock: stock,
                              showKrw: _showKrw,
                              exchangeRate: exchangeRate,
                            ),
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
                  '총 ${widget.stocks.length}종목',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatHoldingsTotalHome(
                    widget.stocks,
                    showKrw: _showKrw,
                    exchangeRate: exchangeRate,
                  ),
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
    required this.sectionState,
  });

  final List<RankingStock> rankings;
  final VoidCallback? onMore;
  final Future<void> Function() onRetry;
  final HomeSectionSyncState sectionState;

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
          if (rankings.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: _RetryEmptyState(
                message: '공매도 데이터를 불러오지 못했습니다.',
                onRetry: onRetry,
                sectionState: sectionState,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Text(
                '전일 기준 공매도 거래 비중 상위 종목',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeNewsPreviewCard extends StatelessWidget {
  const _HomeNewsPreviewCard({
    required this.items,
    required this.sectionState,
    required this.onRetry,
    required this.onOpenList,
  });

  final List<HomeNewsItem> items;
  final HomeSectionSyncState sectionState;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenList;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: '오늘의 뉴스',
                    leading: const Icon(
                      Icons.article_outlined,
                      color: AppColors.accent,
                      size: 18,
                    ),
                    actionLabel: items.isEmpty ? null : '전체보기',
                    onAction: items.isEmpty ? null : onOpenList,
                  ),
                ),
                _SectionRefreshStatus(
                  sectionState: sectionState,
                  syncStatus: HomeSyncStatus.idle,
                  onRefresh: onRetry,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: _RetryEmptyState(
                message: '홈 뉴스 데이터를 불러오지 못했습니다.',
                onRetry: onRetry,
                sectionState: sectionState,
              ),
            )
          else
            ...items
                .take(5)
                .map(
                  (item) => _NewsListTile(item: item),
                ),
        ],
      ),
    );
  }
}

class _InvestorFlowPreviewCard extends StatelessWidget {
  const _InvestorFlowPreviewCard({
    required this.flows,
    required this.sectionState,
    required this.onRetry,
  });

  final List<HomeInvestorFlow> flows;
  final HomeSectionSyncState sectionState;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: '투자자 수급',
                    leading: const Icon(
                      Icons.account_balance_outlined,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ),
                ),
                _SectionRefreshStatus(
                  sectionState: sectionState,
                  syncStatus: HomeSyncStatus.idle,
                  onRefresh: onRetry,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (flows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: _RetryEmptyState(
                message: '투자자 수급 데이터를 불러오지 못했습니다.',
                onRetry: onRetry,
                sectionState: sectionState,
              ),
            )
          else
            ...flows.map(
              (flow) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flow.marketLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _InvestorFlowMetric(
                            label: '외국인',
                            amount: flow.foreignNetBuyAmount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InvestorFlowMetric(
                            label: '기관',
                            amount: flow.institutionNetBuyAmount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InvestorFlowMetric(
                            label: '개인',
                            amount: flow.individualNetBuyAmount,
                          ),
                        ),
                      ],
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

class _MomentumPreviewCard extends StatelessWidget {
  const _MomentumPreviewCard({
    required this.domesticTopMovers,
    required this.domesticVolumeLeaders,
    required this.overseasTopMovers,
    required this.overseasVolumeLeaders,
    required this.sectionState,
    required this.onRetry,
    required this.onOpenDomesticTopMovers,
    required this.onOpenDomesticVolumeLeaders,
    required this.onOpenOverseasTopMovers,
    required this.onOpenOverseasVolumeLeaders,
  });

  final List<RankingStock> domesticTopMovers;
  final List<RankingStock> domesticVolumeLeaders;
  final List<RankingStock> overseasTopMovers;
  final List<RankingStock> overseasVolumeLeaders;
  final HomeSectionSyncState sectionState;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenDomesticTopMovers;
  final VoidCallback onOpenDomesticVolumeLeaders;
  final VoidCallback onOpenOverseasTopMovers;
  final VoidCallback onOpenOverseasVolumeLeaders;

  @override
  Widget build(BuildContext context) {
    final hasData =
        domesticTopMovers.isNotEmpty ||
        domesticVolumeLeaders.isNotEmpty ||
        overseasTopMovers.isNotEmpty ||
        overseasVolumeLeaders.isNotEmpty;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: SectionHeader(
                    title: '급등락/거래량',
                    leading: const Icon(
                      Icons.bolt_outlined,
                      color: AppColors.accent,
                      size: 18,
                    ),
                  ),
                ),
                _SectionRefreshStatus(
                  sectionState: sectionState,
                  syncStatus: HomeSyncStatus.idle,
                  onRefresh: onRetry,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (!hasData)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: _RetryEmptyState(
                message: '급등락/거래량 데이터를 불러오지 못했습니다.',
                onRetry: onRetry,
                sectionState: sectionState,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MomentumMarketSection(
                    title: '국내',
                    leftTitle: '급등 상위',
                    rightTitle: '거래량 상위',
                    leftStocks: domesticTopMovers,
                    rightStocks: domesticVolumeLeaders,
                    onOpenLeft: onOpenDomesticTopMovers,
                    onOpenRight: onOpenDomesticVolumeLeaders,
                  ),
                  const SizedBox(height: 12),
                  _MomentumMarketSection(
                    title: '해외',
                    leftTitle: '급등 상위',
                    rightTitle: '거래량 상위',
                    leftStocks: overseasTopMovers,
                    rightStocks: overseasVolumeLeaders,
                    onOpenLeft: onOpenOverseasTopMovers,
                    onOpenRight: onOpenOverseasVolumeLeaders,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MomentumMarketSection extends StatelessWidget {
  const _MomentumMarketSection({
    required this.title,
    required this.leftTitle,
    required this.rightTitle,
    required this.leftStocks,
    required this.rightStocks,
    required this.onOpenLeft,
    required this.onOpenRight,
  });

  final String title;
  final String leftTitle;
  final String rightTitle;
  final List<RankingStock> leftStocks;
  final List<RankingStock> rightStocks;
  final VoidCallback onOpenLeft;
  final VoidCallback onOpenRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MomentumColumn(
                title: leftTitle,
                stocks: leftStocks,
                onMore: onOpenLeft,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MomentumColumn(
                title: rightTitle,
                stocks: rightStocks,
                onMore: onOpenRight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MomentumColumn extends StatelessWidget {
  const _MomentumColumn({
    required this.title,
    required this.stocks,
    required this.onMore,
  });

  final String title;
  final List<RankingStock> stocks;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurfaceSoft
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: stocks.isEmpty ? null : onMore,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: stocks.isEmpty
                        ? AppColors.textSecondary
                        : AppColors.accent,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (stocks.isEmpty)
            Text('데이터 없음', style: Theme.of(context).textTheme.bodySmall)
          else
            ...stocks
                .take(3)
                .map(
                  (stock) => InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            StockDetailScreen.fromRanking(stock: stock),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '${stock.rank}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stock.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  stock.extraValue,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          PercentageText(
                            value:
                                '${stock.changeRate.abs().toStringAsFixed(2)}%',
                            isPositive: stock.isPositive,
                            fontSize: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _InvestorFlowMetric extends StatelessWidget {
  const _InvestorFlowMetric({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final isPositive = amount >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          _formatSignedAmount(amount),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isPositive ? AppColors.positive : AppColors.negative,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NewsListTile extends StatelessWidget {
  const _NewsListTile({required this.item});

  final HomeNewsItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openNewsLink(context, item),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  item.source,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(item.publishedAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (item.primaryName != null &&
                    item.primaryName!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.primaryName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class HomeNewsListScreen extends StatelessWidget {
  const HomeNewsListScreen({super.key, required this.items});

  final List<HomeNewsItem> items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오늘의 뉴스')),
      body: SafeArea(
        child: items.isEmpty
            ? const Center(child: Text('표시할 뉴스가 없습니다.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemBuilder: (context, index) => AppCard(
                  padding: EdgeInsets.zero,
                  child: _NewsListTile(item: items[index]),
                ),
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: items.length,
              ),
      ),
    );
  }
}

class HomeRankingListScreen extends StatelessWidget {
  const HomeRankingListScreen({
    super.key,
    required this.title,
    required this.stocks,
  });

  final String title;
  final List<RankingStock> stocks;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        bottom: false,
        child: stocks.isEmpty
            ? Center(child: Text('$title 데이터가 없습니다.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                itemBuilder: (context, index) {
                  final stock = stocks[index];
                  return AppCard(
                    child: InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StockDetailScreen.fromRanking(stock: stock),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${stock.rank}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stock.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stock.extraValue,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            PercentageText(
                              value:
                                  '${stock.changeRate.abs().toStringAsFixed(2)}%',
                              isPositive: stock.isPositive,
                              fontSize: 13,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemCount: stocks.length,
              ),
      ),
    );
  }
}

Future<void> _openNewsLink(BuildContext context, HomeNewsItem item) async {
  final uri = Uri.tryParse(item.linkUrl);
  if (uri == null) {
    _showHomeSnackBar(context, '뉴스 링크를 열 수 없습니다.');
    return;
  }

  final didLaunch = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!didLaunch && context.mounted) {
    _showHomeSnackBar(context, '뉴스 링크를 열지 못했습니다.');
  }
}

void _showHomeSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _RetryEmptyState extends StatelessWidget {
  const _RetryEmptyState({
    required this.message,
    required this.onRetry,
    required this.sectionState,
  });

  final String message;
  final Future<void> Function() onRetry;
  final HomeSectionSyncState sectionState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionState.errorMessage ?? message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        _RetryButton(onRetry: onRetry, sectionState: sectionState),
      ],
    );
  }
}

class _SectionRefreshStatus extends StatelessWidget {
  const _SectionRefreshStatus({
    required this.sectionState,
    required this.syncStatus,
    required this.onRefresh,
  });

  final HomeSectionSyncState sectionState;
  final HomeSyncStatus syncStatus;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (sectionState.isSyncing) {
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
        Text(
          _formatTime(sectionState.lastUpdated),
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
  const _RetryButton({required this.onRetry, required this.sectionState});

  final Future<void> Function() onRetry;
  final HomeSectionSyncState sectionState;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: sectionState.isSyncing ? null : onRetry,
          icon: sectionState.isSyncing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(sectionState.isSyncing ? '갱신 중' : '재시도'),
        ),
        Text(
          '마지막 갱신 ${_formatTime(sectionState.lastUpdated)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _CompactCurrencyToggle extends StatelessWidget {
  const _CompactCurrencyToggle({
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniToggleChip(
          label: '원',
          selected: showKrw,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 6),
        _MiniToggleChip(
          label: r'$',
          selected: !showKrw,
          enabled: canShowUsd,
          onTap: canShowUsd ? () => onChanged(false) : null,
        ),
      ],
    );
  }
}

class _MiniToggleChip extends StatelessWidget {
  const _MiniToggleChip({
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
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.black : const Color(0xFFF0F1F4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
