class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.label,
    required this.accountNumber,
    required this.accountProductCode,
    required this.isIsa,
  });

  final String id;
  final String label;
  final String accountNumber;
  final String accountProductCode;
  final bool isIsa;

  bool get isConfigured =>
      accountNumber.isNotEmpty && accountProductCode.isNotEmpty;
}
