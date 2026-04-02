import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/stock_detail.dart';
import 'kis_api_client.dart';

enum KisRealtimeConnectionStatus { disconnected, connecting, connected, failed }

enum _DomesticRealtimeSession { closed, preOpen, regular, afterHours }

enum _OverseasRealtimeSession {
  closed,
  daytime,
  premarket,
  regular,
  afterHours,
}

class KisRealtimeConnectionState {
  const KisRealtimeConnectionState({
    required this.status,
    this.lastAttemptedAt,
    this.lastConnectedAt,
    this.errorMessage,
  });

  final KisRealtimeConnectionStatus status;
  final DateTime? lastAttemptedAt;
  final DateTime? lastConnectedAt;
  final String? errorMessage;

  KisRealtimeConnectionState copyWith({
    KisRealtimeConnectionStatus? status,
    DateTime? lastAttemptedAt,
    DateTime? lastConnectedAt,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return KisRealtimeConnectionState(
      status: status ?? this.status,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
    );
  }
}

class KisRealtimeSnapshot {
  const KisRealtimeSnapshot({
    required this.kospiValue,
    required this.kospiChangeRate,
    required this.kospiIsPositive,
    required this.domesticStockPrices,
    required this.overseasStockPrices,
    required this.orderBooks,
  });

  final String? kospiValue;
  final double? kospiChangeRate;
  final bool? kospiIsPositive;
  final Map<String, RealtimeDomesticPrice> domesticStockPrices;
  final Map<String, RealtimeOverseasPrice> overseasStockPrices;
  final Map<String, List<StockOrderBookLevel>> orderBooks;
}

class RealtimeDomesticPrice {
  const RealtimeDomesticPrice({
    required this.code,
    required this.currentPrice,
    required this.changeRate,
    required this.isPositive,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
  });

  final String code;
  final int currentPrice;
  final double changeRate;
  final bool isPositive;
  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final int volume;
}

class OverseasRealtimeTarget {
  const OverseasRealtimeTarget({
    required this.code,
    required this.exchangeCode,
  });

  final String code;
  final String exchangeCode;

  String get key =>
      '${exchangeCode.trim().toUpperCase()}:${code.trim().toUpperCase()}';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OverseasRealtimeTarget && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

class RealtimeOverseasPrice {
  const RealtimeOverseasPrice({
    required this.code,
    required this.exchangeCode,
    required this.currentPrice,
    required this.changeRate,
    required this.isPositive,
    required this.openPrice,
    required this.highPrice,
    required this.lowPrice,
    required this.volume,
    required this.priceDecimals,
  });

  final String code;
  final String exchangeCode;
  final int currentPrice;
  final double changeRate;
  final bool isPositive;
  final int openPrice;
  final int highPrice;
  final int lowPrice;
  final int volume;
  final int priceDecimals;
}

class KisRealtimeSubscriptionRequest {
  const KisRealtimeSubscriptionRequest({
    this.domesticCodes = const <String>{},
    this.domesticOrderBookCodes = const <String>{},
    this.overseasTargets = const <OverseasRealtimeTarget>[],
    this.overseasOrderBookTargets = const <OverseasRealtimeTarget>[],
    this.includeKospi = true,
  });

  final Set<String> domesticCodes;
  final Set<String> domesticOrderBookCodes;
  final List<OverseasRealtimeTarget> overseasTargets;
  final List<OverseasRealtimeTarget> overseasOrderBookTargets;
  final bool includeKospi;

  bool get isEmpty =>
      !includeKospi &&
      domesticCodes.isEmpty &&
      domesticOrderBookCodes.isEmpty &&
      overseasTargets.isEmpty &&
      overseasOrderBookTargets.isEmpty;

  String get signature {
    final domestic = domesticCodes.toList()..sort();
    final orderBooks = domesticOrderBookCodes.toList()..sort();
    final overseas = overseasTargets.map((target) => target.key).toList()
      ..sort();
    final overseasOrderBooks = overseasOrderBookTargets
      .map((target) => target.key)
      .toList()
      ..sort();
    return [
      includeKospi ? '1' : '0',
      domestic.join(','),
      orderBooks.join(','),
      overseas.join(','),
      overseasOrderBooks.join(','),
    ].join('|');
  }
}

class KisRealtimeService {
  KisRealtimeService(this._apiClient);

  static const _kospiCode = '0001';
  static const _domesticTradeTrId = 'H0STCNT0';
  static const _domesticExpectedTradeTrId = 'H0STANC0';
  static const _domesticAfterHoursTradeTrId = 'H0STOUP0';
  static const _domesticIndexTrId = 'H0UPCNT0';
  static const _domesticOrderBookTrId = 'H0STASP0';
  static const _overseasTradeTrId = 'HDFSCNT0';
  static const _overseasOrderBookTrId = 'HDFSASP0';
  static const domesticMarketClosedMessage = '국내 주식 실시간 체결 가능 시간이 아닙니다.';
  static const overseasMarketClosedMessage =
      '미국 주식 주간거래/프리마켓/정규장/애프터마켓 시간이 아닙니다.';
  static const allMarketsClosedMessage = '국내/미국 주식 실시간 체결 가능 시간이 아닙니다.';

  final KisApiClient _apiClient;
  final StreamController<KisRealtimeSnapshot> _controller =
      StreamController<KisRealtimeSnapshot>.broadcast();
  final StreamController<KisRealtimeConnectionState> _connectionController =
      StreamController<KisRealtimeConnectionState>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Set<String> _activeDomesticCodes = const <String>{};
  Set<String> _activeDomesticOrderBookCodes = const <String>{};
  Set<String> _activeOverseasTargets = const <String>{};
  Set<String> _activeOverseasOrderBookTargets = const <String>{};
  String _activeDomesticTradeTrId = _domesticTradeTrId;
  Set<String> _requestedDomesticCodes = const <String>{};
  Set<String> _requestedDomesticOrderBookCodes = const <String>{};
  List<OverseasRealtimeTarget> _requestedOverseasRealtimeTargets =
      const <OverseasRealtimeTarget>[];
  List<OverseasRealtimeTarget> _requestedOverseasOrderBookTargets =
      const <OverseasRealtimeTarget>[];
  final Map<String, KisRealtimeSubscriptionRequest>
  _subscriptionRequestsByOwner = <String, KisRealtimeSubscriptionRequest>{};
  bool _requestedIncludeKospi = false;
  bool _shouldMaintainConnection = false;
  bool _isDisposed = false;
  bool _includeKospi = false;
  int _socketLifecycleToken = 0;
  int _reconnectAttempt = 0;
  String? _lastMergedRequestSignature;
  Future<void> _operationQueue = Future<void>.value();
  KisRealtimeConnectionState _connectionState =
      const KisRealtimeConnectionState(
        status: KisRealtimeConnectionStatus.disconnected,
      );

