class KisApiException implements Exception {
  const KisApiException(this.message, {this.statusCode, this.apiCode});

  final String message;
  final int? statusCode;
  final String? apiCode;

  @override
  String toString() =>
      'KisApiException(statusCode: $statusCode, apiCode: $apiCode, message: $message)';
}

extension KisApiExceptionPresentation on KisApiException {
  String toUserMessage({bool includeCodeForUnknown = true}) {
    final code = apiCode ?? '';
    final normalizedMessage = message.trim();

    if (code == 'EGW00202') {
      return '주문이 거래소로 정상 전달되지 않았습니다. 장 상태와 주문 가격을 확인한 뒤 다시 시도해주세요.';
    }

    if (code == 'OPSQ2000' ||
        normalizedMessage.contains('INVALID_CHECK_ACNO')) {
      return '계좌 정보가 올바르지 않습니다. 계좌번호와 상품코드를 다시 확인해주세요.';
    }

    if (_containsAny(normalizedMessage, [
      '주문 가능 금액',
      '증거금',
      '예수금',
      '잔고가 부족',
      '매수가능금액 부족',
    ])) {
      return '주문 가능 금액이 부족합니다. 예수금과 증거금을 확인해주세요.';
    }

    if (_containsAny(normalizedMessage, [
      '매도가능수량',
      '매수 가능 수량을 초과',
      '주문가능수량',
      '수량이 부족',
      '보유수량',
    ])) {
      return '주문 가능 수량을 초과했거나 보유 수량이 부족합니다. 수량을 다시 확인해주세요.';
    }

    if (_containsAny(normalizedMessage, [
      '호가단위',
      '주문단가',
      '주문 가격',
      '상한가',
      '하한가',
      '가격제한폭',
      '주문수량/호가단위 오류',
    ])) {
      return '주문 가격이 올바르지 않습니다. 호가 단위와 가격 제한 범위를 확인해주세요.';
    }

    if (_containsAny(normalizedMessage, [
      '장종료',
      '장 시작전',
      '장 시작 전',
      '장중',
      '장시간',
      '거래 가능 시간',
      '시장가 주문 불가',
      '정규장',
    ])) {
      return '현재는 주문 가능한 시간이 아닙니다. 장 운영 시간과 주문 가능 유형을 확인해주세요.';
    }

    if (_containsAny(normalizedMessage, [
      '거래서비스 미신청',
      '서비스 미신청',
      '약정',
      '거래가 제한',
      '주문이 거부',
    ])) {
      return '계좌의 거래 서비스 상태로 인해 주문할 수 없습니다. 계좌 약정과 거래 가능 상태를 확인해주세요.';
    }

    if (_containsAny(normalizedMessage, [
      '모의투자',
      '모의 투자',
      '실전투자',
      '실전 투자',
    ])) {
      return '현재 계좌 또는 서버 환경에서는 해당 주문을 지원하지 않습니다. 실전/모의 설정을 확인해주세요.';
    }

    if (statusCode == 401 || statusCode == 403) {
      return '인증이 만료되었거나 권한이 없습니다. 잠시 후 다시 시도해주세요.';
    }

    if (statusCode != null && statusCode! >= 500) {
      return '증권사 서버와 통신 중 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
    }

    if (normalizedMessage.isNotEmpty) {
      if (!includeCodeForUnknown || code.isEmpty) {
        return normalizedMessage;
      }
      return '$normalizedMessage (오류 코드: $code)';
    }

    if (includeCodeForUnknown && code.isNotEmpty) {
      return '주문 처리 중 오류가 발생했습니다. (오류 코드: $code)';
    }

    return '주문 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
  }

  bool _containsAny(String source, List<String> candidates) {
    for (final candidate in candidates) {
      if (source.contains(candidate)) {
        return true;
      }
    }
    return false;
  }
}
