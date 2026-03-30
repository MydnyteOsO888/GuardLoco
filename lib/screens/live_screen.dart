import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/sensor_card.dart';
import '../widgets/event_tile.dart';
import '../widgets/section_header.dart';

class LiveScreen extends ConsumerStatefulWidget {
  const LiveScreen({super.key});

  @override
  ConsumerState<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends ConsumerState<LiveScreen> {
  final _remoteRenderer = RTCVideoRenderer();
  bool _rendererInit = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    setState(() => _rendererInit = true);

    // Start WebRTC connection
    await ref.read(webRtcConnectionProvider.notifier).connect();

    // Attach remote stream to renderer
    final service = ref.read(webRtcServiceProvider);
    service.remoteStream.listen((stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
        });
      }
    });
  }

  @override
  void dispose() {
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceStatusProvider);
    final sensorAsync = ref.watch(sensorStreamProvider);
    final eventsAsync = ref.watch(eventsProvider);
    final webRtcState = ref.watch(webRtcConnectionProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accentColor,
          backgroundColor: AppTheme.surfaceColor,
          onRefresh: () => ref.read(deviceStatusProvider.notifier).refresh(),
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Syne', fontSize: 22,
                            fontWeight: FontWeight.w800, letterSpacing: -0.3,
                          ),
                          children: [
                            TextSpan(text: 'GUARD', color: AppTheme.textColor),
                            TextSpan(text: 'LOCO', color: AppTheme.accentColor),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _DeviceStatusDot(deviceAsync),
                          const SizedBox(width: 8),
                          _IconButton(
                            icon: Icons.notifications_outlined,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Device Info Card ─────────────────────────
              SliverToBoxAdapter(
                child: deviceAsync.when(
                  data: (status) => status != null
                      ? _DeviceCard(status: status)
                      : const SizedBox.shrink(),
                  loading: () => const _ShimmerCard(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // ── WebRTC Video Feed ─────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _VideoFeedCard(
                    renderer: _remoteRenderer,
                    rendererInit: _rendererInit,
                    connectionState: webRtcState,
                    onReconnect: () =>
                        ref.read(webRtcConnectionProvider.notifier).connect(),
                  ),
                ),
              ),

              // ── Arm / Disarm Button ───────────────────────
              SliverToBoxAdapter(
                child: deviceAsync.when(
                  data: (status) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _ArmButton(
                      isArmed: status?.isArmed ?? false,
                      onToggle: (armed) =>
                          ref.read(deviceStatusProvider.notifier).setArmed(armed),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // ── Sensor Strip ──────────────────────────────
              SliverToBoxAdapter(
                child: sensorAsync.when(
                  data: (reading) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SensorCard(
                            label: 'MOTION',
                            value: reading.motionDetected ? 'ACTIVE' : 'CLEAR',
                            unit: '',
                            sub: 'PIR Sensor',
                            accentColor: reading.motionDetected
                                ? AppTheme.redColor
                                : AppTheme.greenColor,
                            isAlert: reading.motionDetected,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SensorCard(
                            label: 'VIBRATION',
                            value: reading.vibrationG.toStringAsFixed(2),
                            unit: 'g',
                            sub: 'MPU-6050',
                            accentColor: reading.vibrationG > 0.5
                                ? AppTheme.redColor
                                : AppTheme.yellowColor,
                            isAlert: reading.vibrationG > 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SensorCard(
                            label: 'DISTANCE',
                            value: reading.ultrasonicMeters.toStringAsFixed(1),
                            unit: 'm',
                            sub: 'HC-SR04',
                            accentColor: reading.ultrasonicMeters < 1.5
                                ? AppTheme.redColor
                                : AppTheme.accentColor,
                            isAlert: reading.ultrasonicMeters < 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

              // ── FCM Status ────────────────────────────────
              const SliverToBoxAdapter(child: _FcmStatusBar()),

              // ── Recent Events ─────────────────────────────
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'RECENT EVENTS',
                  actionLabel: 'All Clips',
                  onAction: () {},
                ),
              ),

              eventsAsync.when(
                data: (events) => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: EventTile(event: events[i]),
                      ),
                      childCount: events.take(4).length,
                    ),
                  ),
                ),
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator(
                    color: AppTheme.accentColor, strokeWidth: 2,
                  )),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────

class _DeviceStatusDot extends StatelessWidget {
  final AsyncValue<DeviceStatus?> status;
  const _DeviceStatusDot(this.status);

  @override
  Widget build(BuildContext context) {
    final isOnline = status.value?.isOnline ?? false;
    return Row(
      children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? AppTheme.greenColor : AppTheme.redColor,
            boxShadow: [
              BoxShadow(
                color: (isOnline ? AppTheme.greenColor : AppTheme.redColor)
                    .withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          isOnline ? 'ONLINE' : 'OFFLINE',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 10, fontWeight: FontWeight.w600,
            color: isOnline ? AppTheme.greenColor : AppTheme.redColor,
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceStatus status;
  const _DeviceCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: AppTheme.accentColor.withOpacity(0.08),
              border: Border.all(color: AppTheme.accentColor.withOpacity(0.2)),
            ),
            child: const Center(child: Text('📷', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ESP32-CAM Unit 1',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  '${status.ipAddress} · ${status.wifiRssi} dBm',
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10, color: AppTheme.muted2Color,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Pill('ONLINE', AppTheme.greenColor),
                    const SizedBox(width: 6),
                    _Pill('1080p · 30fps', AppTheme.accentColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Syne', fontSize: 9, fontWeight: FontWeight.w700, color: color,
        ),
      ),
    );
  }
}

class _VideoFeedCard extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool rendererInit;
  final WebRtcConnectionState connectionState;
  final VoidCallback onReconnect;

  const _VideoFeedCard({
    required this.renderer,
    required this.rendererInit,
    required this.connectionState,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Video or placeholder
            Container(color: const Color(0xFF020408)),
            if (rendererInit &&
                connectionState == WebRtcConnectionState.connected)
              RTCVideoView(renderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
            else
              _FeedPlaceholder(state: connectionState, onReconnect: onReconnect),

            // Overlay badges
            Positioned(
              top: 10, left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: connectionState == WebRtcConnectionState.connected
                      ? AppTheme.redColor
                      : AppTheme.mutedColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (connectionState == WebRtcConnectionState.connected)
                      Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: Colors.white,
                        ),
                      ),
                    Text(
                      connectionState == WebRtcConnectionState.connected
                          ? 'LIVE'
                          : connectionState.name.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                ),
                child: const Text(
                  'WebRTC P2P',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 8, color: AppTheme.accentColor,
                  ),
                ),
              ),
            ),

            // Bottom overlay
            Positioned(
              bottom: 10, right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  Text('1920×1080', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 8, color: Colors.white38)),
                  Text('SRTP Encrypted', style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 8, color: Colors.white24)),
                ],
              ),
            ),

            // Action buttons
            Positioned(
              bottom: 10, left: 10,
              child: Row(
                children: [
                  _FeedBtn(icon: Icons.camera_alt_outlined, onTap: () {}),
                  const SizedBox(width: 6),
                  _FeedBtn(icon: Icons.volume_up_outlined, onTap: () {}),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  final WebRtcConnectionState state;
  final VoidCallback onReconnect;
  const _FeedPlaceholder({required this.state, required this.onReconnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF060810),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state == WebRtcConnectionState.connecting)
              const CircularProgressIndicator(
                color: AppTheme.accentColor, strokeWidth: 2,
              )
            else if (state == WebRtcConnectionState.error)
              Column(
                children: [
                  const Icon(Icons.signal_wifi_off,
                      color: AppTheme.mutedColor, size: 32),
                  const SizedBox(height: 8),
                  const Text('Stream unavailable',
                      style: TextStyle(color: AppTheme.muted2Color, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onReconnect,
                    child: const Text('Reconnect',
                        style: TextStyle(color: AppTheme.accentColor)),
                  ),
                ],
              )
            else
              const CircularProgressIndicator(
                color: AppTheme.accentColor, strokeWidth: 2,
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FeedBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, size: 14, color: Colors.white70),
      ),
    );
  }
}

class _ArmButton extends StatelessWidget {
  final bool isArmed;
  final ValueChanged<bool> onToggle;

  const _ArmButton({required this.isArmed, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isArmed),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isArmed
              ? AppTheme.redColor.withOpacity(0.12)
              : AppTheme.greenColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isArmed
                ? AppTheme.redColor.withOpacity(0.35)
                : AppTheme.greenColor.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isArmed ? '🔴' : '🟢', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              isArmed ? 'SYSTEM ARMED — TAP TO DISARM' : 'DISARMED — TAP TO ARM',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: isArmed ? AppTheme.redColor : AppTheme.greenColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FcmStatusBar extends StatelessWidget {
  const _FcmStatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Firebase Cloud Messaging',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                SizedBox(height: 1),
                Text('Connected · Push delivery active · FCM v2',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9, color: AppTheme.muted2Color,
                    )),
              ],
            ),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.greenColor,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.greenColor.withOpacity(0.4),
                  blurRadius: 6, spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, size: 18, color: AppTheme.muted2Color),
      ),
    );
  }
}