  String? _kospiValue;
  double? _kospiChangeRate;
  bool? _kospiIsPositive;
  final Map<String, RealtimeDomesticPrice> _domesticPriceByCode =
      <String, RealtimeDomesticPrice>{};
  final Map<String, RealtimeOverseasPrice> _overseasPriceByKey =
      <String, RealtimeOverseasPrice>{};
  final Map<String, List<StockOrderBookLevel>> _orderBooksByKey =
      <String, List<StockOrderBookLevel>>{};

  Stream<KisRealtimeSnapshot> get stream => _controller.stream;

  Stream<KisRealtimeConnectionState> get connectionStateStream =>
      _connectionController.stream;

  KisRealtimeConnectionState get connectionState => _connectionState;

  KisRealtimeSnapshot get snapshot => _buildSnapshot();

  Future<void> setSubscription({
    required String ownerId,
    Iterable<String> domesticCodes = const <String>[],
    Iterable<String> domesticOrderBookCodes = const <String>[],
    Iterable<OverseasRealtimeTarget> overseasTargets =
        const <OverseasRealtimeTarget>[],
    Iterable<OverseasRealtimeTarget> overseasOrderBookTargets =
        const <OverseasRealtimeTarget>[],
    bool includeKospi = true,
  }) async {
    await _enqueueOperation(() async {
      await _setSubscriptionInternal(
        ownerId: ownerId,
        domesticCodes: domesticCodes,
        domesticOrderBookCodes: domesticOrderBookCodes,
        overseasTargets: overseasTargets,
        overseasOrderBookTargets: overseasOrderBookTargets,
        includeKospi: includeKospi,
      );
    });
  }

  Future<void> _setSubscriptionInternal({
    required String ownerId,
    Iterable<String> domesticCodes = const <String>[],
    Iterable<String> domesticOrderBookCodes = const <String>[],
    Iterable<OverseasRealtimeTarget> overseasTargets =
        const <OverseasRealtimeTarget>[],
    Iterable<OverseasRealtimeTarget> overseasOrderBookTargets =
        const <OverseasRealtimeTarget>[],
    bool includeKospi = true,
  }) async {
    final request = KisRealtimeSubscriptionRequest(
      domesticCodes: domesticCodes
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toSet(),
      domesticOrderBookCodes: domesticOrderBookCodes
          .map((code) => code.trim())
          .where((code) => code.isNotEmpty)
          .toSet(),
      overseasTargets: [
        for (final target in overseasTargets)
          OverseasRealtimeTarget(
            code: target.code.trim().toUpperCase(),
            exchangeCode: target.exchangeCode.trim().toUpperCase(),
          ),
      ],
      overseasOrderBookTargets: [
        for (final target in overseasOrderBookTargets)
          OverseasRealtimeTarget(
            code: target.code.trim().toUpperCase(),
            exchangeCode: target.exchangeCode.trim().toUpperCase(),
          ),
      ],
      includeKospi: includeKospi,
    );

    final previousSignature = _subscriptionRequestsByOwner[ownerId]?.signature;
    if (request.isEmpty && previousSignature == null) {
      return;
    }
    if (!request.isEmpty && previousSignature == request.signature) {
      return;
    }

    if (request.isEmpty) {
      _subscriptionRequestsByOwner.remove(ownerId);
    } else {
      _subscriptionRequestsByOwner[ownerId] = request;
    }

    await _syncMergedSubscriptions();
  }

  Future<void> clearSubscription(
    String ownerId, {
    bool clearSnapshot = false,
  }) async {
    await _enqueueOperation(() async {
      await _clearSubscriptionInternal(ownerId, clearSnapshot: clearSnapshot);
    });
  }

  Future<void> _clearSubscriptionInternal(
    String ownerId, {
    bool clearSnapshot = false,
  }) async {
    final removedRequest = _subscriptionRequestsByOwner.remove(ownerId);
    if (removedRequest == null) {
      return;
    }

    await _syncMergedSubscriptions(clearSnapshotWhenEmpty: clearSnapshot);
  }

  Future<void> retrySubscriptions() async {
    await _enqueueOperation(() async {
      await _syncMergedSubscriptions(forceReconnect: true);
    });
  }

  Future<void> connect({
    Iterable<String> domesticCodes = const <String>[],
    Iterable<String> domesticOrderBookCodes = const <String>[],
    Iterable<OverseasRealtimeTarget> overseasTargets =
        const <OverseasRealtimeTarget>[],
    Iterable<OverseasRealtimeTarget> overseasOrderBookTargets =
        const <OverseasRealtimeTarget>[],
    bool includeKospi = true,
    bool forceReconnect = false,
  }) async {
    await _enqueueOperation(() async {
      await _connectInternal(
        domesticCodes: domesticCodes,
        domesticOrderBookCodes: domesticOrderBookCodes,
        overseasTargets: overseasTargets,
        overseasOrderBookTargets: overseasOrderBookTargets,
        includeKospi: includeKospi,
        forceReconnect: forceReconnect,
      );
    });
  }

