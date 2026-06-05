import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:localsend_app/config/theme.dart';
import 'package:localsend_app/model/hub/hub_call_state.dart';
import 'package:localsend_app/provider/hub/hub_call_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class HubVideoCallPage extends StatefulWidget {
  const HubVideoCallPage({super.key});

  @override
  State<HubVideoCallPage> createState() => _HubVideoCallPageState();
}

class _HubVideoCallPageState extends State<HubVideoCallPage>
    with Refena, SingleTickerProviderStateMixin {
  Timer? _durationTimer;
  int _durationSeconds = 0;
  bool _isFullscreen = false;
  bool _showControls = true;
  Timer? _controlsTimer;
  String _videoQuality = '720p';

  // Ripple animation for outgoing state
  late AnimationController _rippleCtrl;

  // Animated dots for "Calling..." text
  Timer? _dotsTimer;
  int _dots = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    _resetControlsTimer();
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dots = (_dots + 1) % 4);
    });
  }

  void _startTimer() {
    _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    setState(() => _showControls = true);
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  String get _formattedDuration {
    final m = (_durationSeconds % 3600) ~/ 60;
    final s = _durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final callState = context.watch(hubCallProvider);
    final callNotifier = ref.notifier(hubCallProvider);

    if (callState.status == HubCallStatus.active) _startTimer();
    if (callState.status == HubCallStatus.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted) context.pop(); });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _resetControlsTimer,
        child: Stack(
          children: [
            // Remote video (full screen)
            Positioned.fill(
              child: callState.status == HubCallStatus.active
                  ? RTCVideoView(callNotifier.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF070B14), Color(0xFF0D1220)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (callState.status == HubCallStatus.outgoing)
                            AnimatedBuilder(
                              animation: _rippleCtrl,
                              builder: (context, child) {
                                return SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      for (int i = 0; i < 3; i++) _buildRippleRing(i),
                                      child!,
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)]),
                                  border: Border.all(color: kAccentCyan.withValues(alpha: 0.4)),
                                ),
                                child: const Icon(Icons.videocam_rounded, color: kAccentCyan, size: 36),
                              ),
                            )
                          else
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [Color(0xFF1E3A5C), Color(0xFF0D1E35)]),
                                border: Border.all(color: kAccentCyan.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.person_rounded, color: kAccentCyan, size: 40),
                            ),
                          const SizedBox(height: 16),
                          Text(callState.remoteDevice?.alias ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (callState.status == HubCallStatus.outgoing)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _BlinkingDot(),
                                const SizedBox(width: 6),
                                Text(
                                  'Calling${'.' * _dots}${' ' * (3 - _dots)}',
                                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                ),
                              ],
                            )
                          else
                            Text(
                              callState.status == HubCallStatus.incoming ? 'Incoming Video Call' : '',
                              style: const TextStyle(color: kAccentCyan, fontSize: 15),
                            ),
                        ],
                      ),
                    ),
            ),

            // Local video (PiP)
            if (callState.status == HubCallStatus.active && callState.isVideoEnabled)
              Positioned(
                top: 50,
                right: 16,
                child: Container(
                  width: 90,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kAccentCyan.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: RTCVideoView(callNotifier.localRenderer, mirror: true),
                  ),
                ),
              ),

            // Top bar
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(callState.remoteDevice?.alias ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          if (callState.status == HubCallStatus.active)
                            Row(
                              children: [
                                const CircleAvatar(radius: 3, backgroundColor: Color(0xFF00E676)),
                                const SizedBox(width: 4),
                                Text(_formattedDuration, style: const TextStyle(color: Color(0xFF00E676), fontSize: 12)),
                              ],
                            ),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _showQualityPicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black.withValues(alpha: 0.5),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(_videoQuality, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom controls
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: callState.status == HubCallStatus.incoming
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _VideoCallBtn(icon: Icons.call_end_rounded, color: Colors.red, label: 'Decline', onTap: () { callNotifier.rejectCall(); context.pop(); }),
                            const SizedBox(width: 56),
                            _VideoCallBtn(icon: Icons.videocam_rounded, color: const Color(0xFF00C853), label: 'Accept', onTap: () => callNotifier.acceptCall()),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _VideoControlBtn(icon: callState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, label: callState.isMuted ? 'Unmute' : 'Mute', active: callState.isMuted, onTap: callNotifier.toggleMute),
                            _VideoControlBtn(icon: callState.isVideoEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded, label: 'Camera', active: !callState.isVideoEnabled, onTap: callNotifier.toggleVideo),
                            _VideoControlBtn(icon: Icons.flip_camera_ios_rounded, label: 'Flip', active: false, onTap: () {}),
                            // Do NOT call context.pop() here — endCall() transitions to
                            // HubCallStatus.ended which the build() watcher pops cleanly.
                            _VideoCallBtn(icon: Icons.call_end_rounded, color: Colors.red, label: 'End', onTap: callNotifier.endCall),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRippleRing(int index) {
    const delay = [0.0, 0.33, 0.66];
    final t = (_rippleCtrl.value + delay[index]) % 1.0;
    final size = 90.0 + t * 90.0;
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

  void _showQualityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Video Quality', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...['240p', '480p', '720p', '1080p', 'Auto'].map((q) => ListTile(
              leading: Icon(Icons.hd_rounded, color: q == _videoQuality ? kAccentCyan : Colors.white54),
              title: Text(q, style: TextStyle(color: q == _videoQuality ? kAccentCyan : Colors.white)),
              trailing: q == _videoQuality ? const Icon(Icons.check_rounded, color: kAccentCyan) : null,
              onTap: () { setState(() => _videoQuality = q); Navigator.pop(context); },
            )),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _controlsTimer?.cancel();
    _dotsTimer?.cancel();
    _rippleCtrl.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
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
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF00E676)),
      ),
    );
  }
}

class _VideoCallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _VideoCallBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16)]),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _VideoControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _VideoControlBtn({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? kAccentCyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: active ? kAccentCyan.withValues(alpha: 0.6) : Colors.transparent),
            ),
            child: Icon(icon, color: active ? kAccentCyan : Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}
