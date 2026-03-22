class MarketIndex {
  const MarketIndex({
    required this.name,
    required this.value,
    required this.changeRate,
    required this.isPositive,
  });

  final String name;
  final String value;
  final String changeRate;
  final bool isPositive;

  MarketIndex copyWith({
    String? name,
    String? value,
    String? changeRate,
    bool? isPositive,
  }) {
    return MarketIndex(
      name: name ?? this.name,
      value: value ?? this.value,
      changeRate: changeRate ?? this.changeRate,
      isPositive: isPositive ?? this.isPositive,
    );
  }
}
