import 'package:flutter/material.dart';

import '../widgets/common_widgets.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      ('내 자산 리포트', Icons.pie_chart_outline),
      ('알림 설정', Icons.notifications_outlined),
      ('투자 성향 테스트', Icons.psychology_outlined),
      ('고객센터', Icons.support_agent_outlined),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '더보기',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 26),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.$2),
                  title: Text(item.$1),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
