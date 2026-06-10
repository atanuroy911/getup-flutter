import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart' hide NotificationVisibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_state_provider.dart';
import '../services/background_timer_service.dart';
import '../theme/app_colors.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  
  bool? _hasOverlayPermission;
  bool? _hasNotificationPermission;
  bool _dismissedOverlayReminder = false;
  bool _dismissedNotificationReminder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FlutterOverlayWindow.closeOverlay();
    _initForegroundTask();
    _checkPermissions();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initForegroundTask() async {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    // Permissions are now handled in the onboarding flow or settings.
    // We intentionally DO NOT auto-start the service here.
    // The user must explicitly press Play for the first time.
  }

  Future<void> _checkPermissions() async {
    final notif = await FlutterForegroundTask.checkNotificationPermission();
    final overlay = await FlutterOverlayWindow.isPermissionGranted();
    
    if (mounted) {
      setState(() {
        _hasNotificationPermission = notif == NotificationPermission.granted;
        _hasOverlayPermission = overlay == true;
      });
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map) {
      final stateStr = data['state'] as String;
      final remainingSeconds = data['remainingSeconds'] as int;
      final cycleIndex = data['cycleIndex'] as int;

      TimerState tState = TimerState.ready;
      if (stateStr == 'paused') tState = TimerState.paused;
      if (stateStr == 'work') tState = TimerState.work;
      if (stateStr == 'exercise') tState = TimerState.exercise;
      if (stateStr == 'water') tState = TimerState.water;

      ref.read(statusProvider.notifier).updateStatus(
        AppStatus(
          state: tState,
          remainingSeconds: remainingSeconds,
          cycleIndex: cycleIndex,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final status = ref.read(statusProvider);
      bool isRunning = status.state != TimerState.paused && status.state != TimerState.ready;
      if (isRunning) {
        if (_hasOverlayPermission == true) {
          FlutterOverlayWindow.isActive().then((isActive) async {
            if (isActive == false) {
              try {
                final density = MediaQuery.of(context).devicePixelRatio;
                await FlutterOverlayWindow.showOverlay(
                  enableDrag: true,
                  overlayTitle: "Get Up",
                  overlayContent: "Timer running",
                  flag: OverlayFlag.defaultFlag,
                  visibility: NotificationVisibility.visibilitySecret,
                  positionGravity: PositionGravity.auto,
                  height: (110 * density).toInt(),
                  width: (250 * density).toInt(),
                );
              } catch (e) {
                // Silently ignore if OEM blocks it or overlay service fails.
              }
            }
          });
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      FlutterOverlayWindow.closeOverlay();
      _checkPermissions();
    }
  }

  void _togglePlayPause(AppStatus status) async {
    HapticFeedback.lightImpact();
    if (status.state == TimerState.paused || status.state == TimerState.ready) {
      if (!await FlutterForegroundTask.isRunningService) {
        // Pre-write the state so the isolate starts immediately in the right mode
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentState', 'work');
        
        final settings = ref.read(settingsProvider);
        if (status.state == TimerState.ready) {
          await prefs.setInt('remainingSeconds', settings.workIntervalMinutes * 60);
        } else {
          await prefs.setInt('remainingSeconds', status.remainingSeconds);
        }
        
        await BackgroundTimerService.startService();
      } else {
        BackgroundTimerService.resume();
      }
    } else {
      BackgroundTimerService.pause();
    }
  }

  Future<void> _confirmReset() async {
    HapticFeedback.lightImpact();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Reset Timer?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to reset the current phase?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      BackgroundTimerService.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(statusProvider);
    final settings = ref.watch(settingsProvider);
    final appColors = AppColors.fromTheme(settings.appTheme);

    if (status.state == TimerState.exercise || status.state == TimerState.water) {
      return _buildActivityScreen(context, status, settings, appColors);
    }
    return _buildTimerScreen(context, status, settings, appColors);
  }

  Widget _buildActivityScreen(BuildContext context, AppStatus status, AppSettings settings, AppColors appColors) {
    String title = status.state == TimerState.water ? "DRINK WATER" : "TIME TO MOVE";
    String task = status.state == TimerState.water 
        ? "Drink a glass of water" 
        : "${settings.exercises[status.cycleIndex].reps} ${settings.exercises[status.cycleIndex].name}";
        
    Color bgColor = appColors.getBackgroundForState(status.state);
    Color accentColor = appColors.getAccentForState(status.state);

    int m = status.remainingSeconds ~/ 60;
    int s = status.remainingSeconds % 60;
    String timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  status.state == TimerState.water ? Icons.water_drop_rounded : Icons.directions_run_rounded,
                  size: 80,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                task,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: appColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                "REMAINING",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: appColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 50),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => BackgroundTimerService.skipOrDone(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appColors.cardBackground,
                        foregroundColor: appColors.textPrimary,
                        minimumSize: const Size(0, 70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(35),
                        ),
                      ),
                      child: const Text('SKIP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => BackgroundTimerService.skipOrDone(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: appColors.background,
                        minimumSize: const Size(0, 70),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(35),
                        ),
                      ),
                      child: const Text('DONE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerScreen(BuildContext context, AppStatus status, AppSettings settings, AppColors appColors) {
    Color accentColor = appColors.getAccentForState(status.state);
    Color bgColor = appColors.getBackgroundForState(status.state);
    String stateLabel;
    String nextLabel = "";
    String currentTaskLabel;

    int totalSeconds = settings.workIntervalMinutes * 60;
    int displaySeconds = status.state == TimerState.ready ? totalSeconds : status.remainingSeconds;

    if (status.state == TimerState.work) {
      stateLabel = "WORK TIME";
      String nTask = status.cycleIndex >= 3 
          ? "Drink Water" 
          : "${settings.exercises[status.cycleIndex].reps} ${settings.exercises[status.cycleIndex].name}";
      nextLabel = "Upcoming: $nTask";
      currentTaskLabel = "Stay focused on your task.";
    } else if (status.state == TimerState.paused) {
      accentColor = appColors.textSecondary;
      stateLabel = "PAUSED";
      currentTaskLabel = "Timer paused.";
    } else {
      // Ready state
      stateLabel = "READY";
      currentTaskLabel = "Ready to get active? Start the timer!";
    }

    double progress = displaySeconds / totalSeconds;
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;

    int m = displaySeconds ~/ 60;
    int s = displaySeconds % 60;
    String timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    
    bool isRunning = status.state == TimerState.work;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: appColors.cardBackground,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: IconButton(
                  icon: Icon(Icons.settings_rounded, color: appColors.textPrimary, size: 28),
                  onPressed: () => context.push('/settings'),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (status.cycleIndex >= 1) ...[
                  if (_hasNotificationPermission == false && !_dismissedNotificationReminder)
                    _buildPermissionReminder(
                      context: context,
                      appColors: appColors,
                      title: "Enable notifications so you never miss a movement break.",
                      onEnable: () {
                        context.push('/settings');
                        setState(() => _dismissedNotificationReminder = true);
                      },
                      onDismiss: () => setState(() => _dismissedNotificationReminder = true),
                    ),
                  if (_hasOverlayPermission == false && !_dismissedOverlayReminder && (_hasNotificationPermission == true || _dismissedNotificationReminder))
                    _buildPermissionReminder(
                      context: context,
                      appColors: appColors,
                      title: "Want reminders even while using other apps? Enable Overlay.",
                      onEnable: () {
                        context.push('/settings');
                        setState(() => _dismissedOverlayReminder = true);
                      },
                      onDismiss: () => setState(() => _dismissedOverlayReminder = true),
                    ),
                ],
                const Spacer(flex: 2),
                ScaleTransition(
                  scale: isRunning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 300,
                          height: 300,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 16,
                            backgroundColor: appColors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              stateLabel,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                                color: appColors.textPrimary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: appColors.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: appColors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          currentTaskLabel,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: appColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (nextLabel.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              nextLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 1),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => _togglePlayPause(status),
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 48,
                          color: appColors.background,
                        ),
                      ),
                    ),
                    if (!isRunning) ...[
                      const SizedBox(width: 20),
                      InkWell(
                        onTap: _confirmReset,
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: appColors.cardBackground,
                            border: Border.all(color: appColors.divider),
                          ),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 30,
                            color: appColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 50),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionReminder({
    required BuildContext context,
    required AppColors appColors,
    required String title,
    required VoidCallback onEnable,
    required VoidCallback onDismiss,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 80, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appColors.defaultAccent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: appColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: appColors.textSecondary,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Not Now", style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onEnable,
                style: TextButton.styleFrom(
                  foregroundColor: appColors.defaultAccent,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("Enable", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
