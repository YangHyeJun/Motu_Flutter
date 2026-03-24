import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_config.dart';
import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../repositories/home_repository.dart';
import '../repositories/market_index_detail_repository.dart';
import '../repositories/stock_detail_repository.dart';
import '../repositories/stocks_market_repository.dart';

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

final marketIndexDetailRepositoryProvider = Provider<MarketIndexDetailRepository>((ref) {
  return MarketIndexDetailRepository(ref.watch(kisApiClientProvider));
});

final stockDetailProvider =
    FutureProvider.autoDispose
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
      return ref.watch(stockDetailRepositoryProvider).fetchStockDetail(
            code: query.code,
            name: query.name,
            period: query.period,
            marketType: query.marketType,
            exchangeCode: query.exchangeCode,
          );
    });

final marketIndexDetailProvider = FutureProvider.autoDispose
    .family<MarketIndexDetail, ({String name, StockChartPeriod period})>((ref, query) {
      return ref.watch(marketIndexDetailRepositoryProvider).fetchMarketIndexDetail(
            name: query.name,
            period: query.period,
          );
    });

final stocksMarketRepositoryProvider = Provider<StocksMarketRepository>((ref) {
  return StocksMarketRepository(ref.watch(kisApiClientProvider));
});

final marketStocksProvider = FutureProvider.autoDispose
    .family<List<RankingStock>, ({String market, String category})>((ref, query) {
      final repository = ref.watch(stocksMarketRepositoryProvider);
      return repository.fetchMarketStocks(
        market: query.market,
        category: query.category,
      );
    });

final stockSearchProvider = FutureProvider.autoDispose.family<List<RankingStock>, String>((
  ref,
  query,
) {
  return ref.watch(stocksMarketRepositoryProvider).searchStocks(query);
});
