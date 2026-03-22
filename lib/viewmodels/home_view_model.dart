import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/kis_api_exception.dart';
import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../providers/api_provider.dart';
import 'home_view_state.dart';

class HomeViewModel extends Notifier<HomeViewState> {
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;

  @override
  HomeViewState build() {
    ref.watch(selectedAccountProvider);
    _ensureRealtimeListener();
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
    });
    final initialState = _buildInitialState();
    Future<void>.microtask(_loadFromServer);
    return initialState;
  }

  Future<void> refreshAll() async {
    await _loadFromServer();
  }

  Future<void> refreshRealtimeSections() async {
    await _loadFromServer();
  }

  HomeViewState _buildInitialState() {
    return HomeViewState(
      summary: const PortfolioSummary(
        asset: 0,
        invested: 0,
        profitRate: 0,
        profitAmount: 0,
      ),
      marketIndexes: const [],
      domesticHoldings: const [],
      usHoldings: const [],
      shortSellRankings: const [],
      tips: const [],
      chartPoints: const [],
      lastUpdated: DateTime.now(),
      isSyncing: false,
      syncStatus: HomeSyncStatus.idle,
      accountSyncErrorTitle: null,
      accountSyncErrorMessage: null,
    );
  }

  Future<void> _loadFromServer() async {
    final apiClient = ref.read(kisApiClientProvider);
    final repository = ref.read(homeRepositoryProvider);
    state = state.copyWith(
      isSyncing: true,
      syncStatus: HomeSyncStatus.authenticating,
      clearAccountSyncErrorMessage: true,
    );

    try {
      await apiClient.ensureAccessToken();
    } on KisApiException catch (error) {
      state = state.copyWith(
        isSyncing: false,
        syncStatus: HomeSyncStatus.idle,
        accountSyncErrorTitle: '토큰 발급 실패',
        accountSyncErrorMessage: _mapTokenError(error),
        lastUpdated: DateTime.now(),
      );
      await _syncRealtimeSubscriptionSafely();
      return;
    } catch (_) {
      state = state.copyWith(
        isSyncing: false,
        syncStatus: HomeSyncStatus.idle,
        accountSyncErrorTitle: '토큰 발급 실패',
        accountSyncErrorMessage: '인증 토큰 발급에 실패했습니다. 앱키와 시크릿을 확인해주세요.',
        lastUpdated: DateTime.now(),
      );
      await _syncRealtimeSubscriptionSafely();
      return;
    }

    state = state.copyWith(
      isSyncing: true,
      syncStatus: HomeSyncStatus.loadingAccount,
      clearAccountSyncErrorMessage: true,
    );

    try {
      final nextState = await repository.fetchHomeState(fallback: state);
      if (nextState == null) {
        state = state.copyWith(
          isSyncing: false,
          syncStatus: HomeSyncStatus.idle,
          accountSyncErrorTitle: '계좌 설정 필요',
          lastUpdated: DateTime.now(),
          accountSyncErrorMessage: '계좌 연동 설정이 없습니다.',
        );
        await _syncRealtimeSubscriptionSafely();
        return;
      }

      state = nextState.copyWith(
        isSyncing: false,
        syncStatus: HomeSyncStatus.idle,
      );
      await _syncRealtimeSubscriptionSafely();
    } on KisApiException catch (error) {
      state = state.copyWith(
        isSyncing: false,
        syncStatus: HomeSyncStatus.idle,
        accountSyncErrorTitle: _mapAccountErrorTitle(error),
        accountSyncErrorMessage: _mapAccountErrorMessage(error),
        lastUpdated: DateTime.now(),
      );
      await _syncRealtimeSubscriptionSafely();
    } catch (_) {
      state = state.copyWith(
        isSyncing: false,
        syncStatus: HomeSyncStatus.idle,
        accountSyncErrorTitle: '계좌 조회 실패',
        accountSyncErrorMessage: '계좌 데이터를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
        lastUpdated: DateTime.now(),
      );
      await _syncRealtimeSubscriptionSafely();
    }
  }

  void _ensureRealtimeListener() {
    if (_realtimeSubscription != null) {
      return;
    }

    final realtimeService = ref.read(kisRealtimeServiceProvider);
    _realtimeSubscription = realtimeService.stream.listen(_applyRealtimeSnapshot);
  }

  Future<void> _syncRealtimeSubscription() async {
    final realtimeService = ref.read(kisRealtimeServiceProvider);
    await realtimeService.connect(
      domesticCodes: state.domesticHoldings.map((holding) => holding.code),
    );
  }

  Future<void> _syncRealtimeSubscriptionSafely() async {
    try {
      await _syncRealtimeSubscription();
    } catch (_) {
      // Keep the initial REST data visible even if realtime socket setup fails.
    }
  }

  String _mapTokenError(KisApiException error) {
    if (error.statusCode == 401 || error.statusCode == 403) {
      return '인증이 거절되었습니다. 앱키와 시크릿이 올바른지 확인해주세요.';
    }
    return error.message;
  }

  String _mapAccountErrorTitle(KisApiException error) {
    if (error.apiCode == 'OPSQ2000' || error.message.contains('INVALID_CHECK_ACNO')) {
      return '계좌 조회 실패';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return '계좌 권한 확인 필요';
    }
    return '계좌 조회 실패';
  }

  String _mapAccountErrorMessage(KisApiException error) {
    if (error.apiCode == 'OPSQ2000' || error.message.contains('INVALID_CHECK_ACNO')) {
      return '선택한 계좌번호 또는 상품코드를 확인해주세요.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return '현재 계좌로 조회할 권한이 없거나 API 사용 설정이 필요합니다.';
    }
    return error.message;
  }

  void _applyRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    final nextMarketIndexes = state.marketIndexes.map((index) {
      if (index.name != '코스피' ||
          snapshot.kospiValue == null ||
          snapshot.kospiChangeRate == null ||
          snapshot.kospiIsPositive == null) {
        return index;
      }

      final rate = snapshot.kospiChangeRate!;
      return index.copyWith(
        value: snapshot.kospiValue!,
        changeRate: '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
        isPositive: snapshot.kospiIsPositive!,
      );
    }).toList(growable: false);

    final nextDomesticHoldings = state.domesticHoldings.map((holding) {
      final realtime = snapshot.domesticStockPrices[holding.code];
      if (realtime == null) {
        return holding;
      }

      return holding.applyRealtimePrice(
        nextPrice: realtime.currentPrice,
        nextProfitRate: realtime.changeRate,
        nextIsPositive: realtime.isPositive,
      );
    }).toList(growable: false);

    state = state.copyWith(
      marketIndexes: nextMarketIndexes,
      domesticHoldings: nextDomesticHoldings,
      lastUpdated: DateTime.now(),
    );
  }
}
