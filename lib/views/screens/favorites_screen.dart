import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/kis_realtime_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/api_provider.dart';
import '../widgets/common_widgets.dart';
import 'detail_screens.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with WidgetsBindingObserver {
  static const _subscriptionOwnerId = 'favorites_screen';

  late final KisRealtimeService _realtimeService;
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  StreamSubscription<KisRealtimeConnectionState>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _realtimeService = ref.read(kisRealtimeServiceProvider);
    ref
        .read(favoritesViewModelProvider.notifier)
        .applyRealtimeSnapshot(_realtimeService.snapshot);
    ref
        .read(favoritesViewModelProvider.notifier)
        .updateConnectionState(_realtimeService.connectionState);
    _realtimeSubscription = _realtimeService.stream.listen((snapshot) {
      ref
          .read(favoritesViewModelProvider.notifier)
          .applyRealtimeSnapshot(snapshot);
    });
    _connectionSubscription = _realtimeService.connectionStateStream.listen((
      state,
    ) {
      ref
          .read(favoritesViewModelProvider.notifier)
          .updateConnectionState(state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    _connectionSubscription?.cancel();
    unawaited(
      ref
          .read(favoritesViewModelProvider.notifier)
          .syncRealtimeSubscription(
            ownerId: _subscriptionOwnerId,
            visibleStocks: const <RankingStock>[],
          ),
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state != AppLifecycleState.resumed) {
      return;
    }

    final favorites = ref.read(favoriteStocksProvider);
    if (favorites.isEmpty) {
      return;
    }

    final visibleStocks = favorites
        .map((favorite) => favorite.toRankingStock())
        .toList(growable: false);
    unawaited(
      ref
          .read(favoritesViewModelProvider.notifier)
          .handleVisibleStocksChanged(
            ownerId: _subscriptionOwnerId,
            visibleStocks: visibleStocks,
            forceQuoteRefresh: true,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(favoritesViewModelProvider);
    final viewModel = ref.read(favoritesViewModelProvider.notifier);
    final favorites = ref.watch(favoriteStocksProvider);
    final exchangeRate = ref.watch(usdKrwRateProvider).valueOrNull;
    final favoriteStocks = [
      for (var index = 0; index < favorites.length; index++)
        favorites[index].toRankingStock(rank: index + 1),
    ];
    final liveFavoriteStocks = viewModel.applyRealtimeStocks(
      favoriteStocks,
      liveDomesticPrices: viewState.liveDomesticPrices,
      liveOverseasPrices: viewState.liveOverseasPrices,
      liveQuoteStocks: viewState.liveQuoteStocks,
    );
    final displayFavoriteStocks = viewModel.applyDisplayCurrency(
      liveFavoriteStocks,
      showKrwForOverseas: viewState.showKrwForOverseas,
      exchangeRate: exchangeRate,
    );
    _scheduleRealtimeSubscription(liveFavoriteStocks);
    final hasOverseasTarget = liveFavoriteStocks.any(
      (stock) => stock.marketType == StockMarketType.overseas,
    );
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => viewModel.refreshFavorites(favoriteStocks),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '즐겨찾기',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: '관심 종목',
                    leading: Icon(Icons.star_rounded, color: Color(0xFFF4B400)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '주식 상세 화면에서 별 아이콘을 눌러 종목을 추가하면 여기서 바로 볼 수 있습니다.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.5),
                  ),
                  if (hasOverseasTarget) ...[
                    const SizedBox(height: 12),
                    _FavoritesCurrencyToggle(
                      showKrw: viewState.showKrwForOverseas,
                      exchangeRate: exchangeRate,
                      onChanged: viewModel.toggleShowKrwForOverseas,
                    ),
                    if (exchangeRate != null && exchangeRate > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '실시간 적용 환율 1달러 = ${_formatAmount(exchangeRate.round())}원',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                  if (viewState.connectionState.status !=
                          KisRealtimeConnectionStatus.connected &&
                      displayFavoriteStocks.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _FavoritesRealtimeBanner(
                      connectionState: viewState.connectionState,
                      onRetry: () => viewModel.handleVisibleStocksChanged(
                        ownerId: _subscriptionOwnerId,
                        visibleStocks: liveFavoriteStocks,
                        forceQuoteRefresh: true,
                      ),
                    ),
                  ],
                  if (viewState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      viewState.errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.negative,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (displayFavoriteStocks.isEmpty)
              AppCard(
                child: Text(
                  '아직 즐겨찾기한 종목이 없습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              _FavoriteStocksList(
                stocks: displayFavoriteStocks,
                lastRefreshTime: viewState.lastRefreshTime,
              ),
          ],
        ),
      ),
    );
  }

  void _scheduleRealtimeSubscription(List<RankingStock> stocks) {
    final viewModel = ref.read(favoritesViewModelProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        viewModel.handleVisibleStocksChanged(
          ownerId: _subscriptionOwnerId,
          visibleStocks: stocks,
        ),
      );
    });
  }
}

class _FavoriteStocksList extends StatelessWidget {
  const _FavoriteStocksList({
    required this.stocks,
    required this.lastRefreshTime,
  });

  final List<RankingStock> stocks;
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
                    '즐겨찾기 종목',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '총 ${stocks.length}종목',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatFavoriteRefreshTime(lastRefreshTime),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8, color: AppColors.border),
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
                    const Icon(Icons.star_rounded, color: Color(0xFFF4B400)),
                    const SizedBox(width: 12),
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
                            stocks[index].marketLabel.isEmpty
                                ? stocks[index].code
                                : '${stocks[index].marketLabel} · ${stocks[index].code}',
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
                        PercentageText(
                          value:
                              '${stocks[index].changeRate.abs().toStringAsFixed(2)}%',
                          isPositive: stocks[index].isPositive,
                          fontSize: 13,
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

class _FavoritesCurrencyToggle extends StatelessWidget {
  const _FavoritesCurrencyToggle({
    required this.showKrw,
    required this.exchangeRate,
    required this.onChanged,
  });

  final bool showKrw;
  final double? exchangeRate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasExchangeRate = exchangeRate != null && exchangeRate! > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceSoft : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              !hasExchangeRate
                  ? '해외 종목 원화 보기'
                  : '해외 종목 원화 보기  •  1달러 ${exchangeRate!.toStringAsFixed(0)}원',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Switch.adaptive(value: showKrw, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FavoritesRealtimeBanner extends StatelessWidget {
  const _FavoritesRealtimeBanner({
    required this.connectionState,
    required this.onRetry,
  });

  final KisRealtimeConnectionState connectionState;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMarketClosed = (connectionState.errorMessage ?? '').contains(
      '시간이 아닙니다.',
    );
    final message = switch (connectionState.status) {
      KisRealtimeConnectionStatus.connecting => '즐겨찾기 실시간 연결 중입니다.',
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
              child: Text(
                connectionState.status == KisRealtimeConnectionStatus.connecting
                    ? '연결 중'
                    : '재연결',
              ),
            ),
        ],
      ),
    );
  }
}

String _formatStockPrice(RankingStock stock) {
  final currencySymbol = stock.currencySymbol;
  final isWon = currencySymbol == '원';
  if (isWon) {
    return '${_formatAmount(stock.price)}원';
  }

  final scale = _pow10(stock.priceDecimals);
  final amount = stock.price / scale;
  return '$currencySymbol${amount.toStringAsFixed(2)}';
}

String _formatAmount(int value) {
  final raw = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final reversedIndex = raw.length - index;
    buffer.write(raw[index]);
    if (reversedIndex > 1 && reversedIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

int _pow10(int exponent) {
  var value = 1;
  for (var index = 0; index < exponent; index++) {
    value *= 10;
  }
  return value;
}

String _formatFavoriteRefreshTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute 기준';
}