  Future<void> _connectInternal({
    Iterable<String> domesticCodes = const <String>[],
    Iterable<String> domesticOrderBookCodes = const <String>[],
    Iterable<OverseasRealtimeTarget> overseasTargets =
        const <OverseasRealtimeTarget>[],
    Iterable<OverseasRealtimeTarget> overseasOrderBookTargets =
        const <OverseasRealtimeTarget>[],
    bool includeKospi = true,
    bool forceReconnect = false,
  }) async {
    _reconnectTimer?.cancel();
    if (!_apiClient.isConfigured) {
      await _disconnectFullyInternal();
      return;
    }

    final nextDomesticCodes = domesticCodes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet();
    final nextDomesticOrderBookCodes = domesticOrderBookCodes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet();
    final nextOverseasTargets = overseasTargets
        .map((target) => _overseasKey(target.exchangeCode, target.code))
        .toSet();
    final nextOverseasOrderBookTargets = overseasOrderBookTargets
        .map((target) => _overseasKey(target.exchangeCode, target.code))
        .toSet();
    _requestedDomesticCodes = nextDomesticCodes;
    _requestedDomesticOrderBookCodes = nextDomesticOrderBookCodes;
    _requestedOverseasRealtimeTargets = [
      for (final target in overseasTargets)
        OverseasRealtimeTarget(
          code: target.code.trim().toUpperCase(),
          exchangeCode: target.exchangeCode.trim().toUpperCase(),
        ),
    ];
    _requestedOverseasOrderBookTargets = [
      for (final target in overseasOrderBookTargets)
        OverseasRealtimeTarget(
          code: target.code.trim().toUpperCase(),
          exchangeCode: target.exchangeCode.trim().toUpperCase(),
        ),
    ];
    _requestedIncludeKospi = includeKospi;
    final requestedDomesticSubscription =
        includeKospi ||
        nextDomesticCodes.isNotEmpty ||
        nextDomesticOrderBookCodes.isNotEmpty;
    final requestedOverseasSubscription =
        nextOverseasTargets.isNotEmpty || nextOverseasOrderBookTargets.isNotEmpty;
    final domesticSession = _currentDomesticSession();
    final domesticOpen = domesticSession != _DomesticRealtimeSession.closed;
    final overseasSession = _currentOverseasRealtimeSession();
    final overseasOpen = overseasSession != _OverseasRealtimeSession.closed;
    final shouldSubscribeDomestic =
        requestedDomesticSubscription && domesticOpen;
    final shouldIncludeKospi =
        includeKospi && domesticSession == _DomesticRealtimeSession.regular;
    final shouldSubscribeOverseas =
        requestedOverseasSubscription && overseasOpen;
    final subscribedDomesticCodes = shouldSubscribeDomestic
        ? nextDomesticCodes
        : const <String>{};
    final subscribedDomesticOrderBookCodes =
        shouldSubscribeDomestic && _supportsDomesticOrderBook(domesticSession)
        ? nextDomesticOrderBookCodes
        : const <String>{};
    final subscribedOverseasTargets = shouldSubscribeOverseas
        ? nextOverseasTargets
        : const <String>{};
    final subscribedOverseasOrderBookTargets = shouldSubscribeOverseas
        ? nextOverseasOrderBookTargets
        : const <String>{};
    final hasAnySubscription =
        requestedDomesticSubscription || requestedOverseasSubscription;

    if (!hasAnySubscription) {
      await _disconnectFullyInternal(clearSnapshot: false);
      return;
    }
    _shouldMaintainConnection = true;

    if (!shouldSubscribeDomestic && !shouldSubscribeOverseas) {
      await _disconnectInternal(clearSnapshot: false, preserveRequested: true);
      _updateConnectionState(
        _connectionState.copyWith(
          status: KisRealtimeConnectionStatus.disconnected,
          lastAttemptedAt: DateTime.now(),
          errorMessage: _marketClosedMessageForRequest(
            requestedDomestic: requestedDomesticSubscription,
            requestedOverseas: requestedOverseasSubscription,
            domesticOpen: domesticOpen,
            overseasOpen: overseasOpen,
          ),
        ),
      );
      return;
    }

    final hasActiveSocket = _socket != null;
    final needsReconnect = forceReconnect || !hasActiveSocket;

    if (!needsReconnect) {
      try {
        final approvalKey = await _apiClient.getApprovalKey(
          forceRefresh: false,
        );
        _syncSocketSubscriptions(
          approvalKey: approvalKey,
          includeKospi: shouldIncludeKospi,
          domesticTradeTrId: _domesticTradeTrIdFor(domesticSession),
          domesticCodes: subscribedDomesticCodes,
          domesticOrderBookCodes: subscribedDomesticOrderBookCodes,
          overseasTargets: subscribedOverseasTargets,
          overseasOrderBookTargets: subscribedOverseasOrderBookTargets,
        );
        _updateConnectionState(
          _connectionState.copyWith(
            status: KisRealtimeConnectionStatus.connected,
            lastConnectedAt: DateTime.now(),
            clearErrorMessage: true,
          ),
        );
        return;
      } catch (_) {
        await _disconnectInternal(
          clearSnapshot: false,
          preserveRequested: true,
          emitDisconnectedState: false,
        );
      }
    }

    _updateConnectionState(
      _connectionState.copyWith(
        status: KisRealtimeConnectionStatus.connecting,
        lastAttemptedAt: DateTime.now(),
        clearErrorMessage: true,
      ),
    );

    await _disconnectInternal(
      clearSnapshot: false,
      preserveRequested: true,
      emitDisconnectedState: false,
    );
    _domesticPriceByCode.removeWhere(
      (code, _) => !subscribedDomesticCodes.contains(code),
    );

    try {
      final approvalKey = await _apiClient.getApprovalKey(forceRefresh: false);
      final endpoint = _apiClient.useMockServer
          ? 'ws://ops.koreainvestment.com:31000'
          : 'ws://ops.koreainvestment.com:21000';

      final socket = await WebSocket.connect(endpoint);
      final lifecycleToken = _socketLifecycleToken;
      _socket = socket;
      _activeDomesticCodes = const <String>{};
    _activeDomesticOrderBookCodes = const <String>{};
    _activeOverseasTargets = const <String>{};
    _activeOverseasOrderBookTargets = const <String>{};
    _includeKospi = false;

      _socketSubscription = socket.listen(
        _handleMessage,
        onDone: () {
          if (lifecycleToken != _socketLifecycleToken) {
            return;
          }
          _socket = null;
          _updateConnectionState(
            _connectionState.copyWith(
              status: KisRealtimeConnectionStatus.disconnected,
              errorMessage: _marketStatusMessage(),
            ),
          );
          _scheduleReconnect();
        },
        onError: (_) {
          if (lifecycleToken != _socketLifecycleToken) {
            return;
          }
          _socket = null;
          _updateConnectionState(
            _connectionState.copyWith(
              status:
                  _currentDomesticSession() !=
                          _DomesticRealtimeSession.closed ||
                      _currentOverseasRealtimeSession() !=
                          _OverseasRealtimeSession.closed
                  ? KisRealtimeConnectionStatus.failed
                  : KisRealtimeConnectionStatus.disconnected,
              errorMessage: _marketStatusMessage(),
            ),
          );
          _scheduleReconnect();
        },
      );
      _syncSocketSubscriptions(
        approvalKey: approvalKey,
        includeKospi: shouldIncludeKospi,
        domesticTradeTrId: _domesticTradeTrIdFor(domesticSession),
        domesticCodes: subscribedDomesticCodes,
        domesticOrderBookCodes: subscribedDomesticOrderBookCodes,
        overseasTargets: subscribedOverseasTargets,
        overseasOrderBookTargets: subscribedOverseasOrderBookTargets,
      );
      _updateConnectionState(
        _connectionState.copyWith(
          status: KisRealtimeConnectionStatus.connected,
          lastConnectedAt: DateTime.now(),
          clearErrorMessage: true,
        ),
      );
      _reconnectAttempt = 0;
    } catch (_) {
      await _disconnectInternal(
        clearSnapshot: false,
        preserveRequested: true,
        emitDisconnectedState: false,
      );
      _updateConnectionState(
        _connectionState.copyWith(
          status:
              _currentDomesticSession() != _DomesticRealtimeSession.closed ||
                  _currentOverseasRealtimeSession() !=
                      _OverseasRealtimeSession.closed
              ? KisRealtimeConnectionStatus.failed
              : KisRealtimeConnectionStatus.disconnected,
          errorMessage: _marketStatusMessage(),
        ),
      );
      _scheduleReconnect();
    }
  }

