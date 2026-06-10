import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble> {
  String timeStr = "00:00";
  String currentState = "ready";
  String taskText = "";

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        if (mounted) {
          setState(() {
            timeStr = event['timeStr'] ?? timeStr;
            currentState = event['state'] ?? currentState;
            taskText = event['taskText'] ?? taskText;
          });
        }
      }
    });
  }

  void _launchApp() {
    FlutterForegroundTask.launchApp();
    FlutterOverlayWindow.closeOverlay();
  }

  void _togglePlayPause() {
    FlutterOverlayWindow.shareData({'action': 'toggle'});
  }

  void _skipOrDone() {
    FlutterOverlayWindow.shareData({'action': 'skip_or_done'});
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = const Color(0xFF121212);
    Color accentColor = const Color(0xFF00E676);
    
    bool isRunning = currentState != 'paused' && currentState != 'ready';

    if (currentState == 'work') {
      bgColor = const Color(0xFF0F2016);
      accentColor = const Color(0xFF00E676);
    } else if (currentState == 'exercise') {
      bgColor = const Color(0xFF2A1005);
      accentColor = const Color(0xFFFF3D00);
    } else if (currentState == 'water') {
      bgColor = const Color(0xFF081825);
      accentColor = const Color(0xFF00B0FF);
    } else if (currentState == 'paused') {
      bgColor = const Color(0xFF121212);
      accentColor = Colors.grey;
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _launchApp,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (taskText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    taskText,
                    style: TextStyle(
                      color: accentColor.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, color: accentColor, size: 32),
                    onPressed: _togglePlayPause,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 30),
                    onPressed: () => FlutterOverlayWindow.closeOverlay(),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
