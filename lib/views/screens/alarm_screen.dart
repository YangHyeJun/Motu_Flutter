import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/home_provider.dart';
import '../widgets/common_widgets.dart';

class AlarmScreen extends ConsumerWidget {
  const AlarmScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(homeViewModelProvider.notifier);
    final state = ref.watch(homeViewModelProvider);

    const alarms = [
      ('삼성전자', '목표가 근접 알림이 도착했습니다.', '방금 전'),
      ('AI 투자 조언', '2차전지 종목 변동성이 확대되었습니다.', '12분 전'),
      ('공매도 순위', '카카오가 공매도 상위 3위로 진입했습니다.', '1시간 전'),
    ];

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const Text('알림')),
      body: RefreshIndicator(
        onRefresh: notifier.refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(
                  '최근 갱신 ${_formatTime(state.lastUpdated)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: notifier.refreshRealtimeSections,
                  icon: const Icon(Icons.refresh, size: 20),
                  color: AppColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...alarms.map(
              (alarm) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.accentSoft,
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.accent,
                      ),
                    ),
                    title: Text(alarm.$1),
                    subtitle: Text('${alarm.$2}\n${alarm.$3}'),
                    isThreeLine: true,
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

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
