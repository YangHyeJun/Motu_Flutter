class KisApiException implements Exception {
  const KisApiException(this.message, {this.statusCode, this.apiCode});

  final String message;
  final int? statusCode;
  final String? apiCode;

  @override
  String toString() =>
      'KisApiException(statusCode: $statusCode, apiCode: $apiCode, message: $message)';
}
