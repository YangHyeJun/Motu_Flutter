class KisAccessToken {
  const KisAccessToken({
    required this.value,
    required this.tokenType,
    required this.expiredAt,
  });

  factory KisAccessToken.fromJson(Map<String, dynamic> json) {
    return KisAccessToken(
      value: json['access_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiredAt: DateTime.tryParse(
            json['access_token_token_expired'] as String? ?? '',
          ) ??
          DateTime.now().add(
            Duration(seconds: int.tryParse('${json['expires_in'] ?? 0}') ?? 0),
          ),
    );
  }

  final String value;
  final String tokenType;
  final DateTime expiredAt;

  bool get isExpired => DateTime.now().isAfter(expiredAt.subtract(const Duration(minutes: 5)));
}
