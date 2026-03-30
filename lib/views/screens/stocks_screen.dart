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
import 'detail_screens.dart';

part 'stocks_screen_sections.dart';

class StocksScreen extends ConsumerStatefulWidget {
  const StocksScreen({super.key});

  @override
  ConsumerState<StocksScreen> createState() => _StocksScreenState();
}

class _StocksScreenState extends ConsumerState<StocksScreen>
    with WidgetsBindingObserver {
  static const _subscriptionOwnerId = 'stocks_screen';

  late final TextEditingController _searchController;
  String _visibleRealtimeSignature = '';

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
    ref.read(stocksScreenViewModelProvider.notifier).attachRealtime(
          _subscriptionOwnerId,
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    unawaited(ref.read(stocksScreenViewModelProvider.notifier).detachRealtime());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || state != AppLifecycleState.resumed) {
      return;
    }

    unawaited(ref.read(stocksScreenViewModelProvider.notifier).handleAppResumed());
  }

  @override
  Widget build(BuildContext context) {
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
    _scheduleRealtimeSubscription(liveVisibleStocks);

    return _StocksScreenContent(
      searchController: _searchController,
      viewState: viewState,
      viewModel: viewModel,
      stocksAsync: stocksAsync,
      searchResultsAsync: searchResultsAsync,
      exchangeRate: exchangeRate,
      totalVisibleSourceCount: totalVisibleSourceCount,
      liveVisibleStocks: liveVisibleStocks,
      displayVisibleStocks: displayVisibleStocks,
      onDismissKeyboard: _dismissKeyboard,
      ownerId: _subscriptionOwnerId,
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
        viewModel.syncDisplayedStocks(
          ownerId: _subscriptionOwnerId,
          visibleStocks: visibleStocks,
          forceQuoteRefresh: true,
          forceSubscriptionSync: true,
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
