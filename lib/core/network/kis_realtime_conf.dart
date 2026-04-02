import 'dart:async';

import 'kis_api_client.dart';
import 'kis_realtime_service.dart';

class KisRealtimeConf {
  KisRealtimeConf(KisApiClient apiClient)
    : _service = KisRealtimeService(apiClient);

  final KisRealtimeService _service;

  Stream<KisRealtimeSnapshot> get stream => _service.stream;

  Stream<KisRealtimeConnectionState> get connectionStateStream =>
      _service.connectionStateStream;

  KisRealtimeSnapshot get snapshot => _service.snapshot;

  KisRealtimeConnectionState get connectionState => _service.connectionState;

  Future<void> setSubscription({
    required String ownerId,
    Iterable<String> domesticCodes = const <String>[],
    Iterable<String> domesticOrderBookCodes = const <String>[],
    Iterable<OverseasRealtimeTarget> overseasTargets =
        const <OverseasRealtimeTarget>[],
    Iterable<OverseasRealtimeTarget> overseasOrderBookTargets =
        const <OverseasRealtimeTarget>[],
    bool includeKospi = true,
  }) {
    return _service.setSubscription(
      ownerId: ownerId,
      domesticCodes: domesticCodes,
      domesticOrderBookCodes: domesticOrderBookCodes,
      overseasTargets: overseasTargets,
      overseasOrderBookTargets: overseasOrderBookTargets,
      includeKospi: includeKospi,
    );
  }

  Future<void> clearSubscription(String ownerId) {
    return _service.clearSubscription(ownerId);
  }

  Future<void> dispose() {
    return _service.dispose();
  }
}