  Future<void> _syncMergedSubscriptions({
    bool clearSnapshotWhenEmpty = false,
    bool forceReconnect = false,
  }) async {
    final domesticCodes = <String>{};
    final domesticOrderBookCodes = <String>{};
    final overseasTargets = <String, OverseasRealtimeTarget>{};
    final overseasOrderBookTargets = <String, OverseasRealtimeTarget>{};
    var includeKospi = false;

    for (final request in _subscriptionRequestsByOwner.values) {
      domesticCodes.addAll(request.domesticCodes);
      domesticOrderBookCodes.addAll(request.domesticOrderBookCodes);
      includeKospi = includeKospi || request.includeKospi;
      for (final target in request.overseasTargets) {
        overseasTargets[_overseasKey(target.exchangeCode, target.code)] =
            target;
      }
      for (final target in request.overseasOrderBookTargets) {
        overseasOrderBookTargets[_overseasKey(target.exchangeCode, target.code)] =
            target;
      }
    }

    if (domesticCodes.isEmpty &&
        domesticOrderBookCodes.isEmpty &&
        overseasTargets.isEmpty &&
        overseasOrderBookTargets.isEmpty &&
        !includeKospi) {
      _lastMergedRequestSignature = null;
      await _disconnectFullyInternal(clearSnapshot: clearSnapshotWhenEmpty);
      return;
    }

    final mergedRequest = KisRealtimeSubscriptionRequest(
      domesticCodes: domesticCodes,
      domesticOrderBookCodes: domesticOrderBookCodes,
      overseasTargets: overseasTargets.values.toList(growable: false),
      overseasOrderBookTargets: overseasOrderBookTargets.values.toList(
        growable: false,
      ),
      includeKospi: includeKospi,
    );
    final mergedSignature = mergedRequest.signature;
    final hasLiveSocket =
        _socket != null &&
        (_connectionState.status == KisRealtimeConnectionStatus.connected ||
            _connectionState.status == KisRealtimeConnectionStatus.connecting);
    if (!forceReconnect &&
        mergedSignature == _lastMergedRequestSignature &&
        hasLiveSocket) {
      return;
    }
    _lastMergedRequestSignature = mergedSignature;

    await _connectInternal(
      domesticCodes: domesticCodes,
      domesticOrderBookCodes: domesticOrderBookCodes,
      overseasTargets: overseasTargets.values,
      overseasOrderBookTargets: overseasOrderBookTargets.values,
      includeKospi: includeKospi,
      forceReconnect: forceReconnect,
    );
  }

  Future<void> disconnect({bool clearSnapshot = true}) async {
    await _enqueueOperation(() async {
      await _disconnectFullyInternal(clearSnapshot: clearSnapshot);
    });
  }

  Future<void> _disconnectFullyInternal({bool clearSnapshot = true}) async {
    _shouldMaintainConnection = false;
    _lastMergedRequestSignature = null;
    _reconnectAttempt = 0;
    _requestedDomesticCodes = const <String>{};
    _requestedDomesticOrderBookCodes = const <String>{};
    _requestedOverseasRealtimeTargets = const <OverseasRealtimeTarget>[];
    _subscriptionRequestsByOwner.clear();
    _requestedIncludeKospi = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _disconnectInternal(clearSnapshot: clearSnapshot);
  }

