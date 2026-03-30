import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_config.dart';
import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../repositories/home_repository.dart';
import '../repositories/exchange_rate_repository.dart';
import '../repositories/market_index_detail_repository.dart';
import '../repositories/stock_detail_repository.dart';
import '../repositories/stock_search_repository.dart';
import '../repositories/stocks_market_repository.dart';
import '../viewmodels/detail_action_view_model.dart';
import '../viewmodels/favorites_view_model.dart';
import '../viewmodels/favorites_view_state.dart';
import '../viewmodels/stocks_screen_view_model.dart';
import '../viewmodels/stocks_screen_view_state.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'theme_mode_v1';

  bool _didRestore = false;

  @override
  ThemeMode build() {
    if (!_didRestore) {
      _didRestore = true;
      Future<void>.microtask(_restoreThemeMode);
    }
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) {
      return;
    }

    state = mode;
    try {
      await _storage.write(key: _storageKey, value: mode.name);
    } catch (_) {
      await _safeDeleteThemeMode();
    }
  }

  Future<void> _restoreThemeMode() async {
    String? storedMode;
    try {
      storedMode = await _storage.read(key: _storageKey);
    } catch (_) {
      await _safeDeleteThemeMode();
    }

    final resolvedMode = switch (storedMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    if (state != resolvedMode) {
      state = resolvedMode;
    }
  }

  Future<void> _safeDeleteThemeMode() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class FavoriteStocksNotifier extends Notifier<List<FavoriteStock>> {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'favorite_stocks_v1';

  bool _didRestore = false;

  @override
  List<FavoriteStock> build() {
    if (!_didRestore) {
      _didRestore = true;
      Future<void>.microtask(_restoreFavorites);
    }
    return const <FavoriteStock>[];
  }

  Future<void> toggle(FavoriteStock stock) async {
    final existingIndex = state.indexWhere(
      (favorite) => favorite.key == stock.key,
    );
    if (existingIndex >= 0) {
      state = [
        ...state.sublist(0, existingIndex),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [...state, stock];
    }
    await _persistFavorites();
  }

  Future<void> upsert(FavoriteStock stock) async {
    final existingIndex = state.indexWhere(
      (favorite) => favorite.key == stock.key,
    );
    if (existingIndex >= 0) {
      final nextFavorites = [...state];
      nextFavorites[existingIndex] = stock;
      state = nextFavorites;
    } else {
      state = [...state, stock];
    }
    await _persistFavorites();
  }

  bool contains(FavoriteStock stock) {
    return state.any((favorite) => favorite.key == stock.key);
  }

  Future<void> _restoreFavorites() async {
    String? rawValue;
    try {
      rawValue = await _storage.read(key: _storageKey);
    } catch (_) {
      await _safeDeleteFavorites();
    }

    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawValue) as List<dynamic>;
      state = decoded
          .whereType<Map<String, dynamic>>()
          .map(FavoriteStock.fromJson)
          .toList(growable: false);
    } catch (_) {
      await _safeDeleteFavorites();
      state = const <FavoriteStock>[];
    }
  }

  Future<void> _persistFavorites() async {
    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(state.map((stock) => stock.toJson()).toList()),
      );
    } catch (_) {
      await _safeDeleteFavorites();
    }
  }

  Future<void> _safeDeleteFavorites() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (_) {}
  }
}

final favoriteStocksProvider =
    NotifierProvider<FavoriteStocksNotifier, List<FavoriteStock>>(
      FavoriteStocksNotifier.new,
    );

final kisApiConfigProvider = Provider<KisApiConfig>((ref) {
  return KisApiConfig.fromEnvironment();
});

final kisApiClientProvider = Provider<KisApiClient>((ref) {
  return KisApiClient(ref.watch(kisApiConfigProvider));
});

final kisRealtimeServiceProvider = Provider<KisRealtimeService>((ref) {
  final service = KisRealtimeService(ref.watch(kisApiClientProvider));
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final availableAccountsProvider = Provider<List<AccountProfile>>((ref) {
  return ref
      .watch(kisApiConfigProvider)
      .accounts
      .where((account) => account.isConfigured)
      .toList();
});

final selectedAccountIdProvider = StateProvider<String?>((ref) {
  final accounts = ref.watch(availableAccountsProvider);
  return accounts.isEmpty ? null : accounts.first.id;
});

final selectedAccountProvider = Provider<AccountProfile?>((ref) {
  final accounts = ref.watch(availableAccountsProvider);
  final selectedId = ref.watch(selectedAccountIdProvider);

  for (final account in accounts) {
    if (account.id == selectedId) {
      return account;
    }
  }

  return accounts.isEmpty ? null : accounts.first;
});

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final account = ref.watch(selectedAccountProvider);
  return HomeRepository(
    ref.watch(kisApiClientProvider),
    account ??
        const AccountProfile(
          id: 'empty',
          label: '미설정',
          accountNumber: '',
          accountProductCode: '',
          isIsa: false,
        ),
    ref.watch(stocksMarketRepositoryProvider),
  );
});

