import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/kis_realtime_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/api_provider.dart';
import '../widgets/common_widgets.dart';
import 'detail_views.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final nextVisibleSignature = liveFavoriteStocks
        .map(viewModel.stockKey)
        .join('|');

    if (viewState.visibleRealtimeSignature != nextVisibleSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          viewModel.syncDisplayedStocks(
            visibleStocks: liveFavoriteStocks,
            forceQuoteRefresh: false,
            forceSubscriptionSync: false,
          ),
        );
      });
    }

    return ResumeListener(
      onResume: () {
        final visibleStocks = ref
            .read(favoriteStocksProvider)
            .map((favorite) => favorite.toRankingStock())
            .toList(growable: false);
        unawaited(viewModel.handleAppResumed(visibleStocks));
      },
      child: SafeArea(
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
                    if (liveFavoriteStocks.any(
                      (stock) => stock.marketType == StockMarketType.overseas,
                    )) ...[
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
                        onRetry: () => viewModel.syncDisplayedStocks(
                          visibleStocks: liveFavoriteStocks,
                          forceQuoteRefresh: true,
                          forceSubscriptionSync: true,
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
      ),
    );
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
                  builder: (_) => StockDetailScreen.fromRanking(
                    stock: stocks[index],
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceSoft
                            : const Color(0xFFF8F6E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                            stocks[index].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${stocks[index].marketLabel} · ${stocks[index].code}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatFavoritePrice(stocks[index]),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        PercentageText(
                          value:
                              '${stocks[index].changeRate.abs().toStringAsFixed(2)}%',
                          isPositive: stocks[index].isPositive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (index < stocks.length - 1)
              const Divider(height: 1, thickness: 0.8, color: AppColors.border),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FavoritesChip(
          label: '달러',
          selected: !showKrw,
          onTap: () => onChanged(false),
        ),
        _FavoritesChip(
          label: '원화',
          selected: showKrw,
          enabled: exchangeRate != null && exchangeRate! > 0,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _FavoritesChip extends StatelessWidget {
  const _FavoritesChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
      selectedColor: AppColors.accent.withValues(alpha: 0.16),
      checkmarkColor: AppColors.accent,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: enabled ? null : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: enabled
            ? (selected ? AppColors.accent : AppColors.border)
            : AppColors.border.withValues(alpha: 0.45),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurfaceSoft
          : Colors.white,
    );
  }
}

class _FavoritesRealtimeBanner extends StatelessWidget {
  const _FavoritesRealtimeBanner({
    required this.connectionState,
    required this.onRetry,
  });

  final KisRealtimeConnectionState connectionState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return InfoBanner(
      message: _favoritesBannerMessage(connectionState),
      trailing: TextButton(
        onPressed: onRetry,
        child: const Text('재연결'),
      ),
    );
  }
}

String _formatAmount(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < text.length; index++) {
    if (index > 0 && (text.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[index]);
  }
  return buffer.toString();
}

String _formatFavoriteRefreshTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatFavoritePrice(RankingStock stock) {
  final scale = _pow10(stock.priceDecimals);
  if (stock.currencySymbol == '원') {
    return '${_formatAmount(stock.price)}원';
  }
  final usd = stock.price / scale;
  return '\$${_trimTrailingZeros(usd.toStringAsFixed(2))}';
}

String _favoritesBannerMessage(KisRealtimeConnectionState state) {
  switch (state.status) {
    case KisRealtimeConnectionStatus.connecting:
      return '실시간 연결 중입니다.';
    case KisRealtimeConnectionStatus.failed:
      return '실시간 연결이 끊어졌습니다.';
    case KisRealtimeConnectionStatus.disconnected:
      return '실시간 연결이 끊어졌습니다.';
    case KisRealtimeConnectionStatus.connected:
      return '실시간 연결이 끊어졌습니다.';
  }
}

int _pow10(int exponent) {
  var value = 1;
  for (var index = 0; index < exponent; index++) {
    value *= 10;
  }
  return value;
}

String _trimTrailingZeros(String value) {
  var trimmed = value;
  while (trimmed.contains('.') && trimmed.endsWith('0')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  if (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
