import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/kis_api_client.dart';
import '../core/network/kis_api_exception.dart';
import '../core/network/kis_realtime_service.dart';
import '../models/models.dart';
import '../providers/api_provider.dart';
import 'home_view_state.dart';

class HomeViewModel extends Notifier<HomeViewState> {
  static const _subscriptionOwnerId = 'home_view_model';
  StreamSubscription<KisRealtimeSnapshot>? _realtimeSubscription;
  Timer? _marketRefreshTimer;
  static const _marketRefreshInterval = Duration(seconds: 2);
  bool _didScheduleInitialLoad = false;
  bool _isDisposed = false;
  int _deferredRefreshToken = 0;

  @override
  HomeViewState build() {
    ref.watch(selectedAccountProvider);
    _isDisposed = false;
    final realtimeConf = ref.read(kisRealtimeConfProvider);
    ref.onDispose(() {
      _isDisposed = true;
      _deferredRefreshToken++;
      _realtimeSubscription?.cancel();
      _marketRefreshTimer?.cancel();
      unawaited(realtimeConf.clearSubscription(_subscriptionOwnerId));
    });
    final initialState = _buildInitialState();
    if (!_didScheduleInitialLoad) {
      _didScheduleInitialLoad = true;
      Future<void>.microtask(() async {
        if (_isDisposed) {
          return;
        }
        _ensureRealtimeListener();
        _ensureMarketRefreshTimer();
        await _loadFromServer();
      });
    } else {
      Future<void>.microtask(() async {
        if (_isDisposed) {
          return;
        }
        await _syncRealtimeSubscriptionSafely();
      });
    }
    return initialState;
  }

  Future<void> refreshAll() async {
    await _loadFromServer();
  }

  Future<void> refreshRealtimeSections() async {
    await Future.wait([
      refreshSection(HomeSection.summary),
      refreshSection(HomeSection.market),
    ]);
  }