  Future<void> _disconnectInternal({
    bool clearSnapshot = true,
    bool preserveRequested = false,
    bool emitDisconnectedState = true,
  }) async {
    _socketLifecycleToken++;
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _activeDomesticCodes = const <String>{};
    _activeDomesticOrderBookCodes = const <String>{};
    _activeOverseasTargets = const <String>{};
    _activeOverseasOrderBookTargets = const <String>{};
    _activeDomesticTradeTrId = _domesticTradeTrId;
    _includeKospi = false;
    if (!preserveRequested) {
      _requestedDomesticCodes = const <String>{};
      _requestedDomesticOrderBookCodes = const <String>{};
      _requestedOverseasRealtimeTargets = const <OverseasRealtimeTarget>[];
      _requestedOverseasOrderBookTargets = const <OverseasRealtimeTarget>[];
      _requestedIncludeKospi = false;
    }

    if (clearSnapshot) {
      _kospiValue = null;
      _kospiChangeRate = null;
      _kospiIsPositive = null;
      _domesticPriceByCode.clear();
      _overseasPriceByKey.clear();
      _orderBooksByKey.clear();
    }

    if (emitDisconnectedState) {
      _updateConnectionState(
        _connectionState.copyWith(
          status: KisRealtimeConnectionStatus.disconnected,
        ),
      );
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await _disconnectFullyInternal();
    await _connectionController.close();
    await _controller.close();
  }

  void _scheduleReconnect() {
    if (_isDisposed || !_shouldMaintainConnection) {
      return;
    }
    if (_reconnectTimer?.isActive ?? false) {
      return;
    }

    final domesticRequested =
        _requestedIncludeKospi ||
        _requestedDomesticCodes.isNotEmpty ||
        _requestedDomesticOrderBookCodes.isNotEmpty;
    final overseasRequested =
        _requestedOverseasRealtimeTargets.isNotEmpty ||
        _requestedOverseasOrderBookTargets.isNotEmpty;
    if (!domesticRequested && !overseasRequested) {
      return;
    }

    final delaySeconds = math.min(30, 1 << _reconnectAttempt);
    _reconnectAttempt = math.min(_reconnectAttempt + 1, 5);
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isDisposed || !_shouldMaintainConnection) {
        return;
      }
      unawaited(
        _enqueueOperation(() async {
          await _syncMergedSubscriptions(forceReconnect: true);
        }),
      );
    });
  }

  Future<void> _enqueueOperation(Future<void> Function() action) {
    final nextOperation = _operationQueue
        .catchError((Object _) {})
        .then((_) => action());
    _operationQueue = nextOperation.catchError((Object _) {});
    return nextOperation;
  }

  void _handleMessage(dynamic rawMessage) {
    final message = rawMessage is List<int>
        ? utf8.decode(rawMessage)
        : rawMessage.toString();

    if (message.contains('PINGPONG')) {
      _socket?.add(message);
      return;
    }

    if (message.startsWith('0|')) {
      _handleRealtimePayload(message);
    }
  }

  void _handleRealtimePayload(String message) {
    final parts = message.split('|');
    if (parts.length < 4) {
      return;
    }

    final trId = parts[1];
    final recordCount = int.tryParse(parts[2]) ?? 1;
    final fields = parts[3].split('^');
    if (fields.isEmpty) {
      return;
    }

    final chunkSize = recordCount <= 0
        ? fields.length
        : fields.length ~/ recordCount;
    if (chunkSize <= 0) {
      return;
    }

    for (
      var index = 0;
      index + chunkSize <= fields.length;
      index += chunkSize
    ) {
      final record = fields.sublist(index, index + chunkSize);
      if (trId == _domesticIndexTrId) {
        _updateKospi(record);
      } else if (_isDomesticTradeTrId(trId)) {
        _updateDomesticPrice(record);
      } else if (trId == _domesticOrderBookTrId) {
        _updateDomesticOrderBook(record);
      } else if (trId == _overseasTradeTrId) {
        _updateOverseasPrice(record);
      } else if (trId == _overseasOrderBookTrId) {
        _updateOverseasOrderBook(record);
      }
    }

    _emitSnapshot();
  }

  void _updateKospi(List<String> record) {
    if (record.length < 10) {
      return;
    }

    final value = _formatIndexValue(record[2]);
    final changeRate = _toDouble(record[9]);
    _kospiValue = value;
    _kospiChangeRate = changeRate;
    _kospiIsPositive = _isPositive(record[3], changeRate);
  }

  void _updateDomesticPrice(List<String> record) {
    if (record.length < 6) {
      return;
    }

    final code = record[0].trim();
    if (code.isEmpty) {
      return;
    }

    _domesticPriceByCode[code] = RealtimeDomesticPrice(
      code: code,
      currentPrice: _toInt(record[2]),
      changeRate: _toDouble(record[5]),
      isPositive: _isPositive(record[3], _toDouble(record[5])),
      openPrice: _toInt(record[7]),
      highPrice: _toInt(record[8]),
      lowPrice: _toInt(record[9]),
      volume: record.length > 13 ? _toInt(record[13]) : 0,
    );
  }

  void _updateDomesticOrderBook(List<String> record) {
    if (record.length < 43) {
      return;
    }

    final code = record[0].trim();
    if (code.isEmpty) {
      return;
    }

    _orderBooksByKey[_domesticOrderBookKey(
      code,
    )] = List<StockOrderBookLevel>.generate(
      10,
      (index) => StockOrderBookLevel(
        askPrice: _toInt(record[3 + index]),
        askVolume: _toInt(record[23 + index]),
        bidPrice: _toInt(record[13 + index]),
        bidVolume: _toInt(record[33 + index]),
      ),
      growable: false,
    );
  }

