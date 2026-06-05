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

class _HubVoiceCallPageState extends State<HubVoiceCallPage>
    with Refena, TickerProviderStateMixin {
  Timer? _durationTimer;
  int _durationSeconds = 0;

  // Avatar pulse when active
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Ripple rings when outgoing (caller waiting)
  late AnimationController _rippleCtrl;

  // Animated dots for "Calling..." text
  Timer? _dotsTimer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
  }

  void _startDurationTimer() {
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  String get _formattedDuration {
    final h = _durationSeconds ~/ 3600;
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _callingText => 'Calling${'.' * _dots}${' ' * (3 - _dots)}';

  @override
  Widget build(BuildContext context) {
    final callState = context.watch(hubCallProvider);

    if (callState.status == HubCallStatus.active) _startDurationTimer();
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
    final alias = callState.remoteDevice?.alias ?? 'Unknown';
    final isOutgoing = callState.status == HubCallStatus.outgoing;
    final isActive = callState.status == HubCallStatus.active;

    final statusText = switch (callState.status) {
      HubCallStatus.incoming => 'Incoming Call',
      HubCallStatus.outgoing => _callingText,
      HubCallStatus.active => _formattedDuration,
      HubCallStatus.ended => 'Call Ended',
      HubCallStatus.idle => '',
    };

    final avatar = ScaleTransition(
      scale: _pulseAnim,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: kAccentCyan.withValues(alpha: 0.4), width: 2),
          boxShadow: [
            BoxShadow(color: kAccentCyan.withValues(alpha: isActive ? 0.3 : 0.15), blurRadius: 30, spreadRadius: 5),
          ],
        ),
        child: const Icon(Icons.person_rounded, size: 52, color: kAccentCyan),
      ),
    );

    return Column(
      children: [
        // Ripple rings only while outgoing (caller waiting for answer)
        if (isOutgoing)
          AnimatedBuilder(
            animation: _rippleCtrl,
            builder: (context, child) {
              return SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 3 expanding rings staggered in time
                    for (int i = 0; i < 3; i++) _buildRippleRing(i),
                    avatar,
                  ],
                ),
              );
            },
          )
        else
          avatar,

        const SizedBox(height: 28),
        Text(
          alias,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        // Status row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isOutgoing) ...[
              // Blinking green dot
              _BlinkDot(),
              const SizedBox(width: 6),
            ],
            Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                color: isOutgoing ? const Color(0xFF00E676) : kAccentCyan,
                fontWeight: FontWeight.w600,
                fontFamily: isOutgoing ? 'monospace' : null,
                letterSpacing: isOutgoing ? 0.5 : 0,
              ),
            ),
          ],
        ),
        if (callState.isOnHold) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.orange.withValues(alpha: 0.2),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
            ),
            child: const Text('On Hold', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _buildRippleRing(int index) {
    const delay = [0.0, 0.33, 0.66];
    final t = (_rippleCtrl.value + delay[index]) % 1.0;
    final size = 110.0 + t * 110.0;
    final opacity = (1.0 - t) * 0.5;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: kAccentCyan.withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildQualityBar(HubCallState callState) {
    if (callState.status != HubCallStatus.active) return const SizedBox.shrink();
    return Column(
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
    );
  }

  Widget _buildControls(HubCallState callState) {
    if (callState.status == HubCallStatus.incoming) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CallButton(
            icon: Icons.call_end_rounded,
            color: Colors.red,
            label: 'Decline',
            onTap: () {
              // rejectCall() sets state → idle (not ended), so we pop manually.
              ref.notifier(hubCallProvider).rejectCall();
              if (context.mounted) context.pop();
            },
          ),
          const SizedBox(width: 56),
          _CallButton(
            icon: Icons.call_rounded,
            color: const Color(0xFF00C853),
            label: 'Accept',
            onTap: () => ref.notifier(hubCallProvider).acceptCall(),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (callState.status == HubCallStatus.active) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: callState.isMuted ? 'Unmute' : 'Mute',
                active: callState.isMuted,
                onTap: () => ref.notifier(hubCallProvider).toggleMute(),
              ),
              const SizedBox(width: 24),
              _ControlButton(
                icon: callState.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                label: 'Speaker',
                active: callState.isSpeakerOn,
                onTap: () => ref.notifier(hubCallProvider).toggleSpeaker(),
              ),
              const SizedBox(width: 24),
              _ControlButton(
                icon: callState.isOnHold ? Icons.play_arrow_rounded : Icons.pause_rounded,
                label: callState.isOnHold ? 'Resume' : 'Hold',
                active: callState.isOnHold,
                onTap: () => ref.notifier(hubCallProvider).toggleHold(),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
        // Do NOT call context.pop() here — endCall() transitions to
        // HubCallStatus.ended which the build() watcher uses to pop cleanly.
        // Popping here too causes a double-pop that can crash the navigator.
        _CallButton(
          icon: Icons.call_end_rounded,
          color: Colors.red,
          label: callState.status == HubCallStatus.outgoing ? 'Cancel' : 'End Call',
          onTap: () => ref.notifier(hubCallProvider).endCall(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _dotsTimer?.cancel();
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }
}

// ── Blinking green dot widget ───────────────────────────────────────────────

class _BlinkDot extends StatefulWidget {
  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = Tween<double>(begin: 0.2, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF00E676),
        ),
      ),
    );
  }
}

// ── Shared button widgets ───────────────────────────────────────────────────

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
              border: Border.all(
                color: active ? kAccentCyan.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15),
              ),
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

