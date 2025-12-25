import 'package:flutter/material.dart';
import 'dart:async';

class SOSStatusBar extends StatefulWidget {
  final bool shakeDetectionActive;
  final int secondsUntilNextSOS;
  final bool sosTriggered;

  const SOSStatusBar({
    Key? key,
    required this.shakeDetectionActive,
    required this.secondsUntilNextSOS,
    required this.sosTriggered,
  }) : super(key: key);

  @override
  State<SOSStatusBar> createState() => _SOSStatusBarState();
}

class _SOSStatusBarState extends State<SOSStatusBar> {
  late Timer _updateTimer;

  @override
  void initState() {
    super.initState();
    _startUpdateTimer();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Timer just triggers rebuild, actual value comes from parent
        });
      }
    });
  }

  @override
  void didUpdateWidget(SOSStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parent will always have updated secondsUntilNextSOS
  }

  @override
  void dispose() {
    _updateTimer.cancel();
    super.dispose();
  }

  String _getStatusText() {
    if (widget.sosTriggered) {
      return '⚠️ SOS TRIGGERED! Emergency alert sent.';
    }
    if (widget.secondsUntilNextSOS > 0) {
      final mins = widget.secondsUntilNextSOS ~/ 60;
      final secs = widget.secondsUntilNextSOS % 60;
      return '🔴 SOS Unavailable: ${mins}m ${secs}s';
    }
    if (widget.shakeDetectionActive) {
      return '🟢 Shake Detection: ACTIVE';
    }
    return '⚪ Shake Detection: INACTIVE';
  }

  Color _getStatusColor() {
    if (widget.sosTriggered) {
      return Colors.orange;
    }
    if (widget.secondsUntilNextSOS > 0) {
      return Colors.red;
    }
    if (widget.shakeDetectionActive) {
      return Colors.green;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        border: Border(bottom: BorderSide(color: _getStatusColor(), width: 3)),
      ),
      child: Row(
        children: [
          Icon(
            widget.sosTriggered
                ? Icons.emergency
                : widget.secondsUntilNextSOS > 0
                ? Icons.schedule
                : widget.shakeDetectionActive
                ? Icons.vibration
                : Icons.warning_amber,
            color: _getStatusColor(),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getStatusText(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
