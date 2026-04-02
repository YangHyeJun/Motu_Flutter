import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF083D34), Color(0xFF52B8A1)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Stack(
              children: [
                Align(
                  alignment: const Alignment(0, -0.12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: Color(0x14FFFFFF),
                          shape: BoxShape.circle,
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: 18,
                              child: Icon(
                                Icons.trending_up,
                                color: AppColors.accent,
                                size: 36,
                              ),
                            ),
                            Positioned(
                              right: 18,
                              top: 22,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Color(0xFFF7B63E),
                                child: Text(
                                  '\$',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '모두투자',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'EVERYONE INVEST',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '모두를 위한 모의 투자',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '지금, 당신의 투자 감각을\n테스트해 보세요',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xDDF4F8F7),
                        ),
                      ),
                      const SizedBox(height: 40),
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '앱을 시작하는 중...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    'Powered by 한국투자증권 OpenAPI',
                    style: TextStyle(
                      color: Color(0xB3FFFFFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
