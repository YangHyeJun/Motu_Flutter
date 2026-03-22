import '../../models/account_profile.dart';

class KisApiConfig {
  const KisApiConfig({
    required this.appKey,
    required this.appSecret,
    required this.accounts,
    required this.useMockServer,
  });

  factory KisApiConfig.fromEnvironment() {
    const legacyAccountNumber = String.fromEnvironment('KIS_ACCOUNT_NO');
    const legacyAccountProductCode = String.fromEnvironment('KIS_ACCOUNT_PRDT_CD');
    const mainAccountNumber = String.fromEnvironment('KIS_ACCOUNT_MAIN_NO');
    const mainAccountProductCode = String.fromEnvironment('KIS_ACCOUNT_MAIN_PRDT_CD');
    const isaAccountNumber = String.fromEnvironment('KIS_ACCOUNT_ISA_NO');
    const isaAccountProductCode = String.fromEnvironment('KIS_ACCOUNT_ISA_PRDT_CD');

    return KisApiConfig(
      appKey: const String.fromEnvironment('KIS_APP_KEY'),
      appSecret: const String.fromEnvironment('KIS_APP_SECRET'),
      accounts: [
        _buildAccount(
          id: 'main',
          label: '63936103-01',
          rawAccountNumber: mainAccountNumber.isNotEmpty
              ? mainAccountNumber
              : legacyAccountNumber,
          rawAccountProductCode: mainAccountProductCode.isNotEmpty
              ? mainAccountProductCode
              : legacyAccountProductCode,
          isIsa: false,
        ),
        _buildAccount(
          id: 'isa',
          label: '43299729-01 (ISA)',
          rawAccountNumber: isaAccountNumber,
          rawAccountProductCode: isaAccountProductCode,
          isIsa: true,
        ),
      ],
      useMockServer: bool.fromEnvironment('KIS_USE_MOCK', defaultValue: false),
    );
  }

  final String appKey;
  final String appSecret;
  final List<AccountProfile> accounts;
  final bool useMockServer;

  bool get isConfigured => appKey.isNotEmpty && appSecret.isNotEmpty;

  Uri resolve(String path, [Map<String, String>? queryParameters]) {
    final baseUrl = useMockServer
        ? 'https://openapivts.koreainvestment.com:29443'
        : 'https://openapi.koreainvestment.com:9443';

    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }
}

AccountProfile _buildAccount({
  required String id,
  required String label,
  required String rawAccountNumber,
  required String rawAccountProductCode,
  required bool isIsa,
}) {
  final normalizedAccountNumber = rawAccountNumber.replaceAll('-', '');
  final accountNumber = normalizedAccountNumber.length == 10
      ? normalizedAccountNumber.substring(0, 8)
      : normalizedAccountNumber;
  final accountProductCode = rawAccountProductCode.isNotEmpty
      ? rawAccountProductCode
      : normalizedAccountNumber.length == 10
          ? normalizedAccountNumber.substring(8, 10)
          : '';

  return AccountProfile(
    id: id,
    label: label,
    accountNumber: accountNumber,
    accountProductCode: accountProductCode,
    isIsa: isIsa,
  );
}
