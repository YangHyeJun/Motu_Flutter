import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'providers/api_provider.dart';
import 'views/screens/app_shell_view.dart';

class MotuApp extends StatelessWidget {
  const MotuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '모두투자',
            theme: AppTheme.theme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ref.watch(themeModeProvider),
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
