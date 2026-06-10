import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Represents an exercise
class Exercise {
  final String name;
  final int reps;

  Exercise({required this.name, required this.reps});

  Map<String, dynamic> toJson() => {'name': name, 'reps': reps};
  factory Exercise.fromJson(Map<String, dynamic> json) =>
      Exercise(name: json['name'], reps: json['reps']);
}

// App Theme options
enum AppTheme { light, dark, oled }

// App Settings state
class AppSettings {
  final int workIntervalMinutes;
  final int exerciseWindowMinutes;
  final String notificationSound; // 'beep', 'ringtone', 'alarm'
  final AppTheme appTheme;
  final List<Exercise> exercises;

  AppSettings({
    this.workIntervalMinutes = 10,
    this.exerciseWindowMinutes = 5,
    this.notificationSound = 'beep',
    this.appTheme = AppTheme.dark,
    List<Exercise>? exercises,
  }) : exercises = exercises ?? [
          Exercise(name: 'Pushups', reps: 10),
          Exercise(name: 'Squats', reps: 10),
          Exercise(name: 'Burpees', reps: 5),
        ];

  AppSettings copyWith({
    int? workIntervalMinutes,
    int? exerciseWindowMinutes,
    String? notificationSound,
    AppTheme? appTheme,
    List<Exercise>? exercises,
  }) {
    return AppSettings(
      workIntervalMinutes: workIntervalMinutes ?? this.workIntervalMinutes,
      exerciseWindowMinutes: exerciseWindowMinutes ?? this.exerciseWindowMinutes,
      notificationSound: notificationSound ?? this.notificationSound,
      appTheme: appTheme ?? this.appTheme,
      exercises: exercises ?? this.exercises,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _loadSettings();
    return AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final workMin = prefs.getInt('workIntervalMinutes') ?? 10;
    final exMin = prefs.getInt('exerciseWindowMinutes') ?? 5;
    final sound = prefs.getString('notificationSound') ?? 'beep';
    
    final themeStr = prefs.getString('appTheme') ?? 'dark';
    AppTheme theme = AppTheme.dark;
    if (themeStr == 'light') theme = AppTheme.light;
    if (themeStr == 'oled') theme = AppTheme.oled;
    
    final exercisesStr = prefs.getString('exercises');
    List<Exercise>? loadedExercises;
    if (exercisesStr != null) {
      final List<dynamic> decoded = jsonDecode(exercisesStr);
      loadedExercises = decoded.map((e) => Exercise.fromJson(e)).toList();
    }

    state = AppSettings(
      workIntervalMinutes: workMin,
      exerciseWindowMinutes: exMin,
      notificationSound: sound,
      appTheme: theme,
      exercises: loadedExercises,
    );
  }

  Future<void> updateSettings(AppSettings newSettings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workIntervalMinutes', newSettings.workIntervalMinutes);
    await prefs.setInt('exerciseWindowMinutes', newSettings.exerciseWindowMinutes);
    await prefs.setString('notificationSound', newSettings.notificationSound);
    await prefs.setString('appTheme', newSettings.appTheme.name);
    await prefs.setString(
        'exercises', jsonEncode(newSettings.exercises.map((e) => e.toJson()).toList()));
    
    state = newSettings;
  }
}

final settingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(() {
  return AppSettingsNotifier();
});

// App State representing current status
enum TimerState { ready, paused, work, exercise, water }

class AppStatus {
  final TimerState state;
  final int remainingSeconds;
  final int cycleIndex; // 0, 1, 2 = exercises, 3 = water

  AppStatus({
    this.state = TimerState.ready,
    this.remainingSeconds = 600,
    this.cycleIndex = 0,
  });

  AppStatus copyWith({
    TimerState? state,
    int? remainingSeconds,
    int? cycleIndex,
  }) {
    return AppStatus(
      state: state ?? this.state,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      cycleIndex: cycleIndex ?? this.cycleIndex,
    );
  }
}

class AppStatusNotifier extends Notifier<AppStatus> {
  @override
  AppStatus build() {
    return AppStatus();
  }

  void updateStatus(AppStatus newStatus) {
    state = newStatus;
  }
}

final statusProvider = NotifierProvider<AppStatusNotifier, AppStatus>(() {
  return AppStatusNotifier();
});
