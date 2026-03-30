import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/kis_realtime_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ranking_stock.dart';
import '../../models/stock_market_type.dart';
import '../../providers/api_provider.dart';
import '../widgets/common_widgets.dart';
import 'detail_screens.dart';

class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen>
    with WidgetsBindingObserver {
  static const _subscriptionOwnerId = 'stocks_screen';

  late final KisRealtimeService _realtimeService;
  late final TextEditingController _searchController;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  String _visibleRealtimeSignature = '';
  List<RankingStock> _latestVisibleRealtimeStocks = const <RankingStock>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();
    _searchController.addListener(() {
      ref
          .read(stocksScreenViewModelProvider.notifier)
          .updateSearchQuery(_searchController.text);
    });
    _realtimeService = ref.read(kisRealtimeServiceProvider);
    ref
        .read(stocksScreenViewModelProvider.notifier)
        .applyRealtimeSnapshot(_realtimeService.snapshot);
    ref
        .read(stocksScreenViewModelProvider.notifier)
        .updateConnectionState(_realtimeService.connectionState);
    _realtimeSubscription = _realtimeService.stream.listen((snapshot) {
      ref
          .read(stocksScreenViewModelProvider.notifier)
          .applyRealtimeSnapshot(snapshot);
    });
    _connectionSubscription = _realtimeService.connectionStateStream.listen((
      state,
    ) {
      final previousStatus = ref
          .read(stocksScreenViewModelProvider)
          .connectionState
          .status;
      ref
          .read(stocksScreenViewModelProvider.notifier)
          .updateConnectionState(state);
      if (state.status == KisRealtimeConnectionStatus.connected &&
          previousStatus != KisRealtimeConnectionStatus.connected &&
          _latestVisibleRealtimeStocks.isNotEmpty) {
        unawaited(
          ref
              .read(stocksScreenViewModelProvider.notifier)
              .handleVisibleStocksChanged(
                ownerId: _subscriptionOwnerId,
                visibleStocks: _latestVisibleRealtimeStocks,
                forceQuoteRefresh: true,
              ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _realtimeSubscription?.cancel();
    _connectionSubscription?.cancel();
    unawaited(
      ref
          .read(stocksScreenViewModelProvider.notifier)
          .clearRealtimeSubscription(_subscriptionOwnerId),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final viewModel = ref.read(stocksScreenViewModelProvider.notifier);
      final viewState = ref.read(stocksScreenViewModelProvider);
      final query = (
        market: viewState.selectedMarket,
        category: viewState.selectedCategory,
      );
      final trimmedSearchQuery = viewState.searchQuery.trim();
      final visibleStocks = trimmedSearchQuery.isNotEmpty
          ? viewModel.sliceVisibleStocks(
              ref.read(stockSearchProvider(trimmedSearchQuery)).valueOrNull ??
                  const <RankingStock>[],
              visibleCount: viewState.visibleCount,
            )
          : viewModel.sliceVisibleStocks(
              ref.read(marketStocksProvider(query)).valueOrNull ??
                  const <RankingStock>[],
              visibleCount: viewState.visibleCount,
            );
      if (visibleStocks.isNotEmpty) {
        unawaited(
          viewModel.handleVisibleStocksChanged(
            ownerId: _subscriptionOwnerId,
            visibleStocks: visibleStocks,
            forceQuoteRefresh: true,
          ),
        );
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(stocksScreenViewModelProvider);
    final viewModel = ref.read(stocksScreenViewModelProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = (
      market: viewState.selectedMarket,
      category: viewState.selectedCategory,
    );
    final stocksAsync = ref.watch(marketStocksProvider(query));
    final trimmedSearchQuery = viewState.searchQuery.trim();
    final exchangeRate = ref.watch(usdKrwRateProvider).valueOrNull;
    final searchResultsAsync = trimmedSearchQuery.isEmpty
        ? null
        : ref.watch(stockSearchProvider(trimmedSearchQuery));

    final totalVisibleSourceCount = trimmedSearchQuery.isNotEmpty
        ? (searchResultsAsync?.valueOrNull?.length ?? 0)
        : (stocksAsync.valueOrNull?.length ?? 0);
    final visibleRealtimeSource = trimmedSearchQuery.isNotEmpty
        ? viewModel.sliceVisibleStocks(
            searchResultsAsync?.valueOrNull ?? const <RankingStock>[],
            visibleCount: viewState.visibleCount,
          )
        : viewModel.sliceVisibleStocks(
            stocksAsync.valueOrNull ?? const <RankingStock>[],
            visibleCount: viewState.visibleCount,
          );
    final liveVisibleStocks = viewModel.applyRealtimeStocks(
      visibleRealtimeSource,
      liveDomesticPrices: viewState.liveDomesticPrices,
      liveOverseasPrices: viewState.liveOverseasPrices,
      liveQuoteStocks: viewState.liveQuoteStocks,
    );
    final displayVisibleStocks = viewModel.applyDisplayCurrency(
      liveVisibleStocks,
      showKrwForOverseas: viewState.showKrwForOverseas,
      exchangeRate: exchangeRate,
    );
    _latestVisibleRealtimeStocks = liveVisibleStocks;
    _scheduleRealtimeSubscription(liveVisibleStocks);
    final hasDomesticRealtimeTarget = liveVisibleStocks.any(
      (stock) => stock.marketType == StockMarketType.domestic,
    );
    final hasOverseasTarget = liveVisibleStocks.any(
      (stock) => stock.marketType == StockMarketType.overseas,
    );

    return SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissKeyboard,
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
                  child: TextField(
                    controller: _searchController,
                    onTapOutside: (_) => _dismissKeyboard(),
                    decoration: InputDecoration(
                      hintText: '국내/미국 종목명 또는 종목코드 검색',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: trimmedSearchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close),
                            ),
                      filled: true,
                      fillColor: isDark
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
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: SectionHeader(title: '시장 카테고리'),
                          ),
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
                            selected:
                                viewState.selectedCategory == 'tradeAmount',
                            onTap: () =>
                                viewModel.updateCategory('tradeAmount'),
                          ),
                          _CategoryChip(
                            label: '거래량',
                            selected: viewState.selectedCategory == 'volume',
                            onTap: () => viewModel.updateCategory('volume'),
                          ),
                          _CategoryChip(
                            label: '등락률',
                            selected:
                                viewState.selectedCategory == 'changeRate',
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
                          onRetry: () => viewModel.handleVisibleStocksChanged(
                            ownerId: _subscriptionOwnerId,
                            visibleStocks: liveVisibleStocks,
                            forceQuoteRefresh: true,
                          ),
                        ),
                      ],
                      if (viewState.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          viewState.errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.negative),
                        ),
                      ],
                    ],
                  ),
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
                    error: (_, _) => AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: '검색 결과'),
                          const SizedBox(height: 12),
                          Text(
                            '검색 결과를 불러오지 못했습니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: viewModel.refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('재시도'),
                          ),
                        ],
                      ),
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
                    error: (_, _) => AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: '주식 목록'),
                          const SizedBox(height: 12),
                          Text(
                            '주식 목록을 불러오지 못했습니다.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: viewModel.refresh,
                            icon: const Icon(Icons.refresh),
                            label: const Text('재시도'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

  void _scheduleRealtimeSubscription(List<RankingStock> visibleStocks) {
    final nextSignature = _stocksRealtimeSignature(visibleStocks);
    if (_visibleRealtimeSignature == nextSignature) {
      return;
    }
    _visibleRealtimeSignature = nextSignature;
    final viewModel = ref.read(stocksScreenViewModelProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        viewModel.handleVisibleStocksChanged(
          ownerId: _subscriptionOwnerId,
          visibleStocks: visibleStocks,
          forceQuoteRefresh: true,
        ),
      );
    });
  }

  String _stocksRealtimeSignature(List<RankingStock> visibleStocks) {
    return visibleStocks
        .map((stock) {
          if (stock.marketType == StockMarketType.domestic) {
            return 'D:${stock.code}';
          }
          return 'O:${(stock.exchangeCode ?? 'NAS').toUpperCase()}:${stock.code.toUpperCase()}';
        })
        .join('|');
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
                    ? const Color(0xFFFFE0A8)
                    : const Color(0xFF8F5B0D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!isMarketClosed)
            TextButton(
              onPressed:
                  connectionState.status ==
                      KisRealtimeConnectionStatus.connecting
                  ? null
                  : onRetry,
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
  final whole = decimals == 0 ? absolute : absolute ~/ scale;
  final rawFraction = decimals == 0
      ? ''
      : (absolute % scale).toString().padLeft(decimals, '0');
  final fraction = stock.currencySymbol == r'$'
      ? _trimTrailingZeros(rawFraction)
      : rawFraction;
  final numberText = _formatPrice(whole);
  final amount = fraction.isEmpty ? numberText : '$numberText.$fraction';
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
  var end = value.length;
  while (end > 0 && value[end - 1] == '0') {
    end--;
  }
  return value.substring(0, end);
}
