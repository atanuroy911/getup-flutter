import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../providers/app_state_provider.dart';
import '../theme/app_colors.dart';

enum PermissionType { notifications, overlay }

class PermissionScreen extends ConsumerStatefulWidget {
  final PermissionType type;

  const PermissionScreen({super.key, required this.type});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> with WidgetsBindingObserver {
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isProcessing) {
      _checkPermissionAndAdvance();
    }
  }

  Future<void> _checkInitialPermission() async {
    // Check if permission is already granted when screen loads to prevent getting stuck
    if (widget.type == PermissionType.notifications) {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status == NotificationPermission.granted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasSeenNotificationOnboarding', true);
        if (mounted) context.go('/onboarding/overlay');
      }
    } else {
      if (await FlutterOverlayWindow.isPermissionGranted() == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasSeenOverlayOnboarding', true);
        if (mounted) context.go('/main');
      }
    }
  }

  Future<void> _checkPermissionAndAdvance() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (widget.type == PermissionType.notifications) {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status == NotificationPermission.granted) {
        await prefs.setBool('hasSeenNotificationOnboarding', true);
        if (mounted) context.go('/onboarding/overlay');
      } else {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else {
      if (await FlutterOverlayWindow.isPermissionGranted() == true) {
        await prefs.setBool('hasSeenOverlayOnboarding', true);
        if (mounted) context.go('/main');
      } else {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleAllow() async {
    setState(() => _isProcessing = true);

    if (widget.type == PermissionType.notifications) {
      final status = await FlutterForegroundTask.checkNotificationPermission();
      if (status != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      await _checkPermissionAndAdvance();
    } else {
      if (await FlutterOverlayWindow.isPermissionGranted() != true) {
        await FlutterOverlayWindow.requestPermission();
      }
      // Note: overlay permission opens system settings. The return from that
      // is caught by didChangeAppLifecycleState(resumed)
    }
  }

  Future<void> _handleSkip() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (widget.type == PermissionType.notifications) {
      await prefs.setBool('hasSeenNotificationOnboarding', true);
      if (mounted) context.go('/onboarding/overlay');
    } else {
      await prefs.setBool('hasSeenOverlayOnboarding', true);
      if (mounted) context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final appColors = AppColors.fromTheme(settings.appTheme);

    final isOverlay = widget.type == PermissionType.overlay;
    final title = isOverlay ? "Display Over Other Apps" : "Enable Notifications";
    final description = isOverlay
        ? "We can show a floating mini-timer over other apps so you never lose track of your work sessions. It helps prevent missing movement reminders!"
        : "Notifications are essential so you never miss a movement break. We only notify you when it's time to transition between work and exercise.";
    final icon = isOverlay ? Icons.layers : Icons.notifications_active;

    return Scaffold(
      backgroundColor: appColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(icon, size: 100, color: appColors.defaultAccent),
              const SizedBox(height: 32),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: appColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: appColors.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleAllow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.defaultAccent,
                    foregroundColor: appColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Allow",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TextButton(
                  onPressed: _isProcessing ? null : _handleSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: appColors.textSecondary,
                  ),
                  child: const Text(
                    "Skip",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