  void _updateOverseasPrice(List<String> record) {
    if (record.length < 21) {
      return;
    }

    final composite = record[0].trim();
    final code = _extractOverseasCode(composite);
    final exchangeCode = _extractOverseasExchangeCode(composite);
    if (code.isEmpty || exchangeCode.isEmpty) {
      return;
    }

    final parsedDecimals = _toInt(record[1]);
    final decimals = parsedDecimals > 0
        ? parsedDecimals
        : _detectDecimalPlaces(record[11]);
    final currentPrice = _scaledOverseasPrice(record[11], decimals);
    final diffPrice = _scaledOverseasPrice(record[13], decimals);
    final signedDiffPrice = _applySignedOverseasDiff(
      diffPrice,
      sign: record[12],
    );
    final previousClosePrice = currentPrice - signedDiffPrice;
    final changeRate = previousClosePrice > 0
        ? (signedDiffPrice / previousClosePrice) * 100
        : _toDouble(record[14]);
    final key = _overseasKey(exchangeCode, code);
    final previous = _overseasPriceByKey[key];
    final next = RealtimeOverseasPrice(
      code: code,
      exchangeCode: exchangeCode,
      currentPrice: currentPrice,
      changeRate: changeRate,
      isPositive: previousClosePrice > 0
          ? signedDiffPrice >= 0
          : _isPositive(record[12], changeRate),
      openPrice: _scaledOverseasPrice(record[8], decimals),
      highPrice: _scaledOverseasPrice(record[9], decimals),
      lowPrice: _scaledOverseasPrice(record[10], decimals),
      volume: _toInt(record[20]),
      priceDecimals: decimals,
    );
    _overseasPriceByKey[key] = next;

    if (kDebugMode &&
        (previous == null ||
            previous.currentPrice != next.currentPrice ||
            previous.volume != next.volume ||
            previous.priceDecimals != next.priceDecimals)) {
      debugPrint(
        '[Realtime][Overseas] key=$key currentRaw=${record[11]} current=${next.currentPrice} '
        'diffRaw=${record[13]} diff=$signedDiffPrice sign=${record[12]} rateRaw=${record[14]} '
        'volumeRaw=${record[20]} volume=${next.volume} decimals=${next.priceDecimals} '
        'prevPrice=${previous?.currentPrice} prevVolume=${previous?.volume}',
      );
    }
  }

  void _updateOverseasOrderBook(List<String> record) {
    if (record.length < 71) {
      return;
    }

    final composite = record[0].trim();
    final code = _extractOverseasCode(composite);
    final exchangeCode = _extractOverseasExchangeCode(composite);
    if (code.isEmpty || exchangeCode.isEmpty) {
      return;
    }

    final decimals = _toInt(record[2]);
    final levels = <StockOrderBookLevel>[];
    for (var index = 0; index < 10; index++) {
      final start = 11 + (index * 6);
      if (start + 5 >= record.length) {
        break;
      }
      levels.add(
        StockOrderBookLevel(
          askPrice: _scaledOverseasPrice(record[start + 1], decimals),
          askVolume: _toInt(record[start + 3]),
          bidPrice: _scaledOverseasPrice(record[start], decimals),
          bidVolume: _toInt(record[start + 2]),
        ),
      );
    }

    _orderBooksByKey[_overseasOrderBookKey(exchangeCode, code)] =
        List<StockOrderBookLevel>.unmodifiable(levels);
  }

  void _emitSnapshot() {
    _controller.add(_buildSnapshot());
  }

  KisRealtimeSnapshot _buildSnapshot() {
    return KisRealtimeSnapshot(
      kospiValue: _kospiValue,
      kospiChangeRate: _kospiChangeRate,
      kospiIsPositive: _kospiIsPositive,
      domesticStockPrices: Map<String, RealtimeDomesticPrice>.unmodifiable(
        _domesticPriceByCode,
      ),
      overseasStockPrices: Map<String, RealtimeOverseasPrice>.unmodifiable(
        _overseasPriceByKey,
      ),
      orderBooks: Map<String, List<StockOrderBookLevel>>.unmodifiable(
        _orderBooksByKey.map(
          (key, value) =>
              MapEntry(key, List<StockOrderBookLevel>.unmodifiable(value)),
        ),
      ),
    );
  }

  void _sendSubscription({
    required String approvalKey,
    required String trId,
    required String trKey,
    String trType = '1',
  }) {
    _socket?.add(
      jsonEncode({
        'header': {
          'approval_key': approvalKey,
          'custtype': 'P',
          'tr_type': trType,
          'content-type': 'utf-8',
        },
        'body': {
          'input': {'tr_id': trId, 'tr_key': trKey},
        },
      }),
    );
  }

  void _syncSocketSubscriptions({
    required String approvalKey,
    required bool includeKospi,
    required String domesticTradeTrId,
    required Set<String> domesticCodes,
    required Set<String> domesticOrderBookCodes,
    required Set<String> overseasTargets,
    required Set<String> overseasOrderBookTargets,
  }) {
    if (_includeKospi && !includeKospi) {
      _sendSubscription(
        approvalKey: approvalKey,
        trId: _domesticIndexTrId,
        trKey: _kospiCode,
        trType: '2',
      );
    } else if (!_includeKospi && includeKospi) {
      _sendSubscription(
        approvalKey: approvalKey,
        trId: _domesticIndexTrId,
        trKey: _kospiCode,
      );
    }

    if (_activeDomesticTradeTrId != domesticTradeTrId) {
      _syncCodeSubscriptions(
        approvalKey: approvalKey,
        trId: _activeDomesticTradeTrId,
        currentCodes: _activeDomesticCodes,
        nextCodes: const <String>{},
      );
      _syncCodeSubscriptions(
        approvalKey: approvalKey,
        trId: domesticTradeTrId,
        currentCodes: const <String>{},
        nextCodes: domesticCodes,
      );
    } else {
      _syncCodeSubscriptions(
        approvalKey: approvalKey,
        trId: domesticTradeTrId,
        currentCodes: _activeDomesticCodes,
        nextCodes: domesticCodes,
      );
    }
    _syncCodeSubscriptions(
      approvalKey: approvalKey,
      trId: _domesticOrderBookTrId,
      currentCodes: _activeDomesticOrderBookCodes,
      nextCodes: domesticOrderBookCodes,
    );
    _syncCodeSubscriptions(
      approvalKey: approvalKey,
      trId: _overseasTradeTrId,
      currentCodes: _activeOverseasTargets,
      nextCodes: overseasTargets,
      transformTrKey: _buildOverseasRealtimeKeyFromKey,
    );
    _syncCodeSubscriptions(
      approvalKey: approvalKey,
      trId: _overseasOrderBookTrId,
      currentCodes: _activeOverseasOrderBookTargets,
      nextCodes: overseasOrderBookTargets,
      transformTrKey: _buildOverseasRealtimeKeyFromKey,
    );

    _activeDomesticTradeTrId = domesticTradeTrId;
    _includeKospi = includeKospi;
    _activeDomesticCodes = domesticCodes;
    _activeDomesticOrderBookCodes = domesticOrderBookCodes;
    _activeOverseasTargets = overseasTargets;
    _activeOverseasOrderBookTargets = overseasOrderBookTargets;
  }