final stockDetailRepositoryProvider = Provider<StockDetailRepository>((ref) {
  final account = ref.watch(selectedAccountProvider);
  return StockDetailRepository(
    ref.watch(kisApiClientProvider),
    account ??
        const AccountProfile(
          id: 'empty',
          label: '미설정',
          accountNumber: '',
          accountProductCode: '',
          isIsa: false,
        ),
  );
});

final marketIndexDetailRepositoryProvider =
    Provider<MarketIndexDetailRepository>((ref) {
      return MarketIndexDetailRepository(ref.watch(kisApiClientProvider));
    });

final exchangeRateRepositoryProvider = Provider<ExchangeRateRepository>((ref) {
  return ExchangeRateRepository(ref.watch(kisApiClientProvider));
});

final usdKrwRateProvider = StreamProvider.autoDispose<double>((ref) {
  return ref.watch(exchangeRateRepositoryProvider).watchUsdKrwRate();
});

final stockDetailProvider = FutureProvider.autoDispose
    .family<
      StockDetail,
      ({
        String code,
        String name,
        StockChartPeriod period,
        StockMarketType marketType,
        String? exchangeCode,
      })
    >((ref, query) {
      return ref
          .watch(stockDetailRepositoryProvider)
          .fetchStockDetail(
            code: query.code,
            name: query.name,
            period: query.period,
            marketType: query.marketType,
            exchangeCode: query.exchangeCode,
          );
    });

final marketIndexDetailProvider = FutureProvider.autoDispose
    .family<MarketIndexDetail, ({String name, StockChartPeriod period})>((
      ref,
      query,
    ) {
      return ref
          .watch(marketIndexDetailRepositoryProvider)
          .fetchMarketIndexDetail(name: query.name, period: query.period);
    });

final detailActionViewModelProvider = Provider<DetailActionViewModel>((ref) {
  return DetailActionViewModel(
    stockDetailRepository: ref.watch(stockDetailRepositoryProvider),
    realtimeService: ref.watch(kisRealtimeServiceProvider),
  );
});

final stocksMarketRepositoryProvider = Provider<StocksMarketRepository>((ref) {
  return StocksMarketRepository(
    ref.watch(kisApiClientProvider),
    ref.watch(stockSearchRepositoryProvider),
  );
});

final stocksScreenViewModelProvider =
    NotifierProvider<StocksScreenViewModel, StocksScreenViewState>(
      StocksScreenViewModel.new,
    );

final favoritesViewModelProvider =
    NotifierProvider<FavoritesViewModel, FavoritesViewState>(
      FavoritesViewModel.new,
    );

final stockSearchRepositoryProvider = Provider<StockSearchRepository>((ref) {
  return StockSearchRepository();
});

final marketStocksProvider = FutureProvider.autoDispose
    .family<List<RankingStock>, ({String market, String category})>((
      ref,
      query,
    ) {
      final repository = ref.watch(stocksMarketRepositoryProvider);
      return repository.fetchMarketStocks(
        market: query.market,
        category: query.category,
      );
    });

final stockSearchProvider = FutureProvider.autoDispose
    .family<List<RankingStock>, String>((ref, query) {
      return ref.watch(stocksMarketRepositoryProvider).searchStocks(query);
    });

final domesticHoldingProvider = FutureProvider.autoDispose
    .family<HoldingStock?, String>((ref, code) async {
      final trimmedCode = code.trim();
      if (trimmedCode.isEmpty) {
        return null;
      }

      final holdings = await ref
          .watch(homeRepositoryProvider)
          .fetchDomesticHoldings();
      for (final holding in holdings) {
        if (holding.code == trimmedCode) {
          return holding;
        }
      }
      return null;
    });

final portfolioProfitHistoryProvider =
    FutureProvider.autoDispose<PortfolioProfitHistory>((ref) async {
      final repository = ref.watch(homeRepositoryProvider);
      final currentSummary = await repository.fetchPortfolioSummary();
      return repository.fetchPortfolioProfitHistory(
        currentSummary: currentSummary,
      );
    });
