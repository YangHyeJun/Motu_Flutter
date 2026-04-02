import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/api_provider.dart';
import '../../providers/home_provider.dart';
import '../../viewmodels/more_view_model.dart';
import '../widgets/common_widgets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(availableAccountsProvider);
    final selectedAccount = ref.watch(selectedAccountProvider);
    final themeMode = ref.watch(themeModeProvider);
    final moreViewModel = ref.watch(moreViewModelProvider);

    final items = [
      (
        '계좌 선택',
        selectedAccount?.label ?? '선택 가능한 계좌 없음',
        Icons.account_balance_wallet_outlined,
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccountSelectionScreen()),
        ),
      ),
      (
        '보유 주식 물타기',
        '추가 매수 시 평균단가와 손익 변화를 계산합니다',
        Icons.calculate_outlined,
        () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AveragingDownStocksScreen(
              viewModel: moreViewModel,
            ),
          ),
        ),
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '더보기',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 16),
          if (accounts.isEmpty) ...[
            const _MissingAccountConfigCard(),
            const SizedBox(height: 16),
          ],
          _ThemeModeCard(
            selectedMode: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setThemeMode(mode),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.$3),
                  title: Text(item.$1),
                  subtitle: Text(item.$2),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: item.$4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AveragingDownStocksScreen extends ConsumerWidget {
  const AveragingDownStocksScreen({super.key, required this.viewModel});

  final MoreViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final notifier = ref.read(homeViewModelProvider.notifier);
    final holdings = viewModel.sortedHoldings([
      ...state.domesticHoldings,
      ...state.usHoldings,
    ]);

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('보유 주식 물타기')),
      body: RefreshIndicator(
        onRefresh: notifier.refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const InfoBanner(
              message: '보유 종목을 선택해 추가 매수 후 평균단가와 현재가 기준 손익 변화를 계산합니다.',
            ),
            const SizedBox(height: 16),
            if (holdings.isEmpty)
              AppCard(
                child: Text(
                  '보유 주식이 없습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...holdings.map(
                (holding) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkSurfaceSoft
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          holding.marketType == StockMarketType.domestic
                              ? '국내'
                              : '해외',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      title: Text(holding.name),
                      subtitle: Text(
                        '${holding.quantity}주  •  평균 ${viewModel.formatHoldingPrice(holding.buyPrice, holding)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AveragingDownCalculatorScreen(
                            stock: holding,
                            viewModel: viewModel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AveragingDownCalculatorScreen extends StatefulWidget {
  const AveragingDownCalculatorScreen({
    super.key,
    required this.stock,
    required this.viewModel,
  });

  final HoldingStock stock;
  final MoreViewModel viewModel;

  @override
  State<AveragingDownCalculatorScreen> createState() =>
      _AveragingDownCalculatorScreenState();
}

class _AveragingDownCalculatorScreenState
    extends State<AveragingDownCalculatorScreen> {
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _targetAveragePriceController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController();
    _priceController = TextEditingController(
      text: widget.stock.currentPrice.toString(),
    );
    _targetAveragePriceController = TextEditingController();
    _quantityController.addListener(_handleInputChanged);
    _priceController.addListener(_handleInputChanged);
    _targetAveragePriceController.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _quantityController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _priceController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _targetAveragePriceController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final calculation = widget.viewModel.buildAveragingDownCalculation(
      stock: stock,
      quantityText: _quantityController.text,
      priceText: _priceController.text,
      targetAveragePriceText: _targetAveragePriceController.text,
    );
    final targetPlan = calculation.targetPlan;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('${stock.name} 물타기')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissKeyboard,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stock.code}  •  ${stock.quantity}주 보유',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CalculatorStatRow(
                    label: '현재 평균단가',
                    value: widget.viewModel.formatHoldingPrice(
                      stock.buyPrice,
                      stock,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CalculatorStatRow(
                    label: '현재가',
                    value: widget.viewModel.formatHoldingPrice(
                      stock.currentPrice,
                      stock,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CalculatorStatRow(
                    label: '현재 수익률',
                    value:
                        '${stock.profitRate >= 0 ? '+' : '-'}${stock.profitRate.abs().toStringAsFixed(2)}%',
                    valueColor: stock.profitRate >= 0
                        ? AppColors.positive
                        : AppColors.negative,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '추가 매수 입력'),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) => _dismissKeyboard(),
                    decoration: const InputDecoration(
                      labelText: '추가 매수 수량',
                      hintText: '예: 10',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) => _dismissKeyboard(),
                    decoration: InputDecoration(
                      labelText: '추가 매수 단가',
                      hintText: stock.currentPrice.toString(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _targetAveragePriceController,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) => _dismissKeyboard(),
                    decoration: const InputDecoration(
                      labelText: '목표 평균단가',
                      hintText: '예: 65000',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '계산 결과'),
                  const SizedBox(height: 14),
                  _CalculatorStatRow(
                    label: '추가 매수 금액',
                    value: widget.viewModel.formatHoldingPrice(
                      calculation.additionalInvested,
                      stock,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CalculatorStatRow(
                    label: '총 보유 수량',
                    value: '${calculation.totalQuantity}주',
                  ),
                  const SizedBox(height: 10),
                  _CalculatorStatRow(
                    label: '새 평균단가',
                    value: widget.viewModel.formatHoldingPrice(
                      calculation.nextAveragePrice,
                      stock,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CalculatorStatRow(
                    label: '현재가 기준 손익',
                    value:
                        '${calculation.nextProfitAmount >= 0 ? '+' : '-'}${widget.viewModel.formatHoldingPrice(calculation.nextProfitAmount.abs(), stock)}',
                    valueColor: calculation.nextProfitAmount >= 0
                        ? AppColors.positive
                        : AppColors.negative,
                  ),
                  const SizedBox(height: 10),
                  _CalculatorStatRow(
                    label: '현재가 기준 수익률',
                    value:
                        '${calculation.nextProfitRate >= 0 ? '+' : '-'}${calculation.nextProfitRate.abs().toStringAsFixed(2)}%',
                    valueColor: calculation.nextProfitRate >= 0
                        ? AppColors.positive
                        : AppColors.negative,
                  ),
                  const SizedBox(height: 10),
                  _CalculatorStatRow(
                    label: '본전까지 필요 등락률',
                    value:
                        '${calculation.breakEvenRate >= 0 ? '+' : '-'}${calculation.breakEvenRate.abs().toStringAsFixed(2)}%',
                    valueColor: calculation.breakEvenRate <= 0
                        ? AppColors.positive
                        : AppColors.negative,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: '목표 평균단가 기준 계산'),
                  const SizedBox(height: 14),
                  if (targetPlan.message != null)
                    Text(
                      targetPlan.message!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    )
                  else ...[
                    _CalculatorStatRow(
                      label: '필요 매수 수량',
                      value: '${targetPlan.requiredQuantity}주',
                    ),
                    const SizedBox(height: 10),
                    _CalculatorStatRow(
                      label: '예상 매수 금액',
                      value: widget.viewModel.formatHoldingPrice(
                        targetPlan.requiredAmount,
                        stock,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _CalculatorStatRow(
                      label: '예상 새 평균단가',
                      value: widget.viewModel.formatHoldingPrice(
                        targetPlan.estimatedAveragePrice,
                        stock,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              stock.marketType == StockMarketType.overseas
                  ? '해외 주식은 현재 앱에 저장된 원화 환산 가격 기준으로 계산합니다.'
                  : '수수료와 세금은 제외한 단순 평균단가 기준 계산입니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleInputChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }
}

class _CalculatorStatRow extends StatelessWidget {
  const _CalculatorStatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}

class AccountSelectionScreen extends ConsumerWidget {
  const AccountSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = ref.watch(availableAccountsProvider);
    final selectedAccountId = ref.watch(selectedAccountIdProvider);
    final selectedAccountNotifier = ref.read(
      selectedAccountIdProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('계좌 선택')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (accounts.isEmpty)
            const _MissingAccountConfigCard()
          else ...[
            const InfoBanner(message: '선택한 계좌를 기준으로 홈, 주식, 상세 화면 데이터를 불러옵니다.'),
            const SizedBox(height: 16),
            ...accounts.map((account) {
              final isSelected = selectedAccountId == account.id;
              final iconBackground = isSelected
                  ? (isDark ? const Color(0xFF11352A) : AppColors.accentSoft)
                  : (isDark
                        ? colorScheme.surfaceContainerHighest
                        : const Color(0xFFF3F4F6));
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        account.isIsa
                            ? Icons.savings_outlined
                            : Icons.account_balance_wallet_outlined,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                    ),
                    title: Text(account.label),
                    subtitle: Text(account.isIsa ? 'ISA 중개형 계좌' : '일반 위탁 계좌'),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.accent,
                          )
                        : const Icon(
                            Icons.radio_button_unchecked,
                            color: AppColors.textSecondary,
                          ),
                    onTap: () {
                      selectedAccountNotifier.state = account.id;
                      ref.invalidate(homeRepositoryProvider);
                      ref.invalidate(kisRealtimeConfProvider);
                      ref.invalidate(homeViewModelProvider);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _MissingAccountConfigCard extends StatelessWidget {
  const _MissingAccountConfigCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '계좌 설정 필요'),
          const SizedBox(height: 12),
          Text(
            '실행 설정에 계좌 정보가 주입되지 않아 선택 가능한 계좌가 없습니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '`flutter run --dart-define-from-file=env/kis.local.json`으로 실행해 주세요.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  const _ThemeModeCard({required this.selectedMode, required this.onChanged});

  final ThemeMode selectedMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: '화면 테마'),
          const SizedBox(height: 12),
          Text(
            '앱 화면을 직접 라이트/다크/시스템으로 바꿀 수 있습니다.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ThemeModeChip(
                label: '시스템',
                selected: selectedMode == ThemeMode.system,
                onTap: () => onChanged(ThemeMode.system),
              ),
              _ThemeModeChip(
                label: '라이트',
                selected: selectedMode == ThemeMode.light,
                onTap: () => onChanged(ThemeMode.light),
              ),
              _ThemeModeChip(
                label: '다크',
                selected: selectedMode == ThemeMode.dark,
                onTap: () => onChanged(ThemeMode.dark),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeModeChip extends StatelessWidget {
  const _ThemeModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? (isDark ? AppColors.darkTextPrimary : const Color(0xFF14563E))
              : Theme.of(context).textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: isDark
          ? AppColors.darkSurfaceSoft
          : Theme.of(context).cardColor,
      selectedColor: isDark ? AppColors.darkAccentSoft : AppColors.accentSoft,
      side: BorderSide(
        color: selected
            ? (isDark ? AppColors.darkAccent : AppColors.accent)
            : (isDark ? AppColors.darkBorder : AppColors.border),
      ),
    );
  }
}