  Future<void> refreshSection(HomeSection section) async {
    switch (section) {
      case HomeSection.summary:
        return _refreshSummarySection();
      case HomeSection.market:
        return _refreshMarketSection();
      case HomeSection.domesticHoldings:
        return _refreshDomesticHoldingsSection();
      case HomeSection.usHoldings:
        return _refreshUsHoldingsSection();
      case HomeSection.news:
        return _refreshNewsSection();
      case HomeSection.investorFlow:
        return _refreshInvestorFlowSection();
      case HomeSection.momentum:
        return _refreshMomentumSection();
      case HomeSection.shortSell:
        return _refreshShortSellSection();
    }
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
      newsItems: const [],
      investorFlows: const [],
      domesticTopMovers: const [],
      domesticVolumeLeaders: const [],
      overseasTopMovers: const [],
      overseasVolumeLeaders: const [],
      shortSellRankings: const [],
      lastUpdated: DateTime.now(),
      isSyncing: false,
      syncStatus: HomeSyncStatus.idle,
      accountSyncErrorTitle: null,
      accountSyncErrorMessage: null,
      sectionSyncStates: {
        for (final section in HomeSection.values)
          section: HomeSectionSyncState(
            lastUpdated: DateTime.now(),
            isSyncing: false,
          ),
      },
    );
  }

  Future<void> _loadFromServer() async {
    final apiClient = ref.read(kisApiClientProvider);
    final repository = ref.read(homeRepositoryProvider);
    final refreshToken = ++_deferredRefreshToken;
    if (await _ensureConfigAndToken(apiClient) == false) {
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
        sectionSyncStates: {
          for (final section in HomeSection.values)
            section: HomeSectionSyncState(
              lastUpdated: nextState.lastUpdated,
              isSyncing: false,
            ),
        },
      );
      await _syncRealtimeSubscriptionSafely();
      unawaited(_refreshDeferredSections(refreshToken));
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

  Future<void> _refreshDeferredSections(int refreshToken) async {
    const sections = <HomeSection>[
      HomeSection.news,
      HomeSection.investorFlow,
      HomeSection.momentum,
      HomeSection.shortSell,
    ];

    for (final section in sections) {
      if (_isDisposed || refreshToken != _deferredRefreshToken) {
        return;
      }
      await refreshSection(section);
      if (_isDisposed || refreshToken != _deferredRefreshToken) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _refreshSummarySection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.summary, true);
    try {
      final summary = await repository.fetchPortfolioSummary();
      final updatedAt = DateTime.now();
      state = state.copyWith(
        summary: summary,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.summary,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
    } on KisApiException catch (error) {
      _setSectionError(HomeSection.summary, error.message);
    } catch (_) {
      _setSectionError(HomeSection.summary, '보유 자산을 다시 불러오지 못했습니다.');
    }
  }

  Future<void> _refreshMarketSection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.market, true);
    try {
      final marketIndexes = await repository.fetchMarketIndexes(
        state.marketIndexes,
      );
      final updatedAt = DateTime.now();
      state = state.copyWith(
        marketIndexes: marketIndexes,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.market,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      _setSectionError(HomeSection.market, '마켓 요약을 다시 불러오지 못했습니다.');
    }
  }

  Future<void> _refreshDomesticHoldingsSection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.domesticHoldings, true);
    try {
      final holdings = await repository.fetchDomesticHoldings();
      final updatedAt = DateTime.now();
      state = state.copyWith(
        domesticHoldings: holdings,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.domesticHoldings,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
      await _syncRealtimeSubscriptionSafely();
    } on KisApiException catch (error) {
      _setSectionError(HomeSection.domesticHoldings, error.message);
    } catch (_) {
      _setSectionError(HomeSection.domesticHoldings, '국내 보유주식을 다시 불러오지 못했습니다.');
    }
  }

  Future<void> _refreshUsHoldingsSection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.usHoldings, true);
    try {
      final holdings = await repository.fetchUsHoldings(state.usHoldings);
      final updatedAt = DateTime.now();
      state = state.copyWith(
        usHoldings: holdings,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.usHoldings,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
      await _syncRealtimeSubscriptionSafely();
    } on KisApiException catch (error) {
      _setSectionError(HomeSection.usHoldings, error.message);
    } catch (_) {
      _setSectionError(HomeSection.usHoldings, '해외 보유주식을 다시 불러오지 못했습니다.');
    }
  }

  Future<void> _refreshShortSellSection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.shortSell, true);
    try {
      final rankings = await repository.fetchShortSellRankings(
        state.shortSellRankings,
      );
      final updatedAt = DateTime.now();
      state = state.copyWith(
        shortSellRankings: rankings,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.shortSell,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      _setSectionError(HomeSection.shortSell, '공매도 순위를 다시 불러오지 못했습니다.');
    }
  }

  Future<void> _refreshNewsSection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.news, true);
    try {
      final newsItems = await repository.fetchHomeNews(state.newsItems);
      final updatedAt = DateTime.now();
      state = state.copyWith(
        newsItems: newsItems,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.news,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      _setSectionError(HomeSection.news, '뉴스를 다시 불러오지 못했습니다.');
    }
  }

  Future<void> _refreshInvestorFlowSection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.investorFlow, true);
    try {
      final investorFlows = await repository.fetchInvestorFlows(
        state.investorFlows,
      );
      final updatedAt = DateTime.now();
      state = state.copyWith(
        investorFlows: investorFlows,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.investorFlow,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      _setSectionError(HomeSection.investorFlow, '투자자 수급을 다시 불러오지 못했습니다.');
    }
  }

  Future<void> _refreshMomentumSection() async {
    if (await _ensureConfigAndToken(ref.read(kisApiClientProvider)) == false) {
      return;
    }

    final repository = ref.read(homeRepositoryProvider);
    _setSectionSyncing(HomeSection.momentum, true);
    try {
      final results = await Future.wait([
        repository.fetchDomesticTopMovers(state.domesticTopMovers),
        repository.fetchDomesticVolumeLeaders(state.domesticVolumeLeaders),
        repository.fetchOverseasTopMovers(state.overseasTopMovers),
        repository.fetchOverseasVolumeLeaders(state.overseasVolumeLeaders),
      ]);
      final updatedAt = DateTime.now();
      state = state.copyWith(
        domesticTopMovers: results[0],
        domesticVolumeLeaders: results[1],
        overseasTopMovers: results[2],
        overseasVolumeLeaders: results[3],
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.momentum,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      _setSectionError(HomeSection.momentum, '급등락/거래량 데이터를 다시 불러오지 못했습니다.');
    }
  }

  Future<bool> _ensureConfigAndToken(KisApiClient apiClient) async {
    state = state.copyWith(
      isSyncing: true,
      syncStatus: HomeSyncStatus.authenticating,
      clearAccountSyncErrorMessage: true,
    );

    try {
      await apiClient.ensureAccessToken();
      state = state.copyWith(isSyncing: false, syncStatus: HomeSyncStatus.idle);
      return true;
    } on KisApiException catch (error) {
      state = state.copyWith(
        isSyncing: false,
        syncStatus: HomeSyncStatus.idle,
        accountSyncErrorTitle: '토큰 발급 실패',
        accountSyncErrorMessage: _mapTokenError(error),
        lastUpdated: DateTime.now(),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSyncing: false,
        syncStatus: HomeSyncStatus.idle,
        accountSyncErrorTitle: '토큰 발급 실패',
        accountSyncErrorMessage: '인증 토큰 발급에 실패했습니다. 앱키와 시크릿을 확인해주세요.',
        lastUpdated: DateTime.now(),
      );
      return false;
    }
  }

  void _setSectionSyncing(HomeSection section, bool isSyncing) {
    state = state.copyWith(
      sectionSyncStates: _updatedSectionState(
        section,
        isSyncing: isSyncing,
        clearErrorMessage: isSyncing,
      ),
    );
  }

  void _setSectionError(HomeSection section, String message) {
    state = state.copyWith(
      sectionSyncStates: _updatedSectionState(
        section,
        isSyncing: false,
        errorMessage: message,
      ),
    );
  }

  Map<HomeSection, HomeSectionSyncState> _updatedSectionState(
    HomeSection section, {
    DateTime? lastUpdated,
    bool? isSyncing,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    final next = Map<HomeSection, HomeSectionSyncState>.from(
      state.sectionSyncStates,
    );
    next[section] = state
        .sectionState(section)
        .copyWith(
          lastUpdated: lastUpdated,
          isSyncing: isSyncing,
          errorMessage: errorMessage,
          clearErrorMessage: clearErrorMessage,
        );
    return next;
  }

  void _ensureRealtimeListener() {
    if (_realtimeSubscription != null) {
      return;
    }

    final realtimeConf = ref.read(kisRealtimeConfProvider);
    _applyRealtimeSnapshot(realtimeConf.snapshot);
    _realtimeSubscription = realtimeConf.stream.listen(
      _applyRealtimeSnapshot,
    );
  }

  void _ensureMarketRefreshTimer() {
    if (_marketRefreshTimer != null) {
      return;
    }

    _marketRefreshTimer = Timer.periodic(_marketRefreshInterval, (_) {
      unawaited(_refreshMarketSectionSilently());
    });
  }

  Future<void> _refreshMarketSectionSilently() async {
    if (state.sectionState(HomeSection.market).isSyncing || state.isSyncing) {
      return;
    }

    try {
      final apiClient = ref.read(kisApiClientProvider);
      await apiClient.ensureAccessToken();
      final repository = ref.read(homeRepositoryProvider);
      final marketIndexes = await repository.fetchMarketIndexes(
        state.marketIndexes,
      );
      final updatedAt = DateTime.now();
      state = state.copyWith(
        marketIndexes: marketIndexes,
        lastUpdated: updatedAt,
        sectionSyncStates: _updatedSectionState(
          HomeSection.market,
          isSyncing: false,
          lastUpdated: updatedAt,
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      // Keep the latest visible values if background polling fails.
    }
  }

  Future<void> _syncRealtimeSubscription() async {
    final realtimeConf = ref.read(kisRealtimeConfProvider);
    await realtimeConf.setSubscription(
      ownerId: _subscriptionOwnerId,
      domesticCodes: state.domesticHoldings.map((holding) => holding.code),
      overseasTargets: state.usHoldings.map(
        (holding) => OverseasRealtimeTarget(
          code: holding.code,
          exchangeCode: holding.exchangeCode ?? 'NAS',
        ),
      ),
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
    if (error.apiCode == 'OPSQ2000' ||
        error.message.contains('INVALID_CHECK_ACNO')) {
      return '계좌 조회 실패';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return '계좌 권한 확인 필요';
    }
    return '계좌 조회 실패';
  }

  String _mapAccountErrorMessage(KisApiException error) {
    if (error.apiCode == 'OPSQ2000' ||
        error.message.contains('INVALID_CHECK_ACNO')) {
      return '선택한 계좌번호 또는 상품코드를 확인해주세요.';
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      return '현재 계좌로 조회할 권한이 없거나 API 사용 설정이 필요합니다.';
    }
    return error.message;
  }

  void _applyRealtimeSnapshot(KisRealtimeSnapshot snapshot) {
    final nextMarketIndexes = state.marketIndexes
        .map((index) {
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
        })
        .toList(growable: false);

    final nextDomesticHoldings = state.domesticHoldings
        .map((holding) {
          final realtime = snapshot.domesticStockPrices[holding.code];
          if (realtime == null) {
            return holding;
          }

          return holding.applyRealtimePrice(nextPrice: realtime.currentPrice);
        })
        .toList(growable: false);

    final nextUsHoldings = state.usHoldings
        .map((holding) {
          final exchangeCode = (holding.exchangeCode ?? 'NAS').toUpperCase();
          final realtime = snapshot
              .overseasStockPrices['$exchangeCode:${holding.code.toUpperCase()}'];
          if (realtime == null) {
            return holding;
          }

          final convertedPrice = _convertOverseasRealtimePriceToKrw(
            holding: holding,
            realtime: realtime,
          );
          return holding.applyRealtimePrice(nextPrice: convertedPrice);
        })
        .toList(growable: false);

    state = state.copyWith(
      marketIndexes: nextMarketIndexes,
      domesticHoldings: nextDomesticHoldings,
      usHoldings: nextUsHoldings,
      lastUpdated: DateTime.now(),
    );
  }

  int _convertOverseasRealtimePriceToKrw({
    required HoldingStock holding,
    required RealtimeOverseasPrice realtime,
  }) {
    final exchangeRate = holding.exchangeRate;
    if (exchangeRate == null || exchangeRate <= 0) {
      return holding.currentPrice;
    }

    final scale = _pow10(realtime.priceDecimals);
    return ((realtime.currentPrice / scale) * exchangeRate).round();
  }

  int _pow10(int exponent) {
    var value = 1;
    for (var index = 0; index < exponent; index++) {
      value *= 10;
    }
    return value;
  }
}
