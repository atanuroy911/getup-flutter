import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_state_provider.dart';
import '../theme/app_colors.dart';

class GetStartedScreen extends ConsumerStatefulWidget {
  const GetStartedScreen({super.key});

  @override
  ConsumerState<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends ConsumerState<GetStartedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _requestPermissionsAndFinish() async {
    // Ignore battery optimizations (Background execution)
    await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasLaunched', true);
    
    if (mounted) {
      context.go('/onboarding/notifications');
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _requestPermissionsAndFinish();
    }
  }

  Widget _buildPage({required IconData icon, required String title, required String description, required Color iconColor, required AppColors appColors}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.1),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 100,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 50),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: appColors.textPrimary,
              letterSpacing: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: appColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.fromTheme(ref.watch(settingsProvider).appTheme);

    return Scaffold(
      backgroundColor: appColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildPage(
                    icon: Icons.directions_run_rounded,
                    title: 'Ready to change your life?',
                    description: 'Get Up interrupts your day with tiny exercises to keep you moving and healthy.',
                    iconColor: appColors.defaultAccent,
                    appColors: appColors,
                  ),
                  _buildPage(
                    icon: Icons.notifications_active_rounded,
                    title: 'Stay Notified',
                    description: 'We need permission to send you notifications so you never miss a workout window.',
                    iconColor: appColors.waterAccent,
                    appColors: appColors,
                  ),
                  _buildPage(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Background Execution',
                    description: 'To keep the timer accurate, we require background execution permissions. You will be prompted to grant these next.',
                    iconColor: appColors.exerciseAccent,
                    appColors: appColors,
                  ),
                ],
              ),
            ),
            
            // Dot Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                height: 10,
                width: _currentPage == index ? 20 : 10,
                decoration: BoxDecoration(
                  color: _currentPage == index ? appColors.defaultAccent : appColors.divider,
                  borderRadius: BorderRadius.circular(5),
                ),
              )),
            ),
            
            const SizedBox(height: 40),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appColors.defaultAccent,
                  foregroundColor: appColors.background,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                  shadowColor: appColors.defaultAccent.withValues(alpha: 0.5),
                ),
                child: Text(
                  _currentPage == 2 ? 'GRANT PERMISSIONS & START' : 'NEXT',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
