import 'dart:async';

import 'package:flutter/material.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/hub/hub_call_state.dart';
import 'package:localsend_app/provider/hub/hub_call_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class HubVoiceCallPage extends StatefulWidget {
  const HubVoiceCallPage({super.key});

  @override
  State<HubVoiceCallPage> createState() => _HubVoiceCallPageState();
}

class _HubVoiceCallPageState extends State<HubVoiceCallPage> with Refena, SingleTickerProviderStateMixin {
  Timer? _durationTimer;
  int _durationSeconds = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _pulseController.repeat(reverse: true);
  }

  void _startTimer() {
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  String get _formattedDuration {
    final h = _durationSeconds ~/ 3600;
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callState = context.watch(hubCallProvider);

    if (callState.status == HubCallStatus.active) _startTimer();

    if (callState.status == HubCallStatus.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pop();
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF070B14), Color(0xFF0D1220), Color(0xFF111827)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              _buildCallInfo(callState),
              const Spacer(),
              _buildQualityBar(callState),
              const SizedBox(height: 32),
              _buildControls(callState),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallInfo(HubCallState callState) {
    final deviceAlias = callState.remoteDevice?.alias ?? 'Unknown';
    final statusText = switch (callState.status) {
      HubCallStatus.incoming => 'Incoming Call',
      HubCallStatus.outgoing => 'Calling...',
      HubCallStatus.active => _formattedDuration,
      HubCallStatus.ended => 'Call Ended',
      HubCallStatus.idle => '',
    };

    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: kAccentCyan.withValues(alpha: 0.4), width: 2),
              boxShadow: [
                BoxShadow(color: kAccentCyan.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: const Icon(Icons.person_rounded, size: 52, color: kAccentCyan),
          ),
        ),
        const SizedBox(height: 24),
        Text(deviceAlias, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text(statusText, style: const TextStyle(fontSize: 16, color: kAccentCyan, fontWeight: FontWeight.w500)),
        if (callState.isOnHold)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.orange.withValues(alpha: 0.2),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: const Text('On Hold', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _buildQualityBar(HubCallState callState) {
    if (callState.status != HubCallStatus.active) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 8,
                height: 8 + i * 5.0,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: kAccentCyan.withValues(alpha: i < 4 ? 1.0 : 0.3),
                ),
              ),
            )),
          ),
          const SizedBox(height: 6),
          const Text('LAN · Excellent', style: TextStyle(fontSize: 11, color: kAccentCyan)),
        ],
      ),
    );
  }

  Widget _buildControls(HubCallState callState) {
    final isIncoming = callState.status == HubCallStatus.incoming;
    final isActive = callState.status == HubCallStatus.active || callState.status == HubCallStatus.outgoing;

    if (isIncoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CallButton(
            icon: Icons.call_end_rounded,
            color: Colors.red,
            label: 'Decline',
            onTap: () { ref.read(hubCallProvider.notifier).rejectCall(); context.pop(); },
          ),
          const SizedBox(width: 56),
          _CallButton(
            icon: Icons.call_rounded,
            color: const Color(0xFF00C853),
            label: 'Accept',
            onTap: () => ref.read(hubCallProvider.notifier).acceptCall(),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: callState.isMuted ? 'Unmute' : 'Mute',
              active: callState.isMuted,
              onTap: () => ref.read(hubCallProvider.notifier).toggleMute(),
            ),
            const SizedBox(width: 24),
            _ControlButton(
              icon: callState.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
              label: 'Speaker',
              active: callState.isSpeakerOn,
              onTap: () => ref.read(hubCallProvider.notifier).toggleSpeaker(),
            ),
            const SizedBox(width: 24),
            _ControlButton(
              icon: callState.isOnHold ? Icons.play_arrow_rounded : Icons.pause_rounded,
              label: callState.isOnHold ? 'Resume' : 'Hold',
              active: callState.isOnHold,
              onTap: () => ref.read(hubCallProvider.notifier).toggleHold(),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _CallButton(
          icon: Icons.call_end_rounded,
          color: Colors.red,
          label: 'End Call',
          onTap: () { ref.read(hubCallProvider.notifier).endCall(); context.pop(); },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? kAccentCyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: active ? kAccentCyan.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: active ? kAccentCyan : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
    );
  }
}
