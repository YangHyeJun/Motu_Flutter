import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/kis_realtime_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/api_provider.dart';
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
                    builder: (_) => StockDetailScreen.fromHolding(stock: stock),
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

class MarketIndexDetailScreen extends ConsumerStatefulWidget {
  MarketIndexDetailScreen({
    super.key,
    required this.index,
  }) : name = index.name,
       currentValue = index.value,
       changeRate = 0,
       isPositive = index.isPositive;

  final MarketIndex index;
  final String name;
  final String currentValue;
  final double changeRate;
  final bool isPositive;

  @override
  ConsumerState<MarketIndexDetailScreen> createState() => _MarketIndexDetailScreenState();
}

class _MarketIndexDetailScreenState extends ConsumerState<MarketIndexDetailScreen> {
  StockChartPeriod _selectedPeriod = StockChartPeriod.oneDay;
  late final KisRealtimeService _realtimeService;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  int? _realtimeValue;
  double? _realtimeRate;
  KisRealtimeConnectionState _connectionState = const KisRealtimeConnectionState(
    status: KisRealtimeConnectionStatus.disconnected,
  );

  @override
  void initState() {
    super.initState();
    _realtimeService = KisRealtimeService(ref.read(kisApiClientProvider));
    _realtimeSubscription = _realtimeService.stream.listen(_handleRealtimeSnapshot);
    _connectionSubscription = _realtimeService.connectionStateStream.listen((state) {
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
    _realtimeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      name: widget.name,
      period: _selectedPeriod,
    );
    final detailAsync = ref.watch(marketIndexDetailProvider(query));
    final detail = detailAsync.valueOrNull;
    final displayValue = _realtimeValue != null
        ? _formatCompactNumber(_realtimeValue!)
        : detail?.currentValue ?? widget.currentValue;
    final displayRate =
        _realtimeRate ?? detail?.changeRate ?? _parseSignedPercent(widget.index.changeRate);
    final displayPositive = detail?.isPositive ?? widget.isPositive;
    final chartEntries = _mergeRealtimeChartEntries(
      entries: detail?.chartEntries ?? const <StockChartEntry>[],
      realtimePrice: _realtimeValue,
      applyRealtime: _selectedPeriod == StockChartPeriod.oneDay && widget.name == '코스피',
    );
    final range = _chartRange(chartEntries);

    Future<void> refreshDetail() async {
      ref.invalidate(marketIndexDetailProvider(query));
      await ref.read(marketIndexDetailProvider(query).future);
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: refreshDetail,
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
                      widget.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      displayValue,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '전일 대비 ',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        PercentageText(
                          value:
                              '${detail?.changeAmount ?? _formatSignedPercent(displayRate)} (${displayRate.abs().toStringAsFixed(2)}%)',
                          isPositive: displayPositive,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_selectedPeriod == StockChartPeriod.oneDay &&
                        _connectionState.status != KisRealtimeConnectionStatus.connected) ...[
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
                                isLoading: detailAsync.isLoading && detail == null,
                                errorText: detailAsync.hasError ? '지수 차트 데이터를 불러오지 못했습니다.' : null,
                                valueSuffix: '',
                                valueFormatter: _formatCompactNumber,
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
                      highValue: range == null ? '-' : _formatCompactNumber(range.$1),
                      lowLabel: '최저',
                      lowValue: range == null ? '-' : _formatCompactNumber(range.$2),
                    ),
                    const SizedBox(height: 18),
                    _IndexMetricRow(
                      openValue: detail?.openValue ?? '-',
                      highValue: detail?.highValue ?? '-',
                      lowValue: detail?.lowValue ?? '-',
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
    if (_selectedPeriod == StockChartPeriod.oneDay && widget.name == '코스피') {
      await _realtimeService.connect(domesticCodes: const [], includeKospi: true);
      return;
    }

    _realtimeValue = null;
    _realtimeRate = null;
    await _realtimeService.disconnect(clearSnapshot: false);
  }

  void _handleRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    if (!mounted || widget.name != '코스피' || _selectedPeriod != StockChartPeriod.oneDay) {
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
  StockDetailScreen.fromHolding({
    super.key,
    required HoldingStock stock,
  }) : name = stock.name,
       code = stock.code,
       marketType = StockMarketType.domestic,
       exchangeCode = null,
       priceDecimals = 0,
       currencySymbol = '원',
       currentPrice = stock.currentPrice,
       changeRate = stock.profitRate,
       isPositive = stock.isPositive,
       averagePrice = stock.buyPrice,
       quantity = stock.quantity;

  StockDetailScreen.fromRanking({
    super.key,
    required RankingStock stock,
  }) : name = stock.name,
       code = stock.code,
       marketType = stock.marketType,
       exchangeCode = stock.exchangeCode,
       priceDecimals = stock.priceDecimals,
       currencySymbol = stock.currencySymbol,
       currentPrice = stock.price,
       changeRate = stock.changeRate,
       isPositive = stock.isPositive,
       averagePrice = null,
       quantity = null;

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

  @override
  ConsumerState<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends ConsumerState<StockDetailScreen> {
  StockChartPeriod _selectedPeriod = StockChartPeriod.oneDay;
  late final KisRealtimeService _realtimeService;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;
  int? _realtimePrice;
  double? _realtimeRate;
  KisRealtimeConnectionState _connectionState = const KisRealtimeConnectionState(
    status: KisRealtimeConnectionStatus.disconnected,
  );

  @override
  void initState() {
    super.initState();
    _realtimeService = KisRealtimeService(ref.read(kisApiClientProvider));
    _realtimeSubscription = _realtimeService.stream.listen(_handleRealtimeSnapshot);
    _connectionSubscription = _realtimeService.connectionStateStream.listen((state) {
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
    _realtimeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      code: widget.code,
      name: widget.name,
      period: _selectedPeriod,
      marketType: widget.marketType,
      exchangeCode: widget.exchangeCode,
    );
    final detailAsync = ref.watch(stockDetailProvider(query));
    final detail = detailAsync.valueOrNull;
    final displayPrice = _realtimePrice ?? detail?.currentPrice ?? widget.currentPrice;
    final displayRate = _realtimeRate ?? detail?.changeRate ?? widget.changeRate;
    final displayPositive = displayRate >= 0;
    final chartEntries = _mergeRealtimeChartEntries(
      entries: detail?.chartEntries ?? const <StockChartEntry>[],
      realtimePrice: _realtimePrice,
      applyRealtime: _selectedPeriod == StockChartPeriod.oneDay,
    );
    final displayVolume = detail?.volume ?? 0;
    final range = _chartRange(chartEntries);
    final displayOpenPrice = detail?.openPrice ?? 0;
    final displayHighPrice = math.max(detail?.highPrice ?? 0, range?.$1 ?? 0);
    final displayLowPrice = detail?.lowPrice == null || detail!.lowPrice == 0
        ? (range?.$2 ?? 0)
        : math.min(detail.lowPrice, range?.$2 ?? detail.lowPrice);
    final compareLabel = widget.averagePrice == null ? '전일 대비 ' : '내 평균 대비 ';
    final compareAmount = widget.averagePrice == null
        ? (displayPrice * (displayRate.abs() / 100)).round()
        : (displayPrice - widget.averagePrice!).abs();
    final priceDecimals = detail?.priceDecimals ?? widget.priceDecimals;
    final currencySymbol = detail?.currencySymbol ?? widget.currencySymbol;
    final isOverseas = (detail?.marketType ?? widget.marketType) == StockMarketType.overseas;

    Future<void> refreshDetail() async {
      ref.invalidate(stockDetailProvider(query));
      await ref.read(stockDetailProvider(query).future);
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
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
                    Text(
                      _formatMoney(
                        displayPrice,
                        currencySymbol: currencySymbol,
                        decimals: priceDecimals,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
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
                          widget.quantity == null ? '일반 종목 상세 보기' : '보유수량: ${widget.quantity}주',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (widget.marketType == StockMarketType.domestic &&
                        _selectedPeriod == StockChartPeriod.oneDay &&
                        _connectionState.status != KisRealtimeConnectionStatus.connected) ...[
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
                                isLoading: detailAsync.isLoading && detail == null,
                                errorText: detailAsync.hasError ? '차트 데이터를 불러오지 못했습니다.' : null,
                                valueSuffix: currencySymbol,
                                valueFormatter: (value) => _formatMoney(
                                  value,
                                  currencySymbol: currencySymbol,
                                  decimals: priceDecimals,
                                ),
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
                        });
                        await _syncRealtimeSubscription();
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
                    if (detail != null && detail.orderBook.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _OrderBookCard(
                        orderBook: detail.orderBook,
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
                        onPressed: isOverseas ? null : () {},
                        child: Text(
                          isOverseas ? '해외 종목 정보 보기' : '구매하기',
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

  Future<void> _syncRealtimeSubscription() async {
    if (widget.marketType == StockMarketType.domestic &&
        _selectedPeriod == StockChartPeriod.oneDay) {
      await _realtimeService.connect(
        domesticCodes: [widget.code],
        includeKospi: false,
      );
      return;
    }

    await _realtimeService.disconnect(clearSnapshot: false);
  }

  void _handleRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    if (!mounted ||
        widget.marketType != StockMarketType.domestic ||
        _selectedPeriod != StockChartPeriod.oneDay) {
      return;
    }

    final realtime = snapshot.domesticStockPrices[widget.code];
    if (realtime == null) {
      return;
    }

    setState(() {
      _realtimePrice = realtime.currentPrice;
      _realtimeRate = realtime.changeRate;
    });
  }
}

class _RealtimeConnectionBanner extends StatelessWidget {
  const _RealtimeConnectionBanner({
    required this.connectionState,
    required this.onRetry,
  });

  final KisRealtimeConnectionState connectionState;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final attemptedAt = connectionState.lastAttemptedAt;
    final message = switch (connectionState.status) {
      KisRealtimeConnectionStatus.connecting => '실시간 연결을 시도하고 있습니다.',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_tethering_error_rounded, color: Color(0xFFC27A11), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF8F5B0D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (attemptedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '마지막 시도 ${_formatRetryTime(attemptedAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8F5B0D),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: connectionState.status == KisRealtimeConnectionStatus.connecting
                      ? null
                      : onRetry,
                  icon: connectionState.status == KisRealtimeConnectionStatus.connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    connectionState.status == KisRealtimeConnectionStatus.connecting
                        ? '연결 중'
                        : '다시 연결',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC27A11),
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

class _IndexMetricRow extends StatelessWidget {
  const _IndexMetricRow({
    required this.openValue,
    required this.highValue,
    required this.lowValue,
  });

  final String openValue;
  final String highValue;
  final String lowValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(label: '시가', value: openValue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: '고가', value: highValue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: '저가', value: lowValue),
        ),
      ],
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

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.chartEntries,
    required this.isLoading,
    required this.errorText,
    required this.valueSuffix,
    required this.valueFormatter,
  });

  final List<StockChartEntry> chartEntries;
  final bool isLoading;
  final String? errorText;
  final String valueSuffix;
  final String Function(int value) valueFormatter;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chartEntries.isEmpty) {
      return Center(
        child: Text(
          errorText ?? '차트 데이터가 없습니다.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: StockLineChart(
        entries: chartEntries,
        valueSuffix: valueSuffix,
        valueFormatter: valueFormatter,
      ),
    );
  }
}

class _ChartRangeSummary extends StatelessWidget {
  const _ChartRangeSummary({
    required this.highLabel,
    required this.highValue,
    required this.lowLabel,
    required this.lowValue,
  });

  final String highLabel;
  final String highValue;
  final String lowLabel;
  final String lowValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(label: highLabel, value: highValue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(label: lowLabel, value: lowValue),
        ),
      ],
    );
  }
}

class _PriceSummaryRow extends StatelessWidget {
  const _PriceSummaryRow({
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.currencySymbol,
    required this.priceDecimals,
  });

  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final String currencySymbol;
  final int priceDecimals;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: '시가',
            value: _formatMoney(
              openPrice,
              currencySymbol: currencySymbol,
              decimals: priceDecimals,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: '고가',
            value: _formatMoney(
              highPrice,
              currencySymbol: currencySymbol,
              decimals: priceDecimals,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricCard(
            label: '저가',
            value: _formatMoney(
              lowPrice,
              currencySymbol: currencySymbol,
              decimals: priceDecimals,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderBookCard extends StatelessWidget {
  const _OrderBookCard({
    required this.orderBook,
    required this.currencySymbol,
    required this.priceDecimals,
  });

  final List<StockOrderBookLevel> orderBook;
  final String currencySymbol;
  final int priceDecimals;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('호가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...orderBook.map((level) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatNumber(level.askVolume)}주',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatMoney(
                        level.askPrice,
                        currencySymbol: currencySymbol,
                        decimals: priceDecimals,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.negative,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _formatMoney(
                        level.bidPrice,
                        currencySymbol: currencySymbol,
                        decimals: priceDecimals,
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.positive,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${_formatNumber(level.bidVolume)}주',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoGridCard extends StatelessWidget {
  const _InfoGridCard({required this.items});

  final List<StockInfoItem> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기본 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _VolumeSection extends StatelessWidget {
  const _VolumeSection({
    required this.entries,
    required this.volume,
    required this.isLoading,
  });

  final List<StockChartEntry> entries;
  final int volume;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '거래량',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${_currency(volume)}주',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    '거래량 데이터가 없습니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : VolumeBarChart(entries: entries),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.selectedPeriod,
    required this.onSelect,
  });

  final StockChartPeriod selectedPeriod;
  final ValueChanged<StockChartPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StockChartPeriod.values.map((period) {
        final selected = period == selectedPeriod;
        return GestureDetector(
          onTap: () => onSelect(period),
          child: Container(
            width: 52,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.black : const Color(0xFFF0F1F4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              period.label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
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

String _formatMoney(
  int value, {
  required String currencySymbol,
  required int decimals,
}) {
  final negative = value < 0;
  final scale = _pow10(decimals);
  final absolute = value.abs();
  final whole = decimals == 0 ? absolute : absolute ~/ scale;
  final fraction = decimals == 0 ? '' : (absolute % scale).toString().padLeft(decimals, '0');
  final numberText = _formatNumber(whole);
  final amount = fraction.isEmpty ? numberText : '$numberText.$fraction';
  final prefix = currencySymbol == '원' ? '' : currencySymbol;
  final suffix = currencySymbol == '원' ? currencySymbol : '';
  return '${negative ? '-' : ''}$prefix$amount$suffix';
}

String _formatNumber(int value) {
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

int _pow10(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

List<StockChartEntry> _mergeRealtimeChartEntries({
  required List<StockChartEntry> entries,
  required int? realtimePrice,
  required bool applyRealtime,
}) {
  if (!applyRealtime || realtimePrice == null) {
    return entries;
  }

  final nextEntries = List<StockChartEntry>.from(entries);
  final now = DateTime.now();
  final timeLabel =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  final date =
      '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

  final nextEntry = StockChartEntry(
    date: date,
    timeLabel: timeLabel,
    openPrice: nextEntries.isEmpty ? realtimePrice : nextEntries.last.openPrice,
    highPrice: nextEntries.isEmpty
        ? realtimePrice
        : math.max(nextEntries.last.highPrice, realtimePrice),
    lowPrice: nextEntries.isEmpty
        ? realtimePrice
        : math.min(nextEntries.last.lowPrice, realtimePrice),
    closePrice: realtimePrice,
    volume: nextEntries.isEmpty ? 0 : nextEntries.last.volume,
  );

  if (nextEntries.isEmpty) {
    return [nextEntry];
  }

  if (nextEntries.last.timeLabel == timeLabel) {
    final previousEntry = nextEntries.last;
    nextEntries[nextEntries.length - 1] = StockChartEntry(
      date: date,
      timeLabel: timeLabel,
      openPrice: previousEntry.openPrice,
      highPrice: math.max(previousEntry.highPrice, realtimePrice),
      lowPrice: math.min(previousEntry.lowPrice, realtimePrice),
      closePrice: realtimePrice,
      volume: previousEntry.volume,
    );
  } else {
    nextEntries.add(nextEntry);
  }

  return nextEntries;
}

(int, int)? _chartRange(List<StockChartEntry> entries) {
  if (entries.isEmpty) {
    return null;
  }

  var high = entries.first.highPrice;
  var low = entries.first.lowPrice;

  for (final entry in entries) {
    if (entry.highPrice > high) {
      high = entry.highPrice;
    }
    if (entry.lowPrice < low) {
      low = entry.lowPrice;
    }
  }

  return (high, low);
}

String _formatCompactNumber(int value) {
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

double _parseSignedPercent(String value) {
  return double.tryParse(value.replaceAll('%', '').replaceAll('+', '').replaceAll(',', '')) ??
      0.0;
}

String _formatSignedPercent(double value) {
  return '${value >= 0 ? '+' : '-'}${value.abs().toStringAsFixed(2)}';
}

String _formatRetryTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}
