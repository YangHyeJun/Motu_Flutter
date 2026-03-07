import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'views/screens/app_shell.dart';

class MotuApp extends StatelessWidget {
  const MotuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '모두투자',
        theme: AppTheme.theme,
        home: const AppShell(),
      ),
    );
  }
}
