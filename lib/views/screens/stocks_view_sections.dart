part of 'stocks_view.dart';

class _StocksScreenContent extends StatelessWidget {
  const _StocksScreenContent({
    required this.searchQuery,
    required this.viewState,
    required this.viewModel,
    required this.stocksAsync,
    required this.searchResultsAsync,
    required this.exchangeRate,
    required this.totalVisibleSourceCount,
    required this.liveVisibleStocks,
    required this.displayVisibleStocks,
    required this.onDismissKeyboard,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final String searchQuery;
  final StocksScreenViewState viewState;
  final StocksScreenViewModel viewModel;
  final AsyncValue<List<RankingStock>> stocksAsync;
  final AsyncValue<List<RankingStock>>? searchResultsAsync;
  final double? exchangeRate;
  final int totalVisibleSourceCount;
  final List<RankingStock> liveVisibleStocks;
  final List<RankingStock> displayVisibleStocks;
  final VoidCallback onDismissKeyboard;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trimmedSearchQuery = viewState.searchQuery.trim();
    final hasDomesticRealtimeTarget = liveVisibleStocks.any(
      (stock) => stock.marketType == StockMarketType.domestic,
    );
    final hasOverseasTarget = liveVisibleStocks.any(
      (stock) => stock.marketType == StockMarketType.overseas,
    );

    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismissKeyboard,
        child: RefreshIndicator(
          onRefresh: viewModel.refresh,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 200) {
                viewModel.loadMore(totalVisibleSourceCount);
              }
              return false;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '주식',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: _StocksSearchField(
                    searchQuery: searchQuery,
                    onSearchChanged: onSearchChanged,
                    onClearSearch: onClearSearch,
                    onDismissKeyboard: onDismissKeyboard,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 16),
                _StocksFilterCard(
                  viewState: viewState,
                  viewModel: viewModel,
                  exchangeRate: exchangeRate,
                  hasDomesticRealtimeTarget: hasDomesticRealtimeTarget,
                  hasOverseasTarget: hasOverseasTarget,
                  liveVisibleStocks: liveVisibleStocks,
                ),
                const SizedBox(height: 16),
                if (trimmedSearchQuery.isNotEmpty)
                  searchResultsAsync!.when(
                    data: (stocks) => _StocksList(
                      stocks: viewModel.applyDisplayCurrency(
                        viewModel.applyRealtimeStocks(
                          viewModel.sliceVisibleStocks(
                            stocks,
                            visibleCount: viewState.visibleCount,
                          ),
                          liveDomesticPrices: viewState.liveDomesticPrices,
                          liveOverseasPrices: viewState.liveOverseasPrices,
                          liveQuoteStocks: viewState.liveQuoteStocks,
                        ),
                        showKrwForOverseas: viewState.showKrwForOverseas,
                        exchangeRate: exchangeRate,
                      ),
                      title: '검색 결과',
                      emptyMessage: '검색 결과가 없습니다.',
                      totalCount: stocks.length,
                      selectedMarket: 'all',
                      lastRefreshTime: viewState.lastRefreshTime,
                    ),
                    loading: () => const AppCard(
                      child: SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, _) => _StocksLoadErrorCard(
                      title: '검색 결과',
                      message: '검색 결과를 불러오지 못했습니다.',
                      onRetry: viewModel.refresh,
                    ),
                  )
                else
                  stocksAsync.when(
                    data: (stocks) => _StocksList(
                      stocks: displayVisibleStocks,
                      title:
                          '${viewModel.marketTitle(viewState.selectedMarket)} · ${viewModel.categoryTitle(viewState.selectedCategory)}',
                      emptyMessage: '표시할 종목이 없습니다.',
                      totalCount: stocks.length,
                      selectedMarket: viewState.selectedMarket,
                      lastRefreshTime: viewState.lastRefreshTime,
                    ),
                    loading: () => const AppCard(
                      child: SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, _) => _StocksLoadErrorCard(
                      title: '주식 목록',
                      message: '주식 목록을 불러오지 못했습니다.',
                      onRetry: viewModel.refresh,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StocksSearchField extends StatefulWidget {
  const _StocksSearchField({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onDismissKeyboard,
    required this.isDark,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onDismissKeyboard;
  final bool isDark;

  @override
  State<_StocksSearchField> createState() => _StocksSearchFieldState();
}

class _StocksSearchFieldState extends State<_StocksSearchField> {
  static const _debounceDuration = Duration(milliseconds: 250);

  late final TextEditingController _controller;
  Timer? _debounce;
  String _lastCommittedQuery = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _lastCommittedQuery = widget.searchQuery;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant _StocksSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery == widget.searchQuery) {
      return;
    }
    if (widget.searchQuery == _controller.text) {
      return;
    }

    _lastCommittedQuery = widget.searchQuery;
    _controller
      ..text = widget.searchQuery
      ..selection = TextSelection.collapsed(offset: widget.searchQuery.length);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final value = _controller.value;
    final isComposing =
        value.composing.isValid && !value.composing.isCollapsed;
    if (isComposing) {
      _debounce?.cancel();
      return;
    }

    _debounce?.cancel();
    final nextQuery = value.text;
    _debounce = Timer(_debounceDuration, () {
      if (!mounted || _lastCommittedQuery == nextQuery) {
        return;
      }
      _lastCommittedQuery = nextQuery;
      widget.onSearchChanged(nextQuery);
    });
  }

  void _handleClear() {
    _debounce?.cancel();
    _lastCommittedQuery = '';
    _controller.clear();
    widget.onClearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final trimmedSearchQuery = widget.searchQuery.trim();
    return TextField(
      controller: _controller,
      onTapOutside: (_) => widget.onDismissKeyboard(),
      decoration: InputDecoration(
        hintText: '국내/미국 종목명 또는 종목코드 검색',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: trimmedSearchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: _handleClear,
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: widget.isDark
            ? AppColors.darkSurfaceSoft
            : const Color(0xFFF7F7F8),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _StocksFilterCard extends StatelessWidget {
  const _StocksFilterCard({
    required this.viewState,
    required this.viewModel,
    required this.exchangeRate,
    required this.hasDomesticRealtimeTarget,
    required this.hasOverseasTarget,
    required this.liveVisibleStocks,
  });

  final StocksScreenViewState viewState;
  final StocksScreenViewModel viewModel;
  final double? exchangeRate;
  final bool hasDomesticRealtimeTarget;
  final bool hasOverseasTarget;
  final List<RankingStock> liveVisibleStocks;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeader(title: '시장 카테고리')),
              _StocksRefreshStatus(
                isRefreshing: viewState.isRefreshing,
                lastRefreshTime: viewState.lastRefreshTime,
                onRefresh: viewModel.refresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CategoryChip(
                label: '전체',
                selected: viewState.selectedMarket == 'all',
                onTap: () => viewModel.updateMarket('all'),
              ),
              _CategoryChip(
                label: '국내',
                selected: viewState.selectedMarket == 'domestic',
                onTap: () => viewModel.updateMarket('domestic'),
              ),
              _CategoryChip(
                label: '해외',
                selected: viewState.selectedMarket == 'overseas',
                onTap: () => viewModel.updateMarket('overseas'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CategoryChip(
                label: '실시간 거래대금',
                selected: viewState.selectedCategory == 'tradeAmount',
                onTap: () => viewModel.updateCategory('tradeAmount'),
              ),
              _CategoryChip(
                label: '거래량',
                selected: viewState.selectedCategory == 'volume',
                onTap: () => viewModel.updateCategory('volume'),
              ),
              _CategoryChip(
                label: '등락률',
                selected: viewState.selectedCategory == 'changeRate',
                onTap: () => viewModel.updateCategory('changeRate'),
              ),
              _CategoryChip(
                label: '시가총액',
                selected: viewState.selectedCategory == 'marketCap',
                onTap: () => viewModel.updateCategory('marketCap'),
              ),
            ],
          ),
          if (viewState.selectedMarket == 'overseas' ||
              viewState.selectedMarket == 'all') ...[
            const SizedBox(height: 12),
            Text(
              viewState.selectedMarket == 'all'
                  ? '전체 목록에는 현재 국내와 미국(나스닥·뉴욕·아멕스) 종목이 함께 표시됩니다.'
                  : '해외 목록은 현재 미국(나스닥·뉴욕·아멕스) 종목을 함께 표시합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (hasOverseasTarget) ...[
            const SizedBox(height: 12),
            _StocksCurrencyToggle(
              showKrw: viewState.showKrwForOverseas,
              exchangeRate: exchangeRate,
              onChanged: viewModel.toggleShowKrwForOverseas,
            ),
          ],
          if (hasDomesticRealtimeTarget &&
              viewState.connectionState.status !=
                  KisRealtimeConnectionStatus.connected) ...[
            const SizedBox(height: 12),
            _StocksRealtimeBanner(
              connectionState: viewState.connectionState,
              onRetry: () => viewModel.syncDisplayedStocks(
                visibleStocks: liveVisibleStocks,
                exchangeRate: exchangeRate,
                forceQuoteRefresh: true,
                forceSubscriptionSync: true,
              ),
            ),
          ],
          if (viewState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              viewState.errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.negative),
            ),
          ],
        ],
      ),
    );
  }
}

class _StocksLoadErrorCard extends StatelessWidget {
  const _StocksLoadErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('재시도'),
          ),
        ],
      ),
    );
  }
}