  void _syncCodeSubscriptions({
    required String approvalKey,
    required String trId,
    required Set<String> currentCodes,
    required Set<String> nextCodes,
    String Function(String value)? transformTrKey,
  }) {
    for (final code in currentCodes) {
      if (nextCodes.contains(code)) {
        continue;
      }
      _sendSubscription(
        approvalKey: approvalKey,
        trId: trId,
        trKey: transformTrKey?.call(code) ?? code,
        trType: '2',
      );
    }

    for (final code in nextCodes) {
      if (currentCodes.contains(code)) {
        continue;
      }
      _sendSubscription(
        approvalKey: approvalKey,
        trId: trId,
        trKey: transformTrKey?.call(code) ?? code,
      );
    }
  }

  String _buildOverseasRealtimeKey({
    required String exchangeCode,
    required String code,
  }) {
    final normalizedExchange = _normalizeOverseasExchangeCode(exchangeCode);
    final overseasSession = _currentOverseasRealtimeSession();
    if (overseasSession == _OverseasRealtimeSession.daytime) {
      final daytimeExchange = switch (normalizedExchange) {
        'NAS' || 'BAQ' => 'BAQ',
        'NYS' || 'BAY' => 'BAY',
        'AMS' || 'BAA' => 'BAA',
        _ => null,
      };
      if (daytimeExchange != null) {
        return 'R$daytimeExchange${code.trim().toUpperCase()}';
      }
    }
    return 'D$normalizedExchange${code.trim().toUpperCase()}';
  }

  String _buildOverseasRealtimeKeyFromKey(String rawKey) {
    final parts = rawKey.split(':');
    if (parts.length != 2) {
      return rawKey;
    }
    return _buildOverseasRealtimeKey(
      exchangeCode: parts.first,
      code: parts.last,
    );
  }

  String _extractOverseasExchangeCode(String rawKey) {
    if (rawKey.length < 4) {
      return '';
    }
    final exchange = rawKey.substring(1, 4).toUpperCase();
    switch (exchange) {
      case 'BAQ':
        return 'NAS';
      case 'BAY':
        return 'NYS';
      case 'BAA':
        return 'AMS';
      default:
        return exchange;
    }
  }

  String _extractOverseasCode(String rawKey) {
    if (rawKey.length <= 4) {
      return '';
    }
    return rawKey.substring(4).trim().toUpperCase();
  }

  int _scaledOverseasPrice(String rawValue, int decimals) {
    final numeric = double.tryParse(rawValue.trim());
    if (numeric == null) {
      return 0;
    }

    return (numeric * _pow10(decimals)).round();
  }

  int _detectDecimalPlaces(String rawValue) {
    final trimmed = rawValue.trim();
    final decimalIndex = trimmed.indexOf('.');
    if (decimalIndex < 0) {
      return 0;
    }
    return trimmed.length - decimalIndex - 1;
  }

  int _pow10(int exponent) {
    var value = 1;
    for (var index = 0; index < exponent; index++) {
      value *= 10;
    }
    return value;
  }

  String _domesticOrderBookKey(String code) => 'domestic:$code';

  String _overseasOrderBookKey(String exchangeCode, String code) =>
      'overseas:${_overseasKey(exchangeCode, code)}';

  String _overseasKey(String exchangeCode, String code) =>
      '${_normalizeOverseasExchangeCode(exchangeCode)}:${code.trim().toUpperCase()}';

  String _normalizeOverseasExchangeCode(String exchangeCode) {
    switch (exchangeCode.trim().toUpperCase()) {
      case 'NASD':
      case 'BAQ':
        return 'NAS';
      case 'NYSE':
      case 'BAY':
        return 'NYS';
      case 'AMEX':
      case 'BAA':
        return 'AMS';
      default:
        return exchangeCode.trim().toUpperCase();
    }
  }

  void _updateConnectionState(KisRealtimeConnectionState nextState) {
    _connectionState = nextState;
    if (!_connectionController.isClosed) {
      _connectionController.add(nextState);
    }
  }

  String _marketStatusMessage() {
    final hasDomestic = _includeKospi || _activeDomesticCodes.isNotEmpty;
    final hasOverseas = _activeOverseasTargets.isNotEmpty;
    final domesticOpen =
        !hasDomestic ||
        _currentDomesticSession() != _DomesticRealtimeSession.closed;
    final overseasOpen =
        !hasOverseas ||
        _currentOverseasRealtimeSession() != _OverseasRealtimeSession.closed;
    if (!domesticOpen || !overseasOpen) {
      return _marketClosedMessageForRequest(
        requestedDomestic: hasDomestic,
        requestedOverseas: hasOverseas,
        domesticOpen: domesticOpen,
        overseasOpen: overseasOpen,
      );
    }
    return '실시간 연결이 끊어졌습니다.';
  }

