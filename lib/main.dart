import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'providers/app_state_provider.dart';
import 'theme/app_colors.dart';
import 'services/background_timer_service.dart';
import 'screens/get_started_screen.dart';
import 'screens/main_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/overlay_bubble.dart';
import 'screens/permission_screen.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayBubble(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri?.host == 'toggle') {
    FlutterForegroundTask.sendDataToTask({'action': 'toggle'});
  } else if (uri?.host == 'reset') {
    FlutterForegroundTask.sendDataToTask({'action': 'reset'});
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await HomeWidget.registerBackgroundCallback(widgetBackgroundCallback);
  await BackgroundTimerService.init();

  runApp(
    const ProviderScope(
      child: GetUpApp(),
    ),
  );
}

class GetUpApp extends ConsumerWidget {
  const GetUpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final appColors = AppColors.fromTheme(settings.appTheme);

    final brightness = settings.appTheme == AppTheme.light 
        ? Brightness.light 
        : Brightness.dark;

    return MaterialApp.router(
      title: 'Get Up',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: brightness,
        scaffoldBackgroundColor: appColors.background,
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
      ),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/get-started',
      builder: (context, state) => const GetStartedScreen(),
    ),
    GoRoute(
      path: '/onboarding/notifications',
      builder: (context, state) => const PermissionScreen(type: PermissionType.notifications),
    ),
    GoRoute(
      path: '/onboarding/overlay',
      builder: (context, state) => const PermissionScreen(type: PermissionType.overlay),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

// Determines whether to show Get Started or Main Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasLaunched = prefs.getBool('hasLaunched') ?? false;
    final hasSeenNotificationOnboarding = prefs.getBool('hasSeenNotificationOnboarding') ?? false;
    final hasSeenOverlayOnboarding = prefs.getBool('hasSeenOverlayOnboarding') ?? false;
    
    if (!mounted) return;
    
    if (!hasLaunched) {
      context.go('/get-started');
    } else if (!hasSeenNotificationOnboarding) {
      context.go('/onboarding/notifications');
    } else if (!hasSeenOverlayOnboarding) {
      context.go('/onboarding/overlay');
    } else {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