class _StocksList extends StatelessWidget {
  const _StocksList({
    required this.stocks,
    required this.title,
    required this.emptyMessage,
    required this.totalCount,
    required this.selectedMarket,
    required this.lastRefreshTime,
  });

  final List<RankingStock> stocks;
  final String title;
  final String emptyMessage;
  final int totalCount;
  final String selectedMarket;
  final DateTime lastRefreshTime;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '총 $totalCount종목',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatRefreshTime(lastRefreshTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8, color: AppColors.border),
          if (stocks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  emptyMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          for (var index = 0; index < stocks.length; index++) ...[
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      StockDetailScreen.fromRanking(stock: stocks[index]),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${stocks[index].rank}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stocks[index].name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedMarket == 'all'
                                ? '${stocks[index].marketLabel} · ${stocks[index].code}'
                                : stocks[index].code,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatStockPrice(stocks[index]),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '전일 대비',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 6),
                            PercentageText(
                              value:
                                  '${stocks[index].changeRate.abs().toStringAsFixed(2)}%',
                              isPositive: stocks[index].isPositive,
                              fontSize: 13,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stocks[index].extraLabel} ${stocks[index].extraValue}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (index != stocks.length - 1)
              const Divider(
                height: 1,
                thickness: 0.8,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? (isDark ? AppColors.darkTextPrimary : const Color(0xFF14563E))
              : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: isDark
          ? AppColors.darkSurfaceSoft
          : Theme.of(context).cardColor,
      selectedColor: isDark ? AppColors.darkAccentSoft : AppColors.accentSoft,
      side: BorderSide(
        color: selected
            ? (isDark ? AppColors.darkAccent : AppColors.accent)
            : (isDark ? AppColors.darkBorder : AppColors.border),
      ),
    );
  }
}

