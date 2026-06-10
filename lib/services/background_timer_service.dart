import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// The callback function should always be a top-level function.
@pragma('vm:entry-point')
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

class TimerTaskHandler extends TaskHandler {
  int _remainingSeconds = 0;
  String _currentState = 'ready';
  String _pausedState = 'work';
  int _cycleIndex = 0;
  bool _isTransitioning = false;
  bool _bellPlayed = false;
  
  int _workIntervalSeconds = 600;
  int _exerciseWindowSeconds = 300;
  String _notificationSound = 'beep';
  List<dynamic> _exercises = [];
  DateTime? _targetTime;

  AudioPlayer? _audioPlayer;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map && event.containsKey('action')) {
        onReceiveData(event);
      }
    });

    _audioPlayer = AudioPlayer();
    await _loadSettings();
    await _loadState();
    
    if (_currentState == 'ready') {
      _remainingSeconds = _workIntervalSeconds;
      await _saveState();
    } else if (_currentState == 'paused' && _pausedState == 'paused') {
      _pausedState = 'work'; // default to work if totally new
      _remainingSeconds = _workIntervalSeconds;
      await _saveState();
    }
    
    if (_currentState != 'paused' && _currentState != 'ready') {
      _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
    }
    
    _updateNotification();
    _updateWidget();
    _updateOverlay();
    FlutterForegroundTask.sendDataToMain(_buildStateMap());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _workIntervalSeconds = (prefs.getInt('workIntervalMinutes') ?? 10) * 60;
    _exerciseWindowSeconds = (prefs.getInt('exerciseWindowMinutes') ?? 5) * 60;
    _notificationSound = prefs.getString('notificationSound') ?? 'beep';
    
    final exStr = prefs.getString('exercises');
    if (exStr != null) {
      _exercises = jsonDecode(exStr);
    } else {
      _exercises = [
        {'name': 'Pushups', 'reps': 10},
        {'name': 'Squats', 'reps': 10},
        {'name': 'Burpees', 'reps': 5},
      ];
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    _currentState = prefs.getString('currentState') ?? 'ready';
    _pausedState = prefs.getString('pausedState') ?? 'work';
    _remainingSeconds = prefs.getInt('remainingSeconds') ?? 0;
    _cycleIndex = prefs.getInt('cycleIndex') ?? 0;
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentState', _currentState);
    await prefs.setString('pausedState', _pausedState);
    await prefs.setInt('remainingSeconds', _remainingSeconds);
    await prefs.setInt('cycleIndex', _cycleIndex);
  }

  Map<String, dynamic> _buildStateMap() {
    return {
      'state': _currentState,
      'remainingSeconds': _remainingSeconds,
      'cycleIndex': _cycleIndex,
    };
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    if (_currentState == 'paused' || _currentState == 'ready' || _targetTime == null) {
       FlutterForegroundTask.sendDataToMain(_buildStateMap());
       return;
    }

    final now = DateTime.now();
    _remainingSeconds = _targetTime!.difference(now).inSeconds;

    // Play bell 3 seconds before work ends
    if (_currentState == 'work' && _remainingSeconds == 3 && !_bellPlayed) {
      _bellPlayed = true;
      _playBell(); // async, unawaited
    }

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      if (!_isTransitioning) {
        _isTransitioning = true;
        _transitionState().whenComplete(() {
          _isTransitioning = false;
        });
      }
    } else {
      // Periodically save state to survive process death (every 5 seconds)
      if (_remainingSeconds % 5 == 0) {
        _saveState();
      }
    }

    _updateNotification();
    _updateWidget();
    _updateOverlay();
    FlutterForegroundTask.sendDataToMain(_buildStateMap());
  }

  Future<void> _transitionState() async {
    if (_currentState == 'work') {
      // Work finished, time to move! (Bell played 3 seconds ago)
      
      // Determine next state
      if (_cycleIndex >= 3) {
        _currentState = 'water';
      } else {
        _currentState = 'exercise';
      }
      _remainingSeconds = _exerciseWindowSeconds;
      _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    } else if (_currentState == 'exercise' || _currentState == 'water') {
      // Exercise window finished or ignored. Back to work.
      _currentState = 'work';
      _remainingSeconds = _workIntervalSeconds;
      _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
      _bellPlayed = false;
      
      // Advance cycle
      _cycleIndex = (_cycleIndex + 1) % 4; // 0, 1, 2, 3 (water)
    }
    
    await _saveState();
  }

  Future<void> _playBell() async {
    try {
      // Currently using a unified beep for all options.
      // Later we can add different sound files for 'ringtone' and 'alarm'.
      for (int i = 0; i < 3; i++) {
        await _audioPlayer?.play(AssetSource('sounds/bell.wav'));
        await Future.delayed(const Duration(seconds: 1));
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  void _updateNotification() {
    String title = 'GET UP ACTIVE';
    String text = '';

    String formatTime(int secs) {
      int m = secs ~/ 60;
      int s = secs % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    if (_currentState == 'ready') {
      text = 'Ready to start!';
    } else if (_currentState == 'work') {
      String nextTask = _cycleIndex >= 3 
          ? "Drink Water" 
          : "${_exercises[_cycleIndex]['reps']} ${_exercises[_cycleIndex]['name']}";
      text = 'Next: $nextTask | ${formatTime(_remainingSeconds)}';
    } else if (_currentState == 'exercise') {
      String task = "${_exercises[_cycleIndex]['reps']} ${_exercises[_cycleIndex]['name']}";
      text = '$task! Window: ${formatTime(_remainingSeconds)}';
    } else if (_currentState == 'water') {
      text = 'Drink Water! Window: ${formatTime(_remainingSeconds)}';
    } else {
      text = 'Paused';
    }

    FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  Future<void> _updateWidget() async {
    String formatTime(int secs) {
      int m = secs ~/ 60;
      int s = secs % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    String nextTask = _cycleIndex >= 3 
        ? "Drink Water" 
        : "${_exercises[_cycleIndex]['reps']} ${_exercises[_cycleIndex]['name']}";

    String taskText = "";
    if (_currentState == 'ready') {
      taskText = "Ready to focus";
    } else if (_currentState == 'work') {
      taskText = "Next: $nextTask";
    } else if (_currentState == 'exercise' || _currentState == 'water') {
      taskText = "NOW: $nextTask";
    } else if (_currentState == 'paused') {
      if (_pausedState == 'work') {
         taskText = "Next: $nextTask";
      } else {
         taskText = "NOW: $nextTask";
      }
    }

    bool isRunning = _currentState != 'paused' && _currentState != 'ready';
    int targetTimeMs = DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);
    
    int maxSeconds = _workIntervalSeconds;
    if (_currentState == 'exercise' || _currentState == 'water') {
      maxSeconds = _exerciseWindowSeconds;
    }
    int progressVal = maxSeconds - _remainingSeconds;
    if (progressVal < 0) progressVal = 0;

    await HomeWidget.saveWidgetData<String>('widget_state', _currentState.toUpperCase());
    await HomeWidget.saveWidgetData<String>('widget_time', formatTime(_remainingSeconds));
    await HomeWidget.saveWidgetData<String>('widget_next_task', taskText);
    await HomeWidget.saveWidgetData<String>('widget_target_time', targetTimeMs.toString());
    await HomeWidget.saveWidgetData<String>('widget_is_running', isRunning.toString());
    await HomeWidget.saveWidgetData<int>('widget_progress_max', maxSeconds);
    await HomeWidget.saveWidgetData<int>('widget_progress_val', progressVal);
    await HomeWidget.updateWidget(androidName: 'GetUpWidgetProvider');
    await HomeWidget.updateWidget(androidName: 'GetUpWidgetProviderSmall');
  }

  void _updateOverlay() {
    String formatTime(int secs) {
      int m = secs ~/ 60;
      int s = secs % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    String nextTask = _cycleIndex >= 3 
        ? "Drink Water" 
        : "${_exercises[_cycleIndex]['reps']} ${_exercises[_cycleIndex]['name']}";

    String taskText = "";
    if (_currentState == 'ready') {
      taskText = "Ready to focus";
    } else if (_currentState == 'work') {
      taskText = "Next: $nextTask";
    } else if (_currentState == 'exercise' || _currentState == 'water') {
      taskText = "NOW: $nextTask";
    } else if (_currentState == 'paused') {
      if (_pausedState == 'work') {
         taskText = "Next: $nextTask";
      } else {
         taskText = "NOW: $nextTask";
      }
    }

    try {
      FlutterOverlayWindow.shareData({
        'state': _currentState,
        'timeStr': formatTime(_remainingSeconds),
        'taskText': taskText,
      });
    } catch (e) {
      // Ignore if no overlay
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _saveState();
    _audioPlayer?.dispose();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      if (data['action'] == 'pause') {
        if (_currentState != 'paused') {
          _pausedState = _currentState;
        }
        _currentState = 'paused';
        _targetTime = null;
        _saveState();
        _updateNotification();
        _updateWidget();
        _updateOverlay();
        FlutterForegroundTask.sendDataToMain(_buildStateMap());
      } else if (data['action'] == 'resume') {
        if (_currentState == 'ready') {
          _currentState = 'work';
          _remainingSeconds = _workIntervalSeconds;
          _bellPlayed = false;
        } else {
          _currentState = _pausedState;
        }
        _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
        _saveState();
        _updateNotification();
        _updateWidget();
        _updateOverlay();
        FlutterForegroundTask.sendDataToMain(_buildStateMap());
      } else if (data['action'] == 'toggle') {
        if (_currentState == 'paused') {
          _currentState = _pausedState;
          _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
        } else if (_currentState == 'ready') {
          _currentState = 'work';
          _remainingSeconds = _workIntervalSeconds;
          _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
          _bellPlayed = false;
        } else {
          _pausedState = _currentState;
          _currentState = 'paused';
          _targetTime = null;
        }
        _saveState();
        _updateNotification();
        _updateWidget();
        _updateOverlay();
        FlutterForegroundTask.sendDataToMain(_buildStateMap());
      } else if (data['action'] == 'skip_or_done') {
        if (_currentState == 'exercise' || _currentState == 'water') {
          _remainingSeconds = 0;
          if (!_isTransitioning) {
            _isTransitioning = true;
            _transitionState().whenComplete(() => _isTransitioning = false);
          }
        }
      } else if (data['action'] == 'reload_settings') {
        _loadSettings().then((_) {
          String activeState = _currentState == 'paused' ? _pausedState : _currentState;
          if (activeState == 'work' || activeState == 'ready') {
            _remainingSeconds = _workIntervalSeconds;
          } else if (activeState == 'exercise' || activeState == 'water') {
            _remainingSeconds = _exerciseWindowSeconds;
          }
          if (_currentState != 'paused' && _currentState != 'ready') {
            _targetTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
          }
          _saveState();
          _updateNotification();
          _updateWidget();
          _updateOverlay();
        FlutterForegroundTask.sendDataToMain(_buildStateMap());
        });
      } else if (data['action'] == 'reset') {
        _currentState = 'ready';
        _pausedState = 'work';
        _remainingSeconds = _workIntervalSeconds;
        _targetTime = null;
        _bellPlayed = false;
        _saveState();
        _updateNotification();
        _updateWidget();
        _updateOverlay();
        FlutterForegroundTask.sendDataToMain(_buildStateMap());
      } else if (data['action'] == 'reload_and_reset') {
        _loadSettings().then((_) {
          _currentState = 'ready';
          _pausedState = 'work';
          _remainingSeconds = _workIntervalSeconds;
          _targetTime = null;
          _bellPlayed = false;
          _saveState();
          _updateNotification();
          _updateWidget();
          _updateOverlay();
        FlutterForegroundTask.sendDataToMain(_buildStateMap());
        });
      }
    }
  }
  
  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'pause_btn') {
      if (_currentState != 'paused') {
        _pausedState = _currentState;
      }
      _currentState = 'paused';
      _updateNotification();
      _updateOverlay();
      _saveState();
    } else if (id == 'resume_btn') {
       if (_currentState == 'paused') {
          _currentState = _pausedState;
          _updateNotification();
          _updateOverlay();
          _saveState();
       }
    }
  }
}

class BackgroundTimerService {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'get_up_channel_id',
        channelName: 'Get Up Timer',
        channelDescription: 'Keeps the timer running in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<bool> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.restartService();
      return result is ServiceRequestSuccess;
    } else {
      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'GET UP ACTIVE',
        notificationText: 'Starting...',
        serviceTypes: const [ForegroundServiceTypes.specialUse],
        callback: startCallback,
        notificationButtons: [
          const NotificationButton(id: 'pause_btn', text: 'Pause'),
          const NotificationButton(id: 'resume_btn', text: 'Resume'),
        ],
      );
      return result is ServiceRequestSuccess;
    }
  }

  static Future<bool> stopService() async {
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  static void pause() {
    FlutterForegroundTask.sendDataToTask({'action': 'pause'});
  }

  static void resume() {
    FlutterForegroundTask.sendDataToTask({'action': 'resume'});
  }
  
  static void reset() {
    FlutterForegroundTask.sendDataToTask({'action': 'reset'});
  }
  
  static void reloadSettings() {
    FlutterForegroundTask.sendDataToTask({'action': 'reload_settings'});
  }

  static void reloadAndReset() {
        FlutterForegroundTask.sendDataToTask({'action': 'reload_and_reset'});
      }
      
      static void skipOrDone() {
        FlutterForegroundTask.sendDataToTask({'action': 'skip_or_done'});
      }
}
