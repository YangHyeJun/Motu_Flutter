import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/api_provider.dart';
import '../../providers/home_provider.dart';
import '../widgets/common_widgets.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(availableAccountsProvider);
    final selectedAccount = ref.watch(selectedAccountProvider);

    final items = [
      (
        '계좌 선택',
        selectedAccount?.label ?? '선택 가능한 계좌 없음',
        Icons.account_balance_wallet_outlined,
        () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountSelectionScreen()),
            ),
      ),
      ('내 자산 리포트', '보유 자산과 수익률 요약', Icons.pie_chart_outline, null),
      ('알림 설정', '가격 알림과 주요 알림 관리', Icons.notifications_outlined, null),
      ('투자 성향 테스트', '내 투자 성향 다시 확인', Icons.psychology_outlined, null),
      ('고객센터', '문의와 도움말', Icons.support_agent_outlined, null),
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

class AccountSelectionScreen extends ConsumerWidget {
  const AccountSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(availableAccountsProvider);
    final selectedAccountId = ref.watch(selectedAccountIdProvider);
    final selectedAccountNotifier = ref.read(selectedAccountIdProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('계좌 선택'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (accounts.isEmpty)
            const _MissingAccountConfigCard()
          else ...[
            const InfoBanner(
              message: '선택한 계좌를 기준으로 홈, 주식, 상세 화면 데이터를 불러옵니다.',
            ),
            const SizedBox(height: 16),
            ...accounts.map((account) {
              final isSelected = selectedAccountId == account.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentSoft : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        account.isIsa ? Icons.savings_outlined : Icons.account_balance_wallet_outlined,
                        color: isSelected ? AppColors.accent : AppColors.textSecondary,
                      ),
                    ),
                    title: Text(account.label),
                    subtitle: Text(
                      account.isIsa ? 'ISA 중개형 계좌' : '일반 위탁 계좌',
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.accent)
                        : const Icon(Icons.radio_button_unchecked, color: AppColors.textSecondary),
                    onTap: () {
                      selectedAccountNotifier.state = account.id;
                      ref.invalidate(homeRepositoryProvider);
                      ref.invalidate(kisRealtimeServiceProvider);
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
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
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