class _StocksCurrencyToggle extends StatelessWidget {
  const _StocksCurrencyToggle({
    required this.showKrw,
    required this.exchangeRate,
    required this.onChanged,
  });

  final bool showKrw;
  final double? exchangeRate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final canShowKrw = exchangeRate != null && exchangeRate! > 0;

    return Row(
      children: [
        _CategoryChip(
          label: '달러',
          selected: !showKrw,
          onTap: () => onChanged(false),
        ),
        const SizedBox(width: 8),
        Opacity(
          opacity: canShowKrw ? 1 : 0.5,
          child: _CategoryChip(
            label: '원화',
            selected: showKrw,
            onTap: canShowKrw ? () => onChanged(true) : () {},
          ),
        ),
      ],
    );
  }
}

class _StocksRefreshStatus extends StatelessWidget {
  const _StocksRefreshStatus({
    required this.isRefreshing,
    required this.lastRefreshTime,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final DateTime lastRefreshTime;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatRefreshTime(lastRefreshTime),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        IconButton(
          onPressed: isRefreshing ? null : onRefresh,
          icon: isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 20),
          visualDensity: VisualDensity.compact,
          color: AppColors.textSecondary,
        ),
      ],
    );
  }
}

class _StocksRealtimeBanner extends StatelessWidget {
  const _StocksRealtimeBanner({
    required this.connectionState,
    required this.onRetry,
  });

  final KisRealtimeConnectionState connectionState;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final errorMessage = connectionState.errorMessage ?? '';
    final isMarketClosed =
        errorMessage.contains('시간이 아닙니다.') ||
        errorMessage.contains('실시간 체결 가능 시간이 아닙니다.');
    final message = switch (connectionState.status) {
      KisRealtimeConnectionStatus.connecting => '주식 목록 실시간 연결 중입니다.',
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
        children: [
          Icon(
            Icons.wifi_tethering_error_rounded,
            color: isDark ? const Color(0xFFF0B45B) : const Color(0xFFC27A11),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? const Color(0xFFF6D6A0)
                    : const Color(0xFF8B5A0A),
                height: 1.4,
              ),
            ),
          ),
          if (!isMarketClosed)
            TextButton(
              onPressed: onRetry,
              child: const Text('재연결'),
            ),
        ],
      ),
    );
  }
}

String _formatPrice(int value) {
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

String _formatStockPrice(RankingStock stock) {
  final decimals = stock.priceDecimals;
  final negative = stock.price < 0;
  final scale = _pow10(decimals);
  final absolute = stock.price.abs();
  if (stock.currencySymbol == r'$') {
    final usd = absolute / scale;
    final amount = _trimTrailingZeros(usd.toStringAsFixed(2));
    return '${negative ? '-' : ''}\$$amount';
  }
  final whole = decimals == 0 ? absolute : absolute ~/ scale;
  final rawFraction = decimals == 0
      ? ''
      : (absolute % scale).toString().padLeft(decimals, '0');
  final numberText = _formatPrice(whole);
  final amount = rawFraction.isEmpty ? numberText : '$numberText.$rawFraction';
  final prefix = stock.currencySymbol == '원' ? '' : stock.currencySymbol;
  final suffix = stock.currencySymbol == '원' ? stock.currencySymbol : '';
  return '${negative ? '-' : ''}$prefix$amount$suffix';
}

String _formatRefreshTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

String _trimTrailingZeros(String value) {
  var trimmed = value;
  while (trimmed.endsWith('0')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
