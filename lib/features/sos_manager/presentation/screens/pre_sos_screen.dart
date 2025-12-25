import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'dart:async';

class PreSOSScreen extends StatefulWidget {
  final Function(bool) onConfirm; // Changed to return bool
  final Function(bool) onCancel; // Changed to return bool
  final int countdownSeconds;

  const PreSOSScreen({
    Key? key,
    required this.onConfirm,
    required this.onCancel,
    this.countdownSeconds = 10,
  }) : super(key: key);

  @override
  State<PreSOSScreen> createState() => _PreSOSScreenState();
}

class _PreSOSScreenState extends State<PreSOSScreen>
    with TickerProviderStateMixin {
  late int _remainingSeconds;
  late Timer _timer;
  late AnimationController _pulseController;
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    _setupAnimation();
    _startCountdown();
    _startVibration();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds == 0) {
        _timer.cancel();
        _stopVibration();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    });
  }

  Future<void> _startVibration() async {
    final canVibrate = await Vibration.hasVibrator() ?? false;
    if (!canVibrate) return;

    // Repeat short pulses (like a ringing call) until the dialog closes
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      Vibration.vibrate(duration: 500);
    });
  }

  void _stopVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
    Vibration.cancel();
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    _stopVibration();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated warning icon
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Icon(
                  Icons.warning_rounded,
                  size: 100,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 40),

              // Title
              const Text(
                'EMERGENCY SOS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ACTIVATED',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Countdown Timer - Large Circle
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Text(
                  '$_remainingSeconds',
                  style: const TextStyle(
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Message
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Text(
                      'SOS Alert will be sent in',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_remainingSeconds second${_remainingSeconds != 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap CANCEL to abort emergency alert',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),

              // Cancel Button
              ElevatedButton.icon(
                onPressed: () {
                  if (_timer.isActive) {
                    _timer.cancel();
                  }
                  _stopVibration();
                  if (mounted) {
                    Navigator.of(context).pop(false);
                  }
                },
                icon: const Icon(Icons.close, size: 24),
                label: const Text(
                  'CANCEL SOS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 18,
                  ),
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
