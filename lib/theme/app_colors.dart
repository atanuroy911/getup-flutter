import 'package:flutter/material.dart';
import '../providers/app_state_provider.dart';

class AppColors {
  final Color background;
  final Color cardBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  
  // Specific to timer/activity screen states
  final Color workAccent;
  final Color exerciseAccent;
  final Color waterAccent;
  final Color defaultAccent;
  
  // Specific background overrides for activities
  final Color workBackground;
  final Color exerciseBackground;
  final Color waterBackground;

  AppColors({
    required this.background,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.workAccent,
    required this.exerciseAccent,
    required this.waterAccent,
    required this.defaultAccent,
    required this.workBackground,
    required this.exerciseBackground,
    required this.waterBackground,
  });

  factory AppColors.fromTheme(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
        return AppColors(
          background: const Color(0xFFF5F5F5),
          cardBackground: Colors.white,
          textPrimary: const Color(0xFF1E1E1E),
          textSecondary: Colors.black54,
          divider: Colors.black12,
          workAccent: const Color(0xFF00B248),
          exerciseAccent: const Color(0xFFFF6D00),
          waterAccent: const Color(0xFF0091EA),
          defaultAccent: const Color(0xFF00B248),
          workBackground: const Color(0xFFE8F5E9),
          exerciseBackground: const Color(0xFFFFF3E0),
          waterBackground: const Color(0xFFE1F5FE),
        );
      case AppTheme.oled:
        // Pure black for AOD/OLED to save battery
        return AppColors(
          background: Colors.black,
          cardBackground: Colors.white.withValues(alpha: 0.05),
          textPrimary: Colors.white,
          textSecondary: Colors.white70,
          divider: Colors.white12,
          workAccent: const Color(0xFF00E676),
          exerciseAccent: const Color(0xFFFF3D00),
          waterAccent: const Color(0xFF00B0FF),
          defaultAccent: const Color(0xFF00E676),
          workBackground: Colors.black,
          exerciseBackground: Colors.black,
          waterBackground: Colors.black,
        );
      case AppTheme.dark:
      default:
        // Standard dark mode with subtle tinted backgrounds
        return AppColors(
          background: const Color(0xFF121212),
          cardBackground: Colors.white.withValues(alpha: 0.05),
          textPrimary: Colors.white,
          textSecondary: Colors.white70,
          divider: Colors.white12,
          workAccent: const Color(0xFF00E676),
          exerciseAccent: const Color(0xFFFF3D00),
          waterAccent: const Color(0xFF00B0FF),
          defaultAccent: const Color(0xFF00E676),
          workBackground: const Color(0xFF0F2016),
          exerciseBackground: const Color(0xFF2A1005),
          waterBackground: const Color(0xFF081825),
        );
    }
  }

  // Helper method to get background for a given TimerState
  Color getBackgroundForState(TimerState state) {
    switch (state) {
      case TimerState.work:
        return workBackground;
      case TimerState.exercise:
        return exerciseBackground;
      case TimerState.water:
        return waterBackground;
      case TimerState.ready:
      case TimerState.paused:
      default:
        return background;
    }
  }

  // Helper method to get accent for a given TimerState
  Color getAccentForState(TimerState state) {
    switch (state) {
      case TimerState.work:
        return workAccent;
      case TimerState.exercise:
        return exerciseAccent;
      case TimerState.water:
        return waterAccent;
      case TimerState.ready:
      case TimerState.paused:
      default:
        return defaultAccent;
    }
  }
}
