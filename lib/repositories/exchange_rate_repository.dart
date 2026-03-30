import '../core/network/kis_api_client.dart';

class ExchangeRateRepository {
  ExchangeRateRepository(this._apiClient);

  final KisApiClient _apiClient;

  Stream<double> watchUsdKrwRate({
    Duration interval = const Duration(seconds: 5),
  }) async* {
    while (true) {
      final rate = await fetchUsdKrwRate();
      if (rate > 0) {
        yield rate;
      }
      await Future<void>.delayed(interval);
    }
  }

  Future<double> fetchUsdKrwRate() async {
    final response = await _apiClient.get(
      path: '/uapi/overseas-price/v1/quotations/price-detail',
      trId: 'HHDFS76200200',
      queryParameters: {'AUTH': '', 'EXCD': 'NAS', 'SYMB': 'AAPL'},
    );

    final output =
        response['output'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return double.tryParse('${output['t_rate'] ?? ''}'.trim()) ?? 0.0;
  }
}
