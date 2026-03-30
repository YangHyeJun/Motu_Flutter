class HomeInvestorFlow {
  const HomeInvestorFlow({
    required this.marketLabel,
    required this.foreignNetBuyAmount,
    required this.institutionNetBuyAmount,
    required this.individualNetBuyAmount,
  });

  final String marketLabel;
  final int foreignNetBuyAmount;
  final int institutionNetBuyAmount;
  final int individualNetBuyAmount;
}
