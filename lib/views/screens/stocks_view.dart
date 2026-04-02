import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/kis_realtime_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/ranking_stock.dart';
import '../../models/stock_market_type.dart';
import '../../providers/api_provider.dart';
import '../../viewmodels/stocks_screen_view_model.dart';
import '../../viewmodels/stocks_screen_view_state.dart';
import '../widgets/common_widgets.dart';
import 'detail_views.dart';

part 'stocks_view_sections.dart';

class StocksScreen extends ConsumerWidget {
  const StocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewState = ref.watch(stocksScreenViewModelProvider);
    final viewModel = ref.read(stocksScreenViewModelProvider.notifier);
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
    final isSourceLoading = trimmedSearchQuery.isNotEmpty
        ? (searchResultsAsync?.isLoading ?? false)
        : stocksAsync.isLoading;

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
    final nextVisibleSignature = visibleRealtimeSource
        .map(viewModel.stockKey)
        .join('|');

    if (viewState.visibleRealtimeSignature != nextVisibleSignature ||
        (isSourceLoading && visibleRealtimeSource.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          viewModel.syncDisplayedStocks(
            visibleStocks: visibleRealtimeSource,
            exchangeRate: exchangeRate,
            forceQuoteRefresh: false,
            forceSubscriptionSync: false,
            preserveExistingWhenLoading:
                isSourceLoading && visibleRealtimeSource.isEmpty,
          ),
        );
      });
    }

    return ResumeListener(
      onResume: () => unawaited(viewModel.handleAppResumed()),
      child: _StocksScreenContent(
        searchQuery: viewState.searchQuery,
        viewState: viewState,
        viewModel: viewModel,
        stocksAsync: stocksAsync,
        searchResultsAsync: searchResultsAsync,
        exchangeRate: exchangeRate,
        totalVisibleSourceCount: totalVisibleSourceCount,
        liveVisibleStocks: viewState.displayVisibleStocks,
        displayVisibleStocks: viewState.displayVisibleStocks,
        onDismissKeyboard: () => _dismissKeyboard(context),
        onSearchChanged: viewModel.updateSearchQuery,
        onClearSearch: viewModel.clearSearchQuery,
      ),
    );
  }

  void _dismissKeyboard(BuildContext context) {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }
}
