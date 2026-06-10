import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as fow;
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

import '../providers/app_state_provider.dart';
import '../services/background_timer_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int workMin;
  late int exMin;
  late String notificationSound;
  late AppTheme appTheme;
  late List<Exercise> exercises;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    workMin = s.workIntervalMinutes;
    exMin = s.exerciseWindowMinutes;
    notificationSound = s.notificationSound;
    appTheme = s.appTheme;
    exercises = List.from(s.exercises);
  }

  void _save() async {
    HapticFeedback.lightImpact();
    final s = ref.read(settingsProvider);
    
    await ref.read(settingsProvider.notifier).updateSettings(
      AppSettings(
        workIntervalMinutes: workMin,
        exerciseWindowMinutes: exMin,
        notificationSound: notificationSound,
        appTheme: appTheme, // still kept in case it somehow desynced
        exercises: exercises,
      ),
    );
    
    BackgroundTimerService.reloadAndReset();
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (context) {
          Future.delayed(const Duration(seconds: 1), () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          });
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF00E676), size: 48),
                    SizedBox(height: 8),
                    Text('Settings Saved', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          );
        }
      );
    }
  }

  Future<void> _editExercise(int index) async {
    final nameCtrl = TextEditingController(text: exercises[index].name);
    final repsCtrl = TextEditingController(text: exercises[index].reps.toString());
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Exercise ${index + 1}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: repsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reps'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      }
    );

    if (result == true) {
      setState(() {
        exercises[index] = Exercise(
          name: nameCtrl.text,
          reps: int.tryParse(repsCtrl.text) ?? 10,
        );
      });
    }
  }

  Future<void> _openOverlaySettings() async {
    final intent = const AndroidIntent(
      action: 'android.settings.action.MANAGE_OVERLAY_PERMISSION',
    );
    await intent.launch();
  }

  Widget _buildGlassCard({required Widget child, required AppColors appColors}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.fromTheme(ref.watch(settingsProvider).appTheme);
    
    return Scaffold(
      backgroundColor: appColors.background,
      appBar: AppBar(
        iconTheme: IconThemeData(color: appColors.textPrimary),
        title: Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, color: appColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          const Text('APPEARANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _buildGlassCard(
            appColors: appColors,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text('App Theme', style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600)),
                  trailing: DropdownButton<AppTheme>(
                    value: appTheme,
                    dropdownColor: appColors.background,
                    style: TextStyle(color: appColors.textPrimary, fontSize: 14),
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: appColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: AppTheme.dark, child: Text('Dark')),
                      DropdownMenuItem(value: AppTheme.light, child: Text('Light')),
                      DropdownMenuItem(value: AppTheme.oled, child: Text('OLED / AOD')),
                    ],
                    onChanged: (AppTheme? val) async {
                      if (val != null) {
                        setState(() => appTheme = val);
                        final s = ref.read(settingsProvider);
                        await ref.read(settingsProvider.notifier).updateSettings(
                          AppSettings(
                            workIntervalMinutes: s.workIntervalMinutes,
                            exerciseWindowMinutes: s.exerciseWindowMinutes,
                            notificationSound: s.notificationSound,
                            appTheme: val,
                            exercises: s.exercises,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('PERMISSIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _buildGlassCard(
            appColors: appColors,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text('Notifications', style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: TextButton(
                    onPressed: () => openAppSettings(),
                    child: const Text('MANAGE'),
                  ),
                ),
                Divider(color: appColors.divider, height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text('Overlay Bubble', style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: TextButton(
                    onPressed: _openOverlaySettings,
                    child: const Text('MANAGE'),
                  ),
                ),
                Divider(color: appColors.divider, height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text('Test Overlay', style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: IconButton(
                    icon: Icon(Icons.launch, color: appColors.defaultAccent),
                    onPressed: () async {
                      if (await fow.FlutterOverlayWindow.isPermissionGranted() == true) {
                        try {
                          final density = MediaQuery.of(context).devicePixelRatio;
                          await fow.FlutterOverlayWindow.showOverlay(
                            enableDrag: true,
                            overlayTitle: "Get Up",
                            overlayContent: "Timer running",
                            flag: fow.OverlayFlag.defaultFlag,
                            visibility: fow.NotificationVisibility.visibilitySecret,
                            positionGravity: fow.PositionGravity.auto,
                            height: (110 * density).toInt(),
                            width: (250 * density).toInt(),
                          );
                          Future.delayed(const Duration(seconds: 3), () {
                            fow.FlutterOverlayWindow.closeOverlay();
                          });
                        } catch (e) {
                          // Ignore if overlay fails to start
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Text('INTERVALS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: appColors.defaultAccent, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          _buildGlassCard(
            appColors: appColors,
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text('Work Interval', style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('$workMin min', style: TextStyle(color: appColors.textSecondary, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: appColors.defaultAccent), 
                        onPressed: () { if (workMin > 1) setState(() => workMin--); }
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: appColors.defaultAccent), 
                        onPressed: () { if (workMin < 120) setState(() => workMin++); }
                      ),
                    ],
                  ),
                ),
                Divider(color: appColors.divider, height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text('Exercise Window', style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('$exMin min', style: TextStyle(color: appColors.textSecondary, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline, color: appColors.exerciseAccent), 
                        onPressed: () { if (exMin > 1) setState(() => exMin--); }
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline, color: appColors.exerciseAccent), 
                        onPressed: () { if (exMin < 30) setState(() => exMin++); }
                      ),
                    ],
                  ),
                ),
                Divider(color: appColors.divider, height: 1),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  title: Text('Sound', style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: DropdownButton<String>(
                    value: notificationSound,
                    dropdownColor: appColors.background,
                    style: TextStyle(color: appColors.textPrimary, fontSize: 14),
                    underline: const SizedBox(),
                    icon: Icon(Icons.arrow_drop_down, color: appColors.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'beep', child: Text('Beep')),
                      DropdownMenuItem(value: 'ringtone', child: Text('Ringtone')),
                      DropdownMenuItem(value: 'alarm', child: Text('Alarm')),
                    ],
                    onChanged: (String? val) {
                      if (val != null) setState(() => notificationSound = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Text('EXERCISES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: appColors.exerciseAccent, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          
          _buildGlassCard(
            appColors: appColors,
            child: Column(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(exercises[i].name, style: TextStyle(color: appColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('${exercises[i].reps} Reps', style: TextStyle(color: appColors.exerciseAccent, fontSize: 12)),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: appColors.divider,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, color: appColors.textPrimary, size: 16),
                        onPressed: () => _editExercise(i),
                      ),
                    ),
                    onTap: () => _editExercise(i),
                  ),
                  if (i < 2) Divider(color: appColors.divider, height: 1),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: appColors.defaultAccent,
              foregroundColor: appColors.background,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              elevation: 2,
              shadowColor: appColors.defaultAccent.withValues(alpha: 0.5),
            ),
            child: const Text(
              'SAVE SETTINGS', 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
