import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/market/market_session.dart';
import '../../core/network/kis_api_exception.dart';
import '../../core/network/kis_realtime_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/api_provider.dart';
import '../../providers/home_provider.dart';
import '../../viewmodels/detail_action_view_model.dart';
import 'more_screen.dart';
import '../widgets/chart_widgets.dart';
import '../widgets/common_widgets.dart';

part 'detail_screen_supplemental.dart';
part 'detail_screen_shared.dart';

enum _OverseasDisplayCurrency { usd, krw }

enum _TradeMode { buy, sell }

class HoldingsDetailScreen extends ConsumerStatefulWidget {
  const HoldingsDetailScreen({
    super.key,
    required this.holdings,
    this.title = '국내 보유주식',
  });

  final List<HoldingStock> holdings;
  final String title;

  @override
  ConsumerState<HoldingsDetailScreen> createState() =>
      _HoldingsDetailScreenState();
}

class _HoldingsDetailScreenState extends ConsumerState<HoldingsDetailScreen> {
  bool _showKrw = true;
  bool _showInfoBanner = true;
  late DateTime _currentTime;
  Timer? _marketSessionTimer;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _marketSessionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _marketSessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasOverseas = widget.holdings.any(
      (stock) => stock.marketType == StockMarketType.overseas,
    );
    final exchangeRate = hasOverseas
        ? ref.watch(usdKrwRateProvider).valueOrNull
        : null;
    final openHoldings = <HoldingStock>[];
    final closedHoldings = <HoldingStock>[];
    for (final holding in widget.holdings) {
      if (holdingMarketSessionStatus(holding, _currentTime) ==
          HoldingMarketSessionStatus.open) {
        openHoldings.add(holding);
      } else {
        closedHoldings.add(holding);
      }
    }
    final sections = [
      if (openHoldings.isNotEmpty)
        ('현재 정규장 보유주식', List<HoldingStock>.unmodifiable(openHoldings)),
      if (closedHoldings.isNotEmpty)
        ('정규장 아님 보유주식', List<HoldingStock>.unmodifiable(closedHoldings)),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.title),
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
            if (_showInfoBanner)
              InfoBanner(
                message: '데이터는 한국투자증권 API 기준입니다.',
                onDismiss: () {
                  setState(() {
                    _showInfoBanner = false;
                  });
                },
              ),
            if (hasOverseas) ...[
              const SizedBox(height: 12),
              _OverseasHoldingsCurrencyToggle(
                showKrw: _showKrw,
                exchangeRate: exchangeRate,
                onChanged: (value) {
                  setState(() {
                    _showKrw = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            for (
              var sectionIndex = 0;
              sectionIndex < sections.length;
              sectionIndex++
            ) ...[
              if (sectionIndex > 0) const SizedBox(height: 18),
              Text(
                sections[sectionIndex].$1,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...sections[sectionIndex].$2.map(
                (stock) => InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          StockDetailScreen.fromHolding(stock: stock),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
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
                                '내 평균 ${_formatHoldingAmount(stock.buyPrice, stock: stock, showKrw: _showKrw, exchangeRate: exchangeRate)}',
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
                            value: _formatHoldingAmount(
                              stock.currentPrice,
                              stock: stock,
                              showKrw: _showKrw,
                              exchangeRate: exchangeRate,
                            ),
                            isPositive: stock.isPositive,
                            subtitle:
                                '${stock.profitRate > 0 ? '+' : ''}${stock.profitRate.toStringAsFixed(1)}%',
                          ),
                        ),
                        Expanded(
                          child: _PriceColumn(
                            title: '평가금',
                            value: _formatHoldingAmount(
                              stock.evaluationAmount,
                              stock: stock,
                              showKrw: _showKrw,
                              exchangeRate: exchangeRate,
                            ),
                            isPositive: stock.isPositive,
                            subtitle:
                                '${stock.profitAmount > 0 ? '+' : ''}${_formatHoldingAmount(stock.profitAmount.abs(), stock: stock, showKrw: _showKrw, exchangeRate: exchangeRate)} (${stock.profitRate.toStringAsFixed(1)}%)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MarketIndexDetailScreen extends ConsumerStatefulWidget {
  MarketIndexDetailScreen({super.key, required this.index})
    : name = index.name,
      currentValue = index.value,
      changeRate = 0,
      isPositive = index.isPositive;

  final MarketIndex index;
  final String name;
  final String currentValue;
  final double changeRate;
  final bool isPositive;

  @override
  ConsumerState<MarketIndexDetailScreen> createState() =>
      _MarketIndexDetailScreenState();
}

class _MarketIndexDetailScreenState
    extends ConsumerState<MarketIndexDetailScreen> {
  StockChartPeriod _selectedPeriod = StockChartPeriod.oneDay;
  _OverseasDisplayCurrency _displayCurrency = _OverseasDisplayCurrency.usd;
  final String _subscriptionOwnerId =
      'market_index_detail_${identityHashCode(Object())}';
  late final KisRealtimeService _realtimeService;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  int? _realtimeValue;
  double? _realtimeRate;
  KisRealtimeConnectionState _connectionState =
      const KisRealtimeConnectionState(
        status: KisRealtimeConnectionStatus.disconnected,
      );

  @override
  void initState() {
    super.initState();
    _realtimeService = ref.read(kisRealtimeServiceProvider);
    _connectionState = _realtimeService.connectionState;
    _handleRealtimeSnapshot(_realtimeService.snapshot);
    _realtimeSubscription = _realtimeService.stream.listen(
      _handleRealtimeSnapshot,
    );
    _connectionSubscription = _realtimeService.connectionStateStream.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionState = state;
      });
    });
    _syncRealtimeSubscription();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _connectionSubscription?.cancel();
    unawaited(_realtimeService.clearSubscription(_subscriptionOwnerId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOverseasIndex = widget.name == '나스닥';
    final supportsRealtimeIndex = widget.name == '코스피';
    final query = (name: widget.name, period: _selectedPeriod);
    final detailAsync = ref.watch(marketIndexDetailProvider(query));
    final exchangeRate = isOverseasIndex
        ? ref.watch(usdKrwRateProvider).valueOrNull
        : null;
    final detail = detailAsync.valueOrNull;
    final baseDisplayValue = _realtimeValue != null
        ? _formatCompactNumber(_realtimeValue!)
        : detail?.currentValue ?? widget.currentValue;
    final displayRate =
        _realtimeRate ??
        detail?.changeRate ??
        _parseSignedPercent(widget.index.changeRate);
    final displayPositive = detail?.isPositive ?? widget.isPositive;
    final baseChartEntries = _mergeRealtimeChartEntries(
      entries: detail?.chartEntries ?? const <StockChartEntry>[],
      realtimePrice: _realtimeValue,
      realtimeVolume: null,
      applyRealtime:
          _selectedPeriod == StockChartPeriod.oneDay && widget.name == '코스피',
    );
    final useKrw =
        isOverseasIndex &&
        _displayCurrency == _OverseasDisplayCurrency.krw &&
        exchangeRate != null &&
        exchangeRate > 0;
    final displayValue = useKrw
        ? _formatConvertedIndexValue(baseDisplayValue, exchangeRate)
        : baseDisplayValue;
    final chartEntries = useKrw
        ? _convertIndexChartEntriesToKrw(baseChartEntries, exchangeRate)
        : baseChartEntries;
    final chartReferencePrice = chartEntries.isEmpty
        ? null
        : _referencePriceFromChangeRate(
            currentPrice: chartEntries.last.closePrice,
            changeRate: displayRate,
          );
    final range = _chartRange(chartEntries);
    final changeAmountText = useKrw && detail != null
        ? _formatConvertedSignedIndexValue(detail.changeAmount, exchangeRate)
        : (detail?.changeAmount ?? _formatSignedPercent(displayRate));
    final openValue = useKrw && detail != null
        ? _formatConvertedIndexValue(detail.openValue, exchangeRate)
        : detail?.openValue ?? '-';
    final highValue = useKrw && detail != null
        ? _formatConvertedIndexValue(detail.highValue, exchangeRate)
        : detail?.highValue ?? '-';
    final lowValue = useKrw && detail != null
        ? _formatConvertedIndexValue(detail.lowValue, exchangeRate)
        : detail?.lowValue ?? '-';

    Future<void> refreshDetail() async {
      setState(() {
        _realtimeValue = null;
        _realtimeRate = null;
      });
      await ref
          .read(detailActionViewModelProvider)
          .refreshMarketIndexDetail(
            reload: () async {
              ref.invalidate(marketIndexDetailProvider(query));
              await ref.read(marketIndexDetailProvider(query).future);
            },
          );
      await _syncRealtimeSubscription();
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(onPressed: refreshDetail, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshDetail,
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
                      widget.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (isOverseasIndex) ...[
                      const SizedBox(height: 12),
                      _OverseasCurrencyToggle(
                        selected: _displayCurrency,
                        exchangeRate: exchangeRate,
                        onSelected: (value) {
                          setState(() {
                            _displayCurrency = value;
                          });
                        },
                      ),
                    ],
                    if (isOverseasIndex &&
                        exchangeRate != null &&
                        exchangeRate > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '적용 환율 1달러 = ${_currency(exchangeRate.round())}원',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      displayValue,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Row(
                      children: [
                        Text(
                          '전일 대비 ',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        PercentageText(
                          value:
                              '$changeAmountText (${displayRate.abs().toStringAsFixed(2)}%)',
                          isPositive: displayPositive,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (supportsRealtimeIndex &&
                        _selectedPeriod == StockChartPeriod.oneDay &&
                        _connectionState.status !=
                            KisRealtimeConnectionStatus.connected) ...[
                      _RealtimeConnectionBanner(
                        connectionState: _connectionState,
                        onRetry: _syncRealtimeSubscription,
                      ),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      height: 300,
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '차트',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _ChartSection(
                                chartEntries: chartEntries,
                                isLoading:
                                    detailAsync.isLoading && detail == null,
                                errorText: detailAsync.hasError
                                    ? '지수 차트 데이터를 불러오지 못했습니다.'
                                    : null,
                                valueSuffix: '',
                                valueFormatter: (value) => useKrw
                                    ? '${_currency(value)}원'
                                    : _formatCompactNumber(value),
                                referencePrice: chartReferencePrice,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PeriodRow(
                      selectedPeriod: _selectedPeriod,
                      onSelect: (period) async {
                        setState(() {
                          _selectedPeriod = period;
                          _realtimeValue = null;
                          _realtimeRate = null;
                        });
                        await _syncRealtimeSubscription();
                      },
                    ),
                    const SizedBox(height: 18),
                    _ChartRangeSummary(
                      highLabel: '최고',
                      highValue: range == null
                          ? '-'
                          : (useKrw
                                ? '${_currency(range.$1)}원'
                                : _formatCompactNumber(range.$1)),
                      lowLabel: '최저',
                      lowValue: range == null
                          ? '-'
                          : (useKrw
                                ? '${_currency(range.$2)}원'
                                : _formatCompactNumber(range.$2)),
                    ),
                    const SizedBox(height: 18),
                    _IndexMetricRow(
                      openValue: openValue,
                      highValue: highValue,
                      lowValue: lowValue,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 180,
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: _VolumeSection(
                          entries: chartEntries,
                          volume: detail?.volume ?? 0,
                          isLoading: detailAsync.isLoading && detail == null,
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

  Future<void> _syncRealtimeSubscription() async {
    _realtimeValue = null;
    _realtimeRate = null;
    await ref
        .read(detailActionViewModelProvider)
        .syncStockRealtimeSubscription(
          ownerId: _subscriptionOwnerId,
          marketType: StockMarketType.domestic,
          code: '',
          includeOrderBook: false,
          active:
              _selectedPeriod == StockChartPeriod.oneDay &&
              widget.name == '코스피',
          includeKospi: widget.name == '코스피',
        );
  }

  void _handleRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    if (!mounted ||
        widget.name != '코스피' ||
        _selectedPeriod != StockChartPeriod.oneDay) {
      return;
    }

    final value = snapshot.kospiValue?.replaceAll(',', '');
    final parsed = double.tryParse(value ?? '');
    if (parsed == null) {
      return;
    }

    setState(() {
      _realtimeValue = parsed.round();
      _realtimeRate = snapshot.kospiChangeRate;
    });
  }
}

class StockDetailScreen extends ConsumerStatefulWidget {
  StockDetailScreen.fromHolding({super.key, required HoldingStock stock})
    : name = stock.name,
      code = stock.code,
      marketType = stock.marketType,
      exchangeCode = stock.exchangeCode,
      priceDecimals = stock.priceDecimals,
      currencySymbol = stock.currencySymbol,
      currentPrice = stock.currentPrice,
      changeRate = stock.profitRate,
      isPositive = stock.isPositive,
      averagePrice = stock.buyPrice,
      quantity = stock.quantity,
      initialHolding = stock;

  StockDetailScreen.fromRanking({super.key, required RankingStock stock})
    : name = stock.name,
      code = stock.code,
      marketType = stock.marketType,
      exchangeCode = stock.exchangeCode,
      priceDecimals = stock.priceDecimals,
      currencySymbol = stock.currencySymbol,
      currentPrice = stock.price,
      changeRate = stock.changeRate,
      isPositive = stock.isPositive,
      averagePrice = null,
      quantity = null,
      initialHolding = null;

  final String name;
  final String code;
  final StockMarketType marketType;
  final String? exchangeCode;
  final int priceDecimals;
  final String currencySymbol;
  final int currentPrice;
  final double changeRate;
  final bool isPositive;
  final int? averagePrice;
  final int? quantity;
  final HoldingStock? initialHolding;

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen>
    with WidgetsBindingObserver {
  StockChartPeriod _selectedPeriod = StockChartPeriod.oneDay;
  _OverseasDisplayCurrency _displayCurrency = _OverseasDisplayCurrency.usd;
  final String _subscriptionOwnerId =
      'stock_detail_${identityHashCode(Object())}';
  late final KisRealtimeService _realtimeService;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  int? _realtimePrice;
  double? _realtimeRate;
  int? _realtimeVolume;
  int? _realtimeOpenPrice;
  int? _realtimeHighPrice;
  int? _realtimeLowPrice;
  double? _realtimeExchangeRate;
  List<StockOrderBookLevel> _liveOrderBook = const <StockOrderBookLevel>[];
  KisRealtimeConnectionState _connectionState =
      const KisRealtimeConnectionState(
        status: KisRealtimeConnectionStatus.disconnected,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtimeService = ref.read(kisRealtimeServiceProvider);
    _connectionState = _realtimeService.connectionState;
    _handleRealtimeSnapshot(_realtimeService.snapshot);
    _realtimeSubscription = _realtimeService.stream.listen(
      _handleRealtimeSnapshot,
    );
    _connectionSubscription = _realtimeService.connectionStateStream.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionState = state;
      });
    });
    _configureLiveUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    _connectionSubscription?.cancel();
    unawaited(_realtimeService.clearSubscription(_subscriptionOwnerId));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_syncRealtimeSubscription());
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final query = (
      code: widget.code,
      name: widget.name,
      period: _selectedPeriod,
      marketType: widget.marketType,
      exchangeCode: widget.exchangeCode,
    );
    final detailAsync = ref.watch(stockDetailProvider(query));
    final detail = detailAsync.valueOrNull;
    final favoriteStocks = ref.watch(favoriteStocksProvider);
    final domesticHoldingAsync = widget.marketType == StockMarketType.domestic
        ? ref.watch(domesticHoldingProvider(widget.code))
        : const AsyncValue<HoldingStock?>.data(null);
    final domesticHolding = domesticHoldingAsync.valueOrNull;
    final portfolioHolding =
        [...homeState.domesticHoldings, ...homeState.usHoldings]
            .where(
              (holding) =>
                  holding.marketType == widget.marketType &&
                  holding.code == widget.code &&
                  (widget.marketType == StockMarketType.domestic ||
                      (holding.exchangeCode ?? '').toUpperCase() ==
                          (widget.exchangeCode ?? '').toUpperCase()),
            )
            .firstOrNull;
    final effectiveHolding =
        domesticHolding ?? portfolioHolding ?? widget.initialHolding;
    final effectiveHoldingQuantity =
        effectiveHolding?.quantity ?? widget.quantity ?? 0;
    final effectiveAveragePrice =
        effectiveHolding?.buyPrice ?? widget.averagePrice;
    final basePrice =
        _realtimePrice ?? detail?.currentPrice ?? widget.currentPrice;
    final displayRate =
        _realtimeRate ?? detail?.changeRate ?? widget.changeRate;
    final displayPositive = displayRate >= 0;
    final baseChartEntries = _mergeRealtimeChartEntries(
      entries: detail?.chartEntries ?? const <StockChartEntry>[],
      realtimePrice: _realtimePrice,
      realtimeVolume: _realtimeVolume,
      applyRealtime: _selectedPeriod == StockChartPeriod.oneDay,
    );
    final baseRange = _chartRange(baseChartEntries);
    final baseVolume = _realtimeVolume ?? detail?.volume ?? 0;
    final baseOpenPrice = _realtimeOpenPrice ?? detail?.openPrice ?? 0;
    final baseHighPrice = math.max(
      _realtimeHighPrice ?? detail?.highPrice ?? 0,
      baseRange?.$1 ?? 0,
    );
    final baseLowPrice = detail?.lowPrice == null || detail!.lowPrice == 0
        ? (baseRange?.$2 ?? 0)
        : math.min(
            _realtimeLowPrice ?? detail.lowPrice,
            baseRange?.$2 ?? detail.lowPrice,
          );
    final compareLabel = effectiveAveragePrice == null ? '전일 대비 ' : '내 평균 대비 ';
    final baseCompareAmount = effectiveAveragePrice == null
        ? (basePrice * (displayRate.abs() / 100)).round()
        : (basePrice - effectiveAveragePrice).abs();
    final basePriceDecimals = detail?.priceDecimals ?? widget.priceDecimals;
    final baseCurrencySymbol = detail?.currencySymbol ?? widget.currencySymbol;
    final favoriteStock = FavoriteStock(
      name: widget.name,
      code: widget.code,
      marketType: widget.marketType,
      currentPrice: basePrice,
      changeRate: displayRate,
      isPositive: displayPositive,
      exchangeCode: widget.exchangeCode,
      marketLabel: _favoriteMarketLabel(
        marketType: widget.marketType,
        exchangeCode: widget.exchangeCode,
      ),
      currencySymbol: baseCurrencySymbol,
      priceDecimals: basePriceDecimals,
    );
    final isFavorite = favoriteStocks.any(
      (stock) => stock.key == favoriteStock.key,
    );
    final isOverseas =
        (detail?.marketType ?? widget.marketType) == StockMarketType.overseas;
    final exchangeRate = isOverseas
        ? (_realtimeExchangeRate ??
              ref.watch(usdKrwRateProvider).valueOrNull ??
              detail?.exchangeRate)
        : null;
    final useKrw =
        isOverseas &&
        _displayCurrency == _OverseasDisplayCurrency.krw &&
        exchangeRate != null &&
        exchangeRate > 0;
    final displayPrice = useKrw
        ? _convertForeignPriceToKrw(
            basePrice,
            decimals: basePriceDecimals,
            exchangeRate: exchangeRate,
          )
        : basePrice;
    final chartEntries = useKrw
        ? _convertChartEntriesToKrw(
            baseChartEntries,
            decimals: basePriceDecimals,
            exchangeRate: exchangeRate,
          )
        : baseChartEntries;
    final chartReferencePrice = chartEntries.isEmpty
        ? null
        : _referencePriceFromChangeRate(
            currentPrice: chartEntries.last.closePrice,
            changeRate: displayRate,
          );
    final range = _chartRange(chartEntries);
    final displayVolume = baseVolume;
    final displayOpenPrice = useKrw
        ? _convertForeignPriceToKrw(
            baseOpenPrice,
            decimals: basePriceDecimals,
            exchangeRate: exchangeRate,
          )
        : baseOpenPrice;
    final displayHighPrice = useKrw
        ? _convertForeignPriceToKrw(
            baseHighPrice,
            decimals: basePriceDecimals,
            exchangeRate: exchangeRate,
          )
        : baseHighPrice;
    final displayLowPrice = useKrw
        ? _convertForeignPriceToKrw(
            baseLowPrice,
            decimals: basePriceDecimals,
            exchangeRate: exchangeRate,
          )
        : baseLowPrice;
    final compareAmount = useKrw
        ? _convertForeignPriceToKrw(
            baseCompareAmount,
            decimals: basePriceDecimals,
            exchangeRate: exchangeRate,
          )
        : baseCompareAmount;
    final priceDecimals = useKrw ? 0 : basePriceDecimals;
    final currencySymbol = useKrw ? '원' : baseCurrencySymbol;
    final displayOrderBook = useKrw
        ? _convertOrderBookToKrw(
            (_liveOrderBook.isNotEmpty
                ? _liveOrderBook
                : detail?.orderBook ?? const <StockOrderBookLevel>[]),
            decimals: basePriceDecimals,
            exchangeRate: exchangeRate,
          )
        : (_liveOrderBook.isNotEmpty
              ? _liveOrderBook
              : detail?.orderBook ?? const <StockOrderBookLevel>[]);

    Future<void> refreshDetail() async {
      setState(() {
        _realtimePrice = null;
        _realtimeRate = null;
        _realtimeVolume = null;
        _realtimeOpenPrice = null;
        _realtimeHighPrice = null;
        _realtimeLowPrice = null;
        _realtimeExchangeRate = null;
        _liveOrderBook = const <StockOrderBookLevel>[];
      });
      await ref
          .read(detailActionViewModelProvider)
          .refreshStockDetail(
            reload: () async {
              ref.invalidate(stockDetailProvider(query));
              await ref.read(stockDetailProvider(query).future);
            },
          );
      _configureLiveUpdates();
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(favoriteStocksProvider.notifier).toggle(favoriteStock),
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFavorite
                  ? (Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFFD54F)
                        : const Color(0xFFF4B400))
                  : null,
            ),
          ),
          IconButton(
            onPressed: () => refreshDetail(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshDetail,
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
                      '${widget.name} (${widget.code})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (isOverseas) ...[
                      const SizedBox(height: 12),
                      _OverseasCurrencyToggle(
                        selected: _displayCurrency,
                        exchangeRate: exchangeRate,
                        onSelected: (value) {
                          setState(() {
                            _displayCurrency = value;
                          });
                        },
                      ),
                      if (exchangeRate != null && exchangeRate > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '적용 환율 1달러 = ${_currency(exchangeRate.round())}원',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _formatMoney(
                        displayPrice,
                        currencySymbol: currencySymbol,
                        decimals: priceDecimals,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Row(
                      children: [
                        Text(
                          compareLabel,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        PercentageText(
                          value:
                              '${_formatMoney(compareAmount, currencySymbol: currencySymbol, decimals: priceDecimals)} (${displayRate.abs().toStringAsFixed(2)}%)',
                          isPositive: displayPositive,
                        ),
                        const Spacer(),
                        Text(
                          widget.quantity == null
                              ? '일반 종목 상세 보기'
                              : '보유수량: ${widget.quantity}주',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if (effectiveHolding != null &&
                        effectiveHoldingQuantity > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkBorder
                                  : AppColors.border,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AveragingDownCalculatorScreen(
                                stock: effectiveHolding.copyWith(
                                  currentPrice: basePrice,
                                  exchangeRate: exchangeRate,
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.calculate_outlined),
                          label: const Text('물타기 계산하기'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (_selectedPeriod == StockChartPeriod.oneDay &&
                        _connectionState.status !=
                            KisRealtimeConnectionStatus.connected) ...[
                      _RealtimeConnectionBanner(
                        connectionState: _connectionState,
                        onRetry: _syncRealtimeSubscription,
                      ),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      height: 332,
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '차트',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _ChartSection(
                                chartEntries: chartEntries,
                                isLoading:
                                    detailAsync.isLoading && detail == null,
                                errorText: detailAsync.hasError
                                    ? '차트 데이터를 불러오지 못했습니다.'
                                    : null,
                                valueSuffix: currencySymbol,
                                valueFormatter: (value) => _formatMoney(
                                  value,
                                  currencySymbol: currencySymbol,
                                  decimals: priceDecimals,
                                ),
                                referencePrice: chartReferencePrice,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _PeriodRow(
                      selectedPeriod: _selectedPeriod,
                      onSelect: (period) async {
                        setState(() {
                          _selectedPeriod = period;
                          _realtimePrice = null;
                          _realtimeRate = null;
                          _realtimeVolume = null;
                          _realtimeOpenPrice = null;
                          _realtimeHighPrice = null;
                          _realtimeLowPrice = null;
                        });
                        _configureLiveUpdates();
                      },
                    ),
                    const SizedBox(height: 18),
                    _ChartRangeSummary(
                      highLabel: '최고',
                      highValue: range == null
                          ? '-'
                          : _formatMoney(
                              range.$1,
                              currencySymbol: currencySymbol,
                              decimals: priceDecimals,
                            ),
                      lowLabel: '최저',
                      lowValue: range == null
                          ? '-'
                          : _formatMoney(
                              range.$2,
                              currencySymbol: currencySymbol,
                              decimals: priceDecimals,
                            ),
                    ),
                    const SizedBox(height: 18),
                    _PriceSummaryRow(
                      openPrice: displayOpenPrice,
                      highPrice: displayHighPrice,
                      lowPrice: displayLowPrice,
                      currencySymbol: currencySymbol,
                      priceDecimals: priceDecimals,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 180,
                      child: AppCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: _VolumeSection(
                          entries: chartEntries,
                          volume: displayVolume,
                          isLoading: detailAsync.isLoading && detail == null,
                        ),
                      ),
                    ),
                    if (_liveOrderBook.isNotEmpty ||
                        (detail != null && detail.orderBook.isNotEmpty)) ...[
                      const SizedBox(height: 18),
                      _OrderBookCard(
                        orderBook: displayOrderBook,
                        currencySymbol: currencySymbol,
                        priceDecimals: priceDecimals,
                      ),
                    ],
                    if (detail != null && detail.infoItems.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _InfoGridCard(items: detail.infoItems),
                    ],
                    const Spacer(),
                    const SizedBox(height: 18),
                    if (isOverseas)
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
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => OverseasStockInfoScreen(
                                name: widget.name,
                                code: widget.code,
                                exchangeCode: widget.exchangeCode ?? 'NAS',
                              ),
                            ),
                          ),
                          child: const Text(
                            '해외 종목 정보 보기',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: detail == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => _TradeOrderScreen(
                                          mode: _TradeMode.buy,
                                          stockName: widget.name,
                                          stockCode: widget.code,
                                          initialHoldingQuantity:
                                              effectiveHoldingQuantity,
                                        ),
                                      ),
                                    ),
                              child: const Text(
                                '매수',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF27364A),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  detail == null ||
                                      effectiveHoldingQuantity <= 0
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => _TradeOrderScreen(
                                          mode: _TradeMode.sell,
                                          stockName: widget.name,
                                          stockCode: widget.code,
                                          initialHoldingQuantity:
                                              effectiveHoldingQuantity,
                                        ),
                                      ),
                                    ),
                              child: const Text(
                                '매도',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Future<void> _syncRealtimeSubscription() async {
    await ref
        .read(detailActionViewModelProvider)
        .syncStockRealtimeSubscription(
          ownerId: _subscriptionOwnerId,
          marketType: widget.marketType,
          code: widget.code,
          exchangeCode: widget.exchangeCode,
          includeOrderBook: _selectedPeriod == StockChartPeriod.oneDay,
          active: _selectedPeriod == StockChartPeriod.oneDay,
        );
  }

  void _configureLiveUpdates() {
    unawaited(_syncRealtimeSubscription());

    if (_selectedPeriod != StockChartPeriod.oneDay) {
      if (_liveOrderBook.isNotEmpty) {
        setState(() {
          _liveOrderBook = const <StockOrderBookLevel>[];
        });
      }
      return;
    }
  }

  void _handleRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    if (!mounted || _selectedPeriod != StockChartPeriod.oneDay) {
      return;
    }

    if (widget.marketType == StockMarketType.domestic) {
      final realtime = snapshot.domesticStockPrices[widget.code];
      final orderBook = snapshot.orderBooks['domestic:${widget.code}'];
      if (realtime == null && orderBook == null) {
        return;
      }

      setState(() {
        if (realtime != null) {
          _realtimePrice = realtime.currentPrice;
          _realtimeRate = realtime.changeRate;
          _realtimeVolume = realtime.volume;
          _realtimeOpenPrice = realtime.openPrice;
          _realtimeHighPrice = realtime.highPrice;
          _realtimeLowPrice = realtime.lowPrice;
        }
        if (orderBook != null && orderBook.isNotEmpty) {
          _liveOrderBook = orderBook;
        }
      });
      return;
    }

    final overseasKey =
        '${(widget.exchangeCode ?? 'NAS').toUpperCase()}:${widget.code.toUpperCase()}';
    final realtime = snapshot.overseasStockPrices[overseasKey];
    final orderBook = snapshot.orderBooks['overseas:$overseasKey'];
    if (realtime == null && orderBook == null) {
      return;
    }

    setState(() {
      if (realtime != null) {
        _realtimePrice = realtime.currentPrice;
        _realtimeRate = realtime.changeRate;
        _realtimeVolume = realtime.volume;
        _realtimeOpenPrice = realtime.openPrice;
        _realtimeHighPrice = realtime.highPrice;
        _realtimeLowPrice = realtime.lowPrice;
      }
      if (orderBook != null && orderBook.isNotEmpty) {
        _liveOrderBook = orderBook;
      }
    });
  }
}

String _favoriteMarketLabel({
  required StockMarketType marketType,
  required String? exchangeCode,
}) {
  if (marketType == StockMarketType.domestic) {
    return '국내';
  }

  switch ((exchangeCode ?? 'NAS').toUpperCase()) {
    case 'NYS':
    case 'BAY':
      return '미국 · 뉴욕';
    case 'AMS':
    case 'BAA':
      return '미국 · 아멕스';
    case 'NAS':
    case 'BAQ':
    default:
      return '미국 · 나스닥';
  }
}

class OverseasStockInfoScreen extends ConsumerWidget {
  const OverseasStockInfoScreen({
    super.key,
    required this.name,
    required this.code,
    required this.exchangeCode,
  });

  final String name;
  final String code;
  final String exchangeCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (
      code: code,
      name: name,
      period: StockChartPeriod.oneDay,
      marketType: StockMarketType.overseas,
      exchangeCode: exchangeCode,
    );
    final detailAsync = ref.watch(stockDetailProvider(query));

    Future<void> refresh() async {
      ref.invalidate(stockDetailProvider(query));
      await ref.read(stockDetailProvider(query).future);
    }

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('$name 정보')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: const [
              AppCard(child: Text('해외 종목 정보를 불러오지 못했습니다. 아래로 당겨 다시 시도해주세요.')),
            ],
          ),
        ),
        data: (detail) {
          final basicSection = detail.infoSections
              .where((section) => section.title == '기본 정보')
              .toList(growable: false);
          final detailSections = detail.infoSections
              .where((section) => section.title != '기본 정보')
              .toList(growable: false);

          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'API 정의서 기준으로 제공 가능한 해외 종목 정보를 모두 표시합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: '기본'),
                    Tab(text: '상세'),
                    Tab(text: '호가'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverseasInfoTabContent(
                        onRefresh: refresh,
                        child: basicSection.isEmpty
                            ? const AppCard(child: Text('표시할 기본 정보가 없습니다.'))
                            : Column(
                                children: [
                                  for (final section in basicSection) ...[
                                    _InfoGridCard(
                                      title: section.title,
                                      items: section.items,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ],
                              ),
                      ),
                      _OverseasInfoTabContent(
                        onRefresh: refresh,
                        child: detailSections.isEmpty
                            ? const AppCard(child: Text('표시할 상세 지표가 없습니다.'))
                            : Column(
                                children: [
                                  for (final section in detailSections) ...[
                                    _InfoGridCard(
                                      title: section.title,
                                      items: section.items,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ],
                              ),
                      ),
                      _OverseasInfoTabContent(
                        onRefresh: refresh,
                        child: Column(
                          children: [
                            AppCard(
                              child: Text(
                                exchangeCode == 'NAS' ||
                                        exchangeCode == 'NYS' ||
                                        exchangeCode == 'AMS' ||
                                        exchangeCode == 'BAQ' ||
                                        exchangeCode == 'BAY' ||
                                        exchangeCode == 'BAA'
                                    ? '미국 거래소는 최대 10호가까지 표시합니다.'
                                    : '미국 외 거래소는 API 제공 범위에 따라 1호가 중심으로 표시될 수 있습니다.',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (detail.orderBook.isEmpty)
                              const AppCard(child: Text('표시할 호가 정보가 없습니다.'))
                            else
                              _OrderBookCard(
                                orderBook: detail.orderBook,
                                currencySymbol: detail.currencySymbol,
                                priceDecimals: detail.priceDecimals,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverseasInfoTabContent extends StatelessWidget {
  const _OverseasInfoTabContent({required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [child],
      ),
    );
  }
}

class _TradeOrderScreen extends ConsumerStatefulWidget {
  const _TradeOrderScreen({
    required this.mode,
    required this.stockName,
    required this.stockCode,
    required this.initialHoldingQuantity,
  });

  final _TradeMode mode;
  final String stockName;
  final String stockCode;
  final int initialHoldingQuantity;

  @override
  ConsumerState<_TradeOrderScreen> createState() => _TradeOrderScreenState();
}

class _TradeOrderScreenState extends ConsumerState<_TradeOrderScreen> {
  final String _subscriptionOwnerId =
      'trade_order_${identityHashCode(Object())}';
  late final KisRealtimeService _realtimeService;
  late final TextEditingController _quantityController;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  KisRealtimeConnectionState _connectionState =
      const KisRealtimeConnectionState(
        status: KisRealtimeConnectionStatus.disconnected,
      );
  int? _realtimePrice;
  int? _realtimeOpenPrice;
  int? _realtimeHighPrice;
  int? _realtimeLowPrice;
  int? _realtimeVolume;
  double? _realtimeRate;
  List<StockOrderBookLevel> _liveOrderBook = const <StockOrderBookLevel>[];
  int? _selectedPrice;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
    _quantityController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _realtimeService = ref.read(kisRealtimeServiceProvider);
    _connectionState = _realtimeService.connectionState;
    _handleRealtimeSnapshot(_realtimeService.snapshot);
    _realtimeSubscription = _realtimeService.stream.listen(
      _handleRealtimeSnapshot,
    );
    _connectionSubscription = _realtimeService.connectionStateStream.listen((
      state,
    ) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionState = state;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(detailActionViewModelProvider)
            .syncStockRealtimeSubscription(
              ownerId: _subscriptionOwnerId,
              marketType: StockMarketType.domestic,
              code: widget.stockCode,
              includeOrderBook: true,
              active: true,
            ),
      );
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _realtimeSubscription?.cancel();
    _connectionSubscription?.cancel();
    unawaited(_realtimeService.clearSubscription(_subscriptionOwnerId));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = (
      code: widget.stockCode,
      name: widget.stockName,
      period: StockChartPeriod.oneDay,
      marketType: StockMarketType.domestic,
      exchangeCode: null,
    );
    final detailAsync = ref.watch(stockDetailProvider(query));
    final detail = detailAsync.valueOrNull;
    final holdingAsync = ref.watch(domesticHoldingProvider(widget.stockCode));
    final holding = holdingAsync.valueOrNull;
    final orderBook = _liveOrderBook.isNotEmpty
        ? _liveOrderBook
        : detail?.orderBook ?? const <StockOrderBookLevel>[];
    final currentPrice = _realtimePrice ?? detail?.currentPrice ?? 0;
    final currentRate = _realtimeRate ?? detail?.changeRate ?? 0;
    final openPrice = _realtimeOpenPrice ?? detail?.openPrice ?? 0;
    final highPrice = _realtimeHighPrice ?? detail?.highPrice ?? 0;
    final lowPrice = _realtimeLowPrice ?? detail?.lowPrice ?? 0;
    final volume = _realtimeVolume ?? detail?.volume ?? 0;
    final availableBuyQuantity = detail?.availableBuyQuantity ?? 0;
    final availableCash = detail?.availableCash ?? 0;
    final availableSellQuantity =
        holding?.quantity ?? widget.initialHoldingQuantity;
    final maxQuantity = widget.mode == _TradeMode.buy
        ? availableBuyQuantity
        : availableSellQuantity;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final fallbackPrice = _resolveReferencePrice(orderBook, currentPrice);
    final selectedPrice = _selectedPrice ?? fallbackPrice;
    final totalAmount = quantity > 0 && selectedPrice > 0
        ? quantity * selectedPrice
        : 0;
    final canSubmit =
        !_isSubmitting &&
        detail != null &&
        quantity > 0 &&
        maxQuantity > 0 &&
        quantity <= maxQuantity;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.mode == _TradeMode.buy ? '매수' : '매도'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissKeyboard,
        child: RefreshIndicator(
          onRefresh: () async {
            await ref
                .read(detailActionViewModelProvider)
                .refreshStockDetail(
                  reload: () async {
                    ref.invalidate(stockDetailProvider(query));
                    await ref.read(stockDetailProvider(query).future);
                  },
                );
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              InfoBanner(
                message:
                    '${widget.mode == _TradeMode.buy ? '매수' : '매도'} 금액은 실시간 호가 기준으로 계산됩니다.',
              ),
              const SizedBox(height: 12),
              if (_connectionState.status !=
                  KisRealtimeConnectionStatus.connected) ...[
                _RealtimeConnectionBanner(
                  connectionState: _connectionState,
                  onRetry: () => ref
                      .read(detailActionViewModelProvider)
                      .syncStockRealtimeSubscription(
                        ownerId: _subscriptionOwnerId,
                        marketType: StockMarketType.domestic,
                        code: widget.stockCode,
                        includeOrderBook: true,
                        active: true,
                      ),
                ),
                const SizedBox(height: 12),
              ],
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.stockName} (${widget.stockCode})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatMoney(
                        currentPrice,
                        currencySymbol: '원',
                        decimals: 0,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    PercentageText(
                      value: '${currentRate.abs().toStringAsFixed(2)}%',
                      isPositive: currentRate >= 0,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _TradeStatChip(
                          label: '시가',
                          value: _formatMoney(
                            openPrice,
                            currencySymbol: '원',
                            decimals: 0,
                          ),
                        ),
                        _TradeStatChip(
                          label: '고가',
                          value: _formatMoney(
                            highPrice,
                            currencySymbol: '원',
                            decimals: 0,
                          ),
                        ),
                        _TradeStatChip(
                          label: '저가',
                          value: _formatMoney(
                            lowPrice,
                            currencySymbol: '원',
                            decimals: 0,
                          ),
                        ),
                        _TradeStatChip(
                          label: '거래량',
                          value: '${_currency(volume)}주',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.mode == _TradeMode.buy ? '실시간 매도 호가' : '실시간 매수 호가',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (detailAsync.isLoading && detail == null)
                      const Center(child: CircularProgressIndicator())
                    else if (orderBook.isEmpty)
                      Text(
                        '호가 데이터를 불러오지 못했습니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ...orderBook.map((level) {
                        final price = widget.mode == _TradeMode.buy
                            ? level.askPrice
                            : level.bidPrice;
                        final volumeAtPrice = widget.mode == _TradeMode.buy
                            ? level.askVolume
                            : level.bidVolume;
                        final isSelected = price == selectedPrice;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _dismissKeyboard();
                              setState(() {
                                _selectedPrice = price;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark
                                          ? AppColors.darkAccentSoft
                                          : const Color(0xFFEAF6F1))
                                    : (isDark
                                          ? AppColors.darkSurfaceSoft
                                          : const Color(0xFFF7F8FA)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark
                                            ? AppColors.darkAccent
                                            : AppColors.accent)
                                      : (isDark
                                            ? AppColors.darkBorder
                                            : AppColors.border),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _formatMoney(
                                        price,
                                        currencySymbol: '원',
                                        decimals: 0,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: widget.mode == _TradeMode.buy
                                                ? AppColors.negative
                                                : const Color(0xFF2D6BFF),
                                          ),
                                    ),
                                  ),
                                  Text(
                                    '${_currency(volumeAtPrice)}주',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주문 수량',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      onTapOutside: (_) => _dismissKeyboard(),
                      decoration: InputDecoration(
                        hintText: '수량 입력',
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurfaceSoft
                            : const Color(0xFFF7F7F8),
                        suffixIconConstraints: const BoxConstraints(
                          minWidth: 92,
                          minHeight: 52,
                        ),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '주',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _QuantityStepButton(
                                      icon: Icons.keyboard_arrow_up,
                                      onTap: () {
                                        _dismissKeyboard();
                                        _stepQuantity(1, maxQuantity);
                                      },
                                    ),
                                    Container(
                                      width: 28,
                                      height: 1,
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.border,
                                    ),
                                    _QuantityStepButton(
                                      icon: Icons.keyboard_arrow_down,
                                      onTap: () {
                                        _dismissKeyboard();
                                        _stepQuantity(-1, maxQuantity);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          widget.mode == _TradeMode.buy
                              ? '매수 가능 수량 ${_currency(availableBuyQuantity)}주'
                              : '매도 가능 수량 ${_currency(availableSellQuantity)}주',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: maxQuantity <= 0
                              ? null
                              : () {
                                  _dismissKeyboard();
                                  _quantityController.text = '$maxQuantity';
                                },
                          child: const Text('최대'),
                        ),
                      ],
                    ),
                    if (widget.mode == _TradeMode.buy) ...[
                      const SizedBox(height: 4),
                      Text(
                        '주문 가능 금액 ${_formatMoney(availableCash, currencySymbol: '원', decimals: 0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _TradeSummaryRow(
                      label: '선택 가격',
                      value: _formatMoney(
                        selectedPrice,
                        currencySymbol: '원',
                        decimals: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TradeSummaryRow(
                      label: '예상 주문 금액',
                      value: _formatMoney(
                        totalAmount,
                        currencySymbol: '원',
                        decimals: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: widget.mode == _TradeMode.buy
                      ? AppColors.accent
                      : const Color(0xFF27364A),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: canSubmit
                    ? () => _submitOrder(quantity, selectedPrice)
                    : null,
                child: Text(
                  _isSubmitting
                      ? '주문 중...'
                      : widget.mode == _TradeMode.buy
                      ? '매수 주문'
                      : '매도 주문',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _resolveReferencePrice(
    List<StockOrderBookLevel> orderBook,
    int fallback,
  ) {
    if (orderBook.isEmpty) {
      return fallback;
    }

    final level = orderBook.first;
    return widget.mode == _TradeMode.buy ? level.askPrice : level.bidPrice;
  }

  Future<void> _submitOrder(int quantity, int price) async {
    _dismissKeyboard();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final message = await ref
          .read(detailActionViewModelProvider)
          .submitDomesticOrder(
            action: widget.mode == _TradeMode.buy
                ? TradeOrderAction.buy
                : TradeOrderAction.sell,
            stockCode: widget.stockCode,
            quantity: quantity,
            price: price,
          );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.mode == _TradeMode.buy ? '매수 완료' : '매도 완료'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      ref.invalidate(domesticHoldingProvider(widget.stockCode));
      ref.invalidate(homeViewModelProvider);
      ref.invalidate(
        stockDetailProvider((
          code: widget.stockCode,
          name: widget.stockName,
          period: StockChartPeriod.oneDay,
          marketType: StockMarketType.domestic,
          exchangeCode: null,
        )),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = switch (error) {
        KisApiException() => error.message,
        _ => '주문 처리 중 알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _stepQuantity(int delta, int maxQuantity) {
    final current = int.tryParse(_quantityController.text.trim()) ?? 0;
    final next = current + delta;

    if (delta > 0 && maxQuantity <= 0) {
      _showQuantityToast(
        widget.mode == _TradeMode.buy ? '매수 가능 수량이 없습니다.' : '매도 가능 수량이 없습니다.',
      );
      return;
    }

    if (delta > 0 && next > maxQuantity) {
      _showQuantityToast(
        widget.mode == _TradeMode.buy
            ? '매수 가능 수량을 초과할 수 없습니다.'
            : '매도 가능 수량을 초과할 수 없습니다.',
      );
      return;
    }

    final clamped = next < 0 ? 0 : next;
    _quantityController.value = TextEditingValue(
      text: '$clamped',
      selection: TextSelection.collapsed(offset: '$clamped'.length),
    );
  }

  void _showQuantityToast(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 900),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }

  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

  void _handleRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    if (!mounted) {
      return;
    }

    final realtime = snapshot.domesticStockPrices[widget.stockCode];
    final orderBook = snapshot.orderBooks['domestic:${widget.stockCode}'];
    if (realtime == null && orderBook == null) {
      return;
    }

    setState(() {
      if (realtime != null) {
        _realtimePrice = realtime.currentPrice;
        _realtimeRate = realtime.changeRate;
        _realtimeVolume = realtime.volume;
        _realtimeOpenPrice = realtime.openPrice;
        _realtimeHighPrice = realtime.highPrice;
        _realtimeLowPrice = realtime.lowPrice;
      }
      if (orderBook != null && orderBook.isNotEmpty) {
        _liveOrderBook = orderBook;
        _selectedPrice ??= _resolveReferencePrice(orderBook, 0);
      }
    });
  }
}
