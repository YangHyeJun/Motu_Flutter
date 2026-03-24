import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'kis_api_client.dart';

enum KisRealtimeConnectionStatus { disconnected, connecting, connected, failed }

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
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class KisRealtimeSnapshot {
  const KisRealtimeSnapshot({
    required this.kospiValue,
    required this.kospiChangeRate,
    required this.kospiIsPositive,
    required this.domesticStockPrices,
  });

  final String? kospiValue;
  final double? kospiChangeRate;
  final bool? kospiIsPositive;
  final Map<String, RealtimeDomesticPrice> domesticStockPrices;
}

class RealtimeDomesticPrice {
  const RealtimeDomesticPrice({
    required this.code,
    required this.currentPrice,
    required this.changeRate,
    required this.isPositive,
  });

  final String code;
  final int currentPrice;
  final double changeRate;
  final bool isPositive;
}

class KisRealtimeService {
  KisRealtimeService(this._apiClient);

  static const _kospiCode = '0001';
  static const _domesticTradeTrId = 'H0STCNT0';
  static const _domesticIndexTrId = 'H0UPCNT0';

  final KisApiClient _apiClient;
  final StreamController<KisRealtimeSnapshot> _controller =
      StreamController<KisRealtimeSnapshot>.broadcast();
  final StreamController<KisRealtimeConnectionState> _connectionController =
      StreamController<KisRealtimeConnectionState>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Set<String> _activeDomesticCodes = const <String>{};
  KisRealtimeConnectionState _connectionState = const KisRealtimeConnectionState(
    status: KisRealtimeConnectionStatus.disconnected,
  );

  String? _kospiValue;
  double? _kospiChangeRate;
  bool? _kospiIsPositive;
  final Map<String, RealtimeDomesticPrice> _domesticPriceByCode = <String, RealtimeDomesticPrice>{};

  Stream<KisRealtimeSnapshot> get stream => _controller.stream;

  Stream<KisRealtimeConnectionState> get connectionStateStream => _connectionController.stream;

  KisRealtimeConnectionState get connectionState => _connectionState;

  Future<void> connect({required Iterable<String> domesticCodes, bool includeKospi = true}) async {
    if (!_apiClient.isConfigured) {
      await disconnect();
      return;
    }

    final nextDomesticCodes = domesticCodes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet();

    final needsReconnect = _socket == null || !_sameCodes(_activeDomesticCodes, nextDomesticCodes);

    if (!needsReconnect) {
      return;
    }

    _updateConnectionState(
      _connectionState.copyWith(
        status: KisRealtimeConnectionStatus.connecting,
        lastAttemptedAt: DateTime.now(),
        clearErrorMessage: true,
      ),
    );

    await disconnect(clearSnapshot: false);
    _domesticPriceByCode.removeWhere((code, _) => !nextDomesticCodes.contains(code));

    try {
      final approvalKey = await _apiClient.getApprovalKey(forceRefresh: true);
      final endpoint = _apiClient.useMockServer
          ? 'ws://ops.koreainvestment.com:31000'
          : 'ws://ops.koreainvestment.com:21000';

      final socket = await WebSocket.connect(endpoint);
      _socket = socket;
      _activeDomesticCodes = nextDomesticCodes;

      _socketSubscription = socket.listen(
        _handleMessage,
        onDone: () {
          _socket = null;
          _updateConnectionState(
            _connectionState.copyWith(status: KisRealtimeConnectionStatus.disconnected),
          );
        },
        onError: (_) {
          _socket = null;
          _updateConnectionState(
            _connectionState.copyWith(
              status: KisRealtimeConnectionStatus.failed,
              errorMessage: '실시간 연결이 끊어졌습니다.',
            ),
          );
        },
      );

      if (includeKospi) {
        _sendSubscription(approvalKey: approvalKey, trId: _domesticIndexTrId, trKey: _kospiCode);
      }

      for (final code in nextDomesticCodes) {
        _sendSubscription(approvalKey: approvalKey, trId: _domesticTradeTrId, trKey: code);
      }
      _updateConnectionState(
        _connectionState.copyWith(
          status: KisRealtimeConnectionStatus.connected,
          lastConnectedAt: DateTime.now(),
          clearErrorMessage: true,
        ),
      );
    } catch (_) {
      await disconnect(clearSnapshot: false);
      _updateConnectionState(
        _connectionState.copyWith(
          status: KisRealtimeConnectionStatus.failed,
          errorMessage: '실시간 연결에 실패했습니다. 다시 시도해주세요.',
        ),
      );
    }
  }

  Future<void> disconnect({bool clearSnapshot = true}) async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket = null;
    _activeDomesticCodes = const <String>{};

    if (clearSnapshot) {
      _kospiValue = null;
      _kospiChangeRate = null;
      _kospiIsPositive = null;
      _domesticPriceByCode.clear();
    }

    _updateConnectionState(
      _connectionState.copyWith(status: KisRealtimeConnectionStatus.disconnected),
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await _connectionController.close();
    await _controller.close();
  }

  void _handleMessage(dynamic rawMessage) {
    final message = rawMessage is List<int> ? utf8.decode(rawMessage) : rawMessage.toString();

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

    final chunkSize = recordCount <= 0 ? fields.length : fields.length ~/ recordCount;
    if (chunkSize <= 0) {
      return;
    }

    for (var index = 0; index + chunkSize <= fields.length; index += chunkSize) {
      final record = fields.sublist(index, index + chunkSize);
      if (trId == _domesticIndexTrId) {
        _updateKospi(record);
      } else if (trId == _domesticTradeTrId) {
        _updateDomesticPrice(record);
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
    );
  }

  void _emitSnapshot() {
    _controller.add(
      KisRealtimeSnapshot(
        kospiValue: _kospiValue,
        kospiChangeRate: _kospiChangeRate,
        kospiIsPositive: _kospiIsPositive,
        domesticStockPrices: Map<String, RealtimeDomesticPrice>.unmodifiable(_domesticPriceByCode),
      ),
    );
  }

  void _sendSubscription({
    required String approvalKey,
    required String trId,
    required String trKey,
  }) {
    _socket?.add(
      jsonEncode({
        'header': {
          'approval_key': approvalKey,
          'custtype': 'P',
          'tr_type': '1',
          'content-type': 'utf-8',
        },
        'body': {
          'input': {'tr_id': trId, 'tr_key': trKey},
        },
      }),
    );
  }

  bool _sameCodes(Set<String> currentCodes, Set<String> nextCodes) {
    if (currentCodes.length != nextCodes.length) {
      return false;
    }

    for (final code in currentCodes) {
      if (!nextCodes.contains(code)) {
        return false;
      }
    }

    return true;
  }

  void _updateConnectionState(KisRealtimeConnectionState nextState) {
    _connectionState = nextState;
    if (!_connectionController.isClosed) {
      _connectionController.add(nextState);
    }
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

    return decimal.isEmpty ? buffer.toString() : '${buffer.toString()}.$decimal';
  }

  int _toInt(String rawValue) {
    return int.tryParse(rawValue.trim()) ?? 0;
  }

  double _toDouble(String rawValue) {
    return double.tryParse(rawValue.trim()) ?? 0.0;
  }

  bool _isPositive(String? sign, double changeRate) {
    switch (sign) {
      case '1':
      case '4':
      case '5':
        return false;
      case '2':
      case '3':
        return true;
      default:
        return changeRate >= 0;
    }
  }
}
