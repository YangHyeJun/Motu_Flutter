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

class _StocksScreenState extends ConsumerState<StocksScreen> {
  static const _pageSize = 30;

  late final KisRealtimeService _realtimeService;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  String _selectedMarket = 'domestic';
  String _selectedCategory = 'tradeAmount';
  String _searchQuery = '';
  int _visibleCount = _pageSize;
  bool _isRefreshing = false;
  DateTime _lastRefreshTime = DateTime.now();
  String? _errorMessage;
  KisRealtimeConnectionState _connectionState = const KisRealtimeConnectionState(
    status: KisRealtimeConnectionStatus.disconnected,
  );
  Set<String> _subscribedDomesticCodes = const <String>{};
  final Map<String, RealtimeDomesticPrice> _liveDomesticPrices = <String, RealtimeDomesticPrice>{};

  @override
  void initState() {
    super.initState();
    _realtimeService = KisRealtimeService(ref.read(kisApiClientProvider));
    _realtimeSubscription = _realtimeService.stream.listen((snapshot) {
      if (!mounted) {
        return;
      }
      setState(() {
        _liveDomesticPrices
          ..clear()
          ..addAll(snapshot.domesticStockPrices);
      });
    });
    _connectionSubscription = _realtimeService.connectionStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionState = state;
      });
    });
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _connectionSubscription?.cancel();
    _realtimeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (market: _selectedMarket, category: _selectedCategory);
    final stocksAsync = ref.watch(marketStocksProvider(query));
    final trimmedSearchQuery = _searchQuery.trim();
    final searchResultsAsync = trimmedSearchQuery.isEmpty
        ? null
        : ref.watch(stockSearchProvider(trimmedSearchQuery));

    Future<void> refresh() async {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
      if (trimmedSearchQuery.isNotEmpty) {
        try {
          ref.invalidate(stockSearchProvider(trimmedSearchQuery));
          await ref.read(stockSearchProvider(trimmedSearchQuery).future);
          setState(() {
            _lastRefreshTime = DateTime.now();
          });
        } catch (_) {
          setState(() {
            _errorMessage = '검색 결과를 다시 불러오지 못했습니다.';
          });
        } finally {
          setState(() {
            _isRefreshing = false;
          });
        }
        return;
      }

      try {
        ref.invalidate(marketStocksProvider(query));
        await ref.read(marketStocksProvider(query).future);
        setState(() {
          _lastRefreshTime = DateTime.now();
        });
      } catch (_) {
        setState(() {
          _errorMessage = '주식 목록을 다시 불러오지 못했습니다.';
        });
      } finally {
        setState(() {
          _isRefreshing = false;
        });
      }
    }

    final totalVisibleSourceCount = trimmedSearchQuery.isNotEmpty
        ? (searchResultsAsync?.valueOrNull?.length ?? 0)
        : (stocksAsync.valueOrNull?.length ?? 0);
    final visibleRealtimeSource = trimmedSearchQuery.isNotEmpty
        ? _sliceVisible(searchResultsAsync?.valueOrNull ?? const <RankingStock>[])
        : _sliceVisible(stocksAsync.valueOrNull ?? const <RankingStock>[]);
    final liveVisibleStocks = _applyRealtimeStocks(visibleRealtimeSource);
    _scheduleRealtimeSubscription(liveVisibleStocks);
    final hasDomesticRealtimeTarget = liveVisibleStocks.any(
      (stock) => stock.marketType == StockMarketType.domestic,
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 200) {
              _loadMore(totalVisibleSourceCount);
            }
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
              child: TextField(
                onChanged: (value) => setState(() {
                  _searchQuery = value;
                  _visibleCount = _pageSize;
                }),
                decoration: InputDecoration(
                  hintText: '국내/미국 종목명 또는 종목코드 검색',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: trimmedSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _visibleCount = _pageSize;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F7F8),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      const Expanded(child: SectionHeader(title: '시장 카테고리')),
                      _StocksRefreshStatus(
                        isRefreshing: _isRefreshing,
                        lastRefreshTime: _lastRefreshTime,
                        onRefresh: refresh,
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
                        selected: _selectedMarket == 'all',
                        onTap: () => _updateMarket('all'),
                      ),
                      _CategoryChip(
                        label: '국내',
                        selected: _selectedMarket == 'domestic',
                        onTap: () => _updateMarket('domestic'),
                      ),
                      _CategoryChip(
                        label: '해외',
                        selected: _selectedMarket == 'overseas',
                        onTap: () => _updateMarket('overseas'),
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
                        selected: _selectedCategory == 'tradeAmount',
                        onTap: () => _updateCategory('tradeAmount'),
                      ),
                      _CategoryChip(
                        label: '거래량',
                        selected: _selectedCategory == 'volume',
                        onTap: () => _updateCategory('volume'),
                      ),
                      _CategoryChip(
                        label: '등락률',
                        selected: _selectedCategory == 'changeRate',
                        onTap: () => _updateCategory('changeRate'),
                      ),
                      _CategoryChip(
                        label: '시가총액',
                        selected: _selectedCategory == 'marketCap',
                        onTap: () => _updateCategory('marketCap'),
                      ),
                    ],
                  ),
                  if (_selectedMarket == 'overseas' || _selectedMarket == 'all') ...[
                    const SizedBox(height: 12),
                    Text(
                      _selectedMarket == 'all'
                          ? '전체 목록에는 현재 국내와 미국(나스닥·뉴욕·아멕스) 종목이 함께 표시됩니다.'
                          : '해외 목록은 현재 미국(나스닥·뉴욕·아멕스) 종목을 함께 표시합니다.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (hasDomesticRealtimeTarget &&
                      _connectionState.status != KisRealtimeConnectionStatus.connected) ...[
                    const SizedBox(height: 12),
                    _StocksRealtimeBanner(
                      connectionState: _connectionState,
                      onRetry: () => _syncRealtimeSubscription(liveVisibleStocks),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.negative,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (trimmedSearchQuery.isNotEmpty)
              searchResultsAsync!.when(
                data: (stocks) => _StocksList(
                  stocks: _applyRealtimeStocks(_sliceVisible(stocks)),
                  title: '검색 결과',
                  emptyMessage: '검색 결과가 없습니다.',
                  totalCount: stocks.length,
                  selectedMarket: 'all',
                  lastRefreshTime: _lastRefreshTime,
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
                        onPressed: refresh,
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
                  stocks: _applyRealtimeStocks(_sliceVisible(stocks)),
                  title:
                      '${_marketTitle(_selectedMarket)} · ${_categoryTitle(_selectedCategory)}',
                  emptyMessage: '표시할 종목이 없습니다.',
                  totalCount: stocks.length,
                  selectedMarket: _selectedMarket,
                  lastRefreshTime: _lastRefreshTime,
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
                        onPressed: refresh,
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
    );
  }

  void _updateMarket(String market) {
    setState(() {
      _selectedMarket = market;
      _visibleCount = _pageSize;
    });
  }

  void _updateCategory(String category) {
    setState(() {
      _selectedCategory = category;
      _visibleCount = _pageSize;
    });
  }

  void _loadMore(int totalCount) {
    if (totalCount <= _visibleCount) {
      return;
    }

    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, totalCount);
    });
  }

  List<RankingStock> _sliceVisible(List<RankingStock> stocks) {
    final end = _visibleCount.clamp(0, stocks.length);
    return stocks.take(end).toList(growable: false);
  }

  List<RankingStock> _applyRealtimeStocks(List<RankingStock> stocks) {
    return stocks.map((stock) {
      if (stock.marketType != StockMarketType.domestic) {
        return stock;
      }

      final live = _liveDomesticPrices[stock.code];
      if (live == null) {
        return stock;
      }

      return RankingStock(
        rank: stock.rank,
        name: stock.name,
        code: stock.code,
        price: live.currentPrice,
        changeRate: live.changeRate,
        extraLabel: stock.extraLabel,
        extraValue: stock.extraValue,
        isPositive: live.isPositive,
        marketType: stock.marketType,
        exchangeCode: stock.exchangeCode,
        productTypeCode: stock.productTypeCode,
        marketLabel: stock.marketLabel,
        currencySymbol: stock.currencySymbol,
        priceDecimals: stock.priceDecimals,
      );
    }).toList(growable: false);
  }

  void _scheduleRealtimeSubscription(List<RankingStock> visibleStocks) {
    final domesticCodes = visibleStocks
        .where((stock) => stock.marketType == StockMarketType.domestic)
        .map((stock) => stock.code)
        .toSet();

    if (_sameCodes(_subscribedDomesticCodes, domesticCodes)) {
      return;
    }

    _subscribedDomesticCodes = domesticCodes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncRealtimeSubscription(visibleStocks);
    });
  }

  Future<void> _syncRealtimeSubscription(List<RankingStock> visibleStocks) async {
    final domesticCodes = visibleStocks
        .where((stock) => stock.marketType == StockMarketType.domestic)
        .map((stock) => stock.code);

    if (domesticCodes.isEmpty) {
      await _realtimeService.disconnect(clearSnapshot: false);
      return;
    }

    await _realtimeService.connect(
      domesticCodes: domesticCodes,
      includeKospi: false,
    );
  }

  bool _sameCodes(Set<String> current, Set<String> next) {
    if (current.length != next.length) {
      return false;
    }

    for (final code in current) {
      if (!next.contains(code)) {
        return false;
      }
    }
    return true;
  }

  String _marketTitle(String market) {
    switch (market) {
      case 'all':
        return '전체 주식';
      case 'overseas':
        return '해외 주식';
      case 'domestic':
      default:
        return '국내 주식';
    }
  }

  String _categoryTitle(String category) {
    switch (category) {
      case 'volume':
        return '거래량';
      case 'changeRate':
        return '등락률';
      case 'marketCap':
        return '시가총액';
      case 'tradeAmount':
      default:
        return '실시간 거래대금';
    }
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
          ...stocks.map(
            (stock) => InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StockDetailScreen.fromRanking(stock: stock),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${stock.rank}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stock.name, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            selectedMarket == 'all'
                                ? '${stock.marketLabel} · ${stock.code}'
                                : stock.code,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatStockPrice(stock),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        PercentageText(
                          value: '${stock.changeRate.abs().toStringAsFixed(2)}%',
                          isPositive: stock.isPositive,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stock.extraLabel} ${stock.extraValue}',
                          style: Theme.of(context).textTheme.bodySmall,
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.accentSoft,
      side: BorderSide(
        color: selected ? AppColors.accent : AppColors.border,
      ),
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
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
    final message = switch (connectionState.status) {
      KisRealtimeConnectionStatus.connecting => '주식 목록 실시간 연결 중입니다.',
      KisRealtimeConnectionStatus.failed => connectionState.errorMessage ?? '실시간 연결이 끊어졌습니다.',
      KisRealtimeConnectionStatus.disconnected => '실시간 연결이 끊어졌습니다.',
      KisRealtimeConnectionStatus.connected => '실시간 연결 중',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3D3A1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_tethering_error_rounded, color: Color(0xFFC27A11), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF8F5B0D),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: connectionState.status == KisRealtimeConnectionStatus.connecting
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
  final negative = stock.price < 0;
  final scale = _pow10(stock.priceDecimals);
  final absolute = stock.price.abs();
  final whole = stock.priceDecimals == 0 ? absolute : absolute ~/ scale;
  final fraction = stock.priceDecimals == 0
      ? ''
      : (absolute % scale).toString().padLeft(stock.priceDecimals, '0');
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