  _DomesticRealtimeSession _currentDomesticSession([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (current.weekday == DateTime.saturday ||
        current.weekday == DateTime.sunday) {
      return _DomesticRealtimeSession.closed;
    }

    final minuteOfDay = (current.hour * 60) + current.minute;
    const preOpenStartMinute = (8 * 60) + 30;
    const marketOpenMinute = 9 * 60;
    const marketCloseMinute = (15 * 60) + 30;
    const afterHoursStartMinute = 16 * 60;
    const afterHoursEndMinute = 18 * 60;

    if (minuteOfDay >= preOpenStartMinute && minuteOfDay < marketOpenMinute) {
      return _DomesticRealtimeSession.preOpen;
    }
    if (minuteOfDay >= marketOpenMinute && minuteOfDay < marketCloseMinute) {
      return _DomesticRealtimeSession.regular;
    }
    if (minuteOfDay >= afterHoursStartMinute &&
        minuteOfDay < afterHoursEndMinute) {
      return _DomesticRealtimeSession.afterHours;
    }
    return _DomesticRealtimeSession.closed;
  }

  _OverseasRealtimeSession _currentOverseasRealtimeSession([DateTime? now]) {
    final current = now ?? DateTime.now();
    if (current.weekday == DateTime.saturday ||
        current.weekday == DateTime.sunday) {
      return _OverseasRealtimeSession.closed;
    }

    final koreaMinuteOfDay = (current.hour * 60) + current.minute;
    const daytimeStartMinute = 10 * 60;
    const daytimeEndMinute = 18 * 60;
    if (koreaMinuteOfDay >= daytimeStartMinute &&
        koreaMinuteOfDay < daytimeEndMinute) {
      return _OverseasRealtimeSession.daytime;
    }

    final utcNow = (now ?? DateTime.now()).toUtc();
    final easternOffsetHours = _isUsDaylightSavingTime(utcNow) ? -4 : -5;
    final easternNow = utcNow.add(Duration(hours: easternOffsetHours));
    if (easternNow.weekday == DateTime.saturday ||
        easternNow.weekday == DateTime.sunday) {
      return _OverseasRealtimeSession.closed;
    }

    final minuteOfDay = (easternNow.hour * 60) + easternNow.minute;
    const premarketOpenMinute = 4 * 60;
    const marketOpenMinute = (9 * 60) + 30;
    const marketCloseMinute = 16 * 60;
    const afterHoursCloseMinute = 20 * 60;
    if (minuteOfDay >= premarketOpenMinute && minuteOfDay < marketOpenMinute) {
      return _OverseasRealtimeSession.premarket;
    }
    if (minuteOfDay >= marketOpenMinute && minuteOfDay < marketCloseMinute) {
      return _OverseasRealtimeSession.regular;
    }
    if (minuteOfDay >= marketCloseMinute &&
        minuteOfDay < afterHoursCloseMinute) {
      return _OverseasRealtimeSession.afterHours;
    }

    return _OverseasRealtimeSession.closed;
  }

  bool _isUsDaylightSavingTime(DateTime utcNow) {
    final year = utcNow.year;
    final dstStartDay = _nthWeekdayOfMonth(
      year: year,
      month: 3,
      weekday: DateTime.sunday,
      occurrence: 2,
    );
    final dstEndDay = _nthWeekdayOfMonth(
      year: year,
      month: 11,
      weekday: DateTime.sunday,
      occurrence: 1,
    );
    final dstStartUtc = DateTime.utc(year, 3, dstStartDay, 7);
    final dstEndUtc = DateTime.utc(year, 11, dstEndDay, 6);
    return !utcNow.isBefore(dstStartUtc) && utcNow.isBefore(dstEndUtc);
  }

  int _nthWeekdayOfMonth({
    required int year,
    required int month,
    required int weekday,
    required int occurrence,
  }) {
    final firstDay = DateTime.utc(year, month, 1);
    final offset = (weekday - firstDay.weekday + 7) % 7;
    return 1 + offset + ((occurrence - 1) * 7);
  }

  String _marketClosedMessageForRequest({
    required bool requestedDomestic,
    required bool requestedOverseas,
    required bool domesticOpen,
    required bool overseasOpen,
  }) {
    final domesticClosed = requestedDomestic && !domesticOpen;
    final overseasClosed = requestedOverseas && !overseasOpen;
    if (domesticClosed && overseasClosed) {
      return allMarketsClosedMessage;
    }
    if (domesticClosed) {
      return domesticMarketClosedMessage;
    }
    if (overseasClosed) {
      return overseasMarketClosedMessage;
    }
    return '실시간 연결이 끊어졌습니다.';
  }

  String _formatIndexValue(String rawValue) {
    final numeric = double.tryParse(rawValue.trim());
    if (numeric == null) {
      return rawValue;
    }

    final fixed = numeric.toStringAsFixed(2);
    final parts = fixed.split('.');
    final whole = parts.first;
    final decimal = parts.length > 1 ? parts[1] : '';
    final buffer = StringBuffer();

    for (var index = 0; index < whole.length; index++) {
      final reversedIndex = whole.length - index;
      buffer.write(whole[index]);
      if (reversedIndex > 1 && reversedIndex % 3 == 1) {
        buffer.write(',');
      }
    }

    return decimal.isEmpty
        ? buffer.toString()
        : '${buffer.toString()}.$decimal';
  }

  int _toInt(String rawValue) {
    return int.tryParse(rawValue.trim()) ?? 0;
  }

  double _toDouble(String rawValue) {
    return double.tryParse(rawValue.trim()) ?? 0.0;
  }

  int _applySignedOverseasDiff(int diffPrice, {String? sign}) {
    switch ((sign ?? '').trim()) {
      case '4':
      case '5':
        return -diffPrice;
      default:
        return diffPrice;
    }
  }

  bool _isPositive(String? sign, double changeRate) {
    switch (sign) {
      case '4':
      case '5':
        return false;
      case '1':
      case '2':
        return true;
      case '3':
        return false;
      default:
        return changeRate >= 0;
    }
  }

  bool _supportsDomesticOrderBook(_DomesticRealtimeSession session) {
    return session == _DomesticRealtimeSession.regular;
  }

  String _domesticTradeTrIdFor(_DomesticRealtimeSession session) {
    switch (session) {
      case _DomesticRealtimeSession.preOpen:
        return _domesticExpectedTradeTrId;
      case _DomesticRealtimeSession.afterHours:
        return _domesticAfterHoursTradeTrId;
      case _DomesticRealtimeSession.regular:
      case _DomesticRealtimeSession.closed:
        return _domesticTradeTrId;
    }
  }

  bool _isDomesticTradeTrId(String trId) {
    return trId == _domesticTradeTrId ||
        trId == _domesticExpectedTradeTrId ||
        trId == _domesticAfterHoursTradeTrId;
  }
}
