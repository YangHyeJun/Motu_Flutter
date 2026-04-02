import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/api_provider.dart';
import 'favorites_view.dart';
import 'home_view.dart';
import 'more_view.dart';
import 'splash_view.dart';
import 'stocks_view.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appShellViewModelProvider);
    final viewModel = ref.read(appShellViewModelProvider.notifier);

    if (state.showSplash) {
      return const SplashScreen();
    }

    final screens = [
      const HomeScreen(),
      const StocksScreen(),
      const FavoritesScreen(),
      const MoreScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: state.currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: state.currentIndex,
        onTap: viewModel.updateCurrentIndex,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: Theme.of(context).cardColor,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: '홈',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: '주식'),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline_rounded),
            activeIcon: Icon(Icons.star_rounded),
            label: '즐겨찾기',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: '더보기'),
        ],
      ),
    );
  }
}
