import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppShellViewState {
  const AppShellViewState({
    required this.showSplash,
    required this.currentIndex,
  });

  final bool showSplash;
  final int currentIndex;

  AppShellViewState copyWith({
    bool? showSplash,
    int? currentIndex,
  }) {
    return AppShellViewState(
      showSplash: showSplash ?? this.showSplash,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class AppShellViewModel extends AutoDisposeNotifier<AppShellViewState> {
  Timer? _splashTimer;

  @override
  AppShellViewState build() {
    ref.onDispose(() {
      _splashTimer?.cancel();
    });
    _splashTimer ??= Timer(const Duration(milliseconds: 1800), () {
      state = state.copyWith(showSplash: false);
    });
    return const AppShellViewState(showSplash: true, currentIndex: 0);
  }

  void updateCurrentIndex(int index) {
    if (state.currentIndex == index) {
      return;
    }
    state = state.copyWith(currentIndex: index);
  }
}
