import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../providers/auth_provider.dart';
import '../widgets/section_header.dart';

class ConfigScreen extends ConsumerWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
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
                        TextSpan(text: 'DEVICE ', color: AppTheme.textColor),
                        TextSpan(text: 'CONFIG', color: AppTheme.accentColor),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _confirmSignOut(context, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.redColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.redColor.withOpacity(0.3)),
                      ),
                      child: const Text('SIGN OUT', style: TextStyle(
                        fontFamily: 'Syne', fontSize: 10,
                        fontWeight: FontWeight.w700, color: AppTheme.redColor,
                      )),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: settingsAsync.when(
                data: (settings) => ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    // Camera / Stream
                    const SectionHeader(title: 'CAMERA / STREAM'),
                    _SettingGroup(children: [
                      _SelectRow(
                        icon: '📹', label: 'Resolution',
                        desc: 'ESP32-CAM capture quality',
                        value: settings['resolution'] ?? '1080p',
                        options: const ['480p', '720p', '1080p'],
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('resolution', v),
                      ),
                      _SelectRow(
                        icon: '⚡', label: 'Frame Rate',
                        desc: 'WebRTC stream FPS',
                        value: '${settings['fps'] ?? 30} FPS',
                        options: const ['10 FPS', '15 FPS', '30 FPS'],
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('fps', int.parse(v.split(' ')[0])),
                      ),
                      _ToggleRow(
                        icon: '🌙', label: 'Night Vision (IR LED)',
                        desc: 'Auto-activate in low light',
                        value: settings['night_vision'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('night_vision', v),
                      ),
                      _ToggleRow(
                        icon: '🔁', label: 'WebRTC P2P Stream',
                        desc: 'STUN/TURN NAT traversal enabled',
                        value: settings['webrtc_enabled'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('webrtc_enabled', v),
                      ),
                    ]),

                    // Alerts / FCM
                    const SectionHeader(title: 'ALERTS / FCM'),
                    _SettingGroup(children: [
                      _ToggleRow(
                        icon: '🏃', label: 'Motion Alerts',
                        desc: 'PIR sensor push via Firebase FCM',
                        value: settings['alert_motion'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('alert_motion', v),
                      ),
                      _ToggleRow(
                        icon: '💥', label: 'Impact / Vibration',
                        desc: 'MPU-6050 · threshold: 0.5g',
                        value: settings['alert_impact'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('alert_impact', v),
                      ),
                      _ToggleRow(
                        icon: '🔊', label: 'Sound Detection',
                        desc: 'Microphone noise level alert',
                        value: settings['alert_sound'] ?? false,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('alert_sound', v),
                      ),
                      _ToggleRow(
                        icon: '📏', label: 'Proximity Alert',
                        desc: 'HC-SR04 ultrasonic · threshold: 1.5m',
                        value: settings['alert_proximity'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('alert_proximity', v),
                      ),
                    ]),

                    // Storage
                    const SectionHeader(title: 'STORAGE'),
                    _SettingGroup(children: [
                      _ToggleRow(
                        icon: '💾', label: 'Local SD Buffer',
                        desc: 'Circular write to MicroSD card',
                        value: settings['local_storage'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('local_storage', v),
                      ),
                      _ToggleRow(
                        icon: '☁️', label: 'Cloud Sync (AWS S3)',
                        desc: 'AES-256 encrypted upload',
                        value: settings['cloud_sync'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('cloud_sync', v),
                      ),
                      _ToggleRow(
                        icon: '🗑', label: 'Auto-Delete Local',
                        desc: 'Remove clips older than 7 days',
                        value: settings['auto_delete'] ?? true,
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('auto_delete', v),
                      ),
                      _SelectRow(
                        icon: '📁', label: 'Clip Buffer Length',
                        desc: 'Recording duration per event',
                        value: '${settings['clip_length'] ?? 30} sec',
                        options: const ['10 sec', '20 sec', '30 sec', '60 sec'],
                        onChanged: (v) => ref.read(settingsProvider.notifier).update('clip_length', int.parse(v.split(' ')[0])),
                      ),
                    ]),

                    // Security / Backend
                    const SectionHeader(title: 'SECURITY / BACKEND'),
                    _SettingGroup(children: [
                      _InfoRow(
                        icon: '🔐', label: 'JWT Authentication',
                        desc: 'FastAPI token · expiry: 24h',
                        value: 'ACTIVE', valueColor: AppTheme.greenColor,
                      ),
                      _ToggleRow(
                        icon: '🔒', label: 'Data Encryption',
                        desc: 'AES-256 in transit + at rest',
                        value: settings['encryption'] ?? true,
                        onChanged: (_) {}, // Always on — read-only
                      ),
                      _InfoRow(
                        icon: '🔄', label: 'Firmware OTA',
                        desc: 'ESP32 over-the-air update',
                        value: 'v2.1.4', valueColor: AppTheme.accentColor,
                      ),
                      _ActionRow(
                        icon: '📶', label: 'WiFi Network',
                        desc: 'HomeNetwork_5G · ESP32',
                        onTap: () {},
                      ),
                      _ActionRow(
                        icon: '🔁', label: 'Reboot ESP32',
                        desc: 'Restart the controller',
                        onTap: () => _confirmReboot(context),
                        dangerous: true,
                      ),
                    ]),

                    const SizedBox(height: 24),
                  ],
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentColor, strokeWidth: 2,
                  ),
                ),
                error: (_, __) => const Center(
                  child: Text('Failed to load settings',
                      style: TextStyle(color: AppTheme.muted2Color)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Sign Out?', style: TextStyle(color: AppTheme.textColor)),
        content: const Text('You will need to sign in again.',
            style: TextStyle(color: AppTheme.muted2Color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted2Color)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.redColor)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authActionsProvider).signOut();
    }
  }

  Future<void> _confirmReboot(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Reboot Device?', style: TextStyle(color: AppTheme.textColor)),
        content: const Text('The ESP32 will restart. Live stream will disconnect briefly.',
            style: TextStyle(color: AppTheme.muted2Color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted2Color)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // ApiService().rebootDevice();
            },
            child: const Text('Reboot', style: TextStyle(color: AppTheme.redColor)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Setting Rows ─────────────────────────────────

class _SettingGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: children.indexed.map((entry) {
          final isLast = entry.$1 == children.length - 1;
          return Column(
            children: [
              entry.$2,
              if (!isLast)
                const Divider(height: 0, color: AppTheme.borderColor,
                    indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String icon, label, desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon, required this.label, required this.desc,
    required this.value, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(desc, style: const TextStyle(fontSize: 9, color: AppTheme.muted2Color)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.greenColor,
            activeTrackColor: AppTheme.greenColor.withOpacity(0.3),
            inactiveThumbColor: AppTheme.mutedColor,
            inactiveTrackColor: AppTheme.borderColor,
          ),
        ],
      ),
    );
  }
}

class _SelectRow extends StatelessWidget {
  final String icon, label, desc, value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SelectRow({
    required this.icon, required this.label, required this.desc,
    required this.value, required this.options, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(desc, style: const TextStyle(fontSize: 9, color: AppTheme.muted2Color)),
                ],
              ),
            ),
            Text(value, style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 11, color: AppTheme.accentColor,
            )),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.mutedColor),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) => ListTile(
            title: Text(opt, style: const TextStyle(color: AppTheme.textColor)),
            trailing: opt == value
                ? const Icon(Icons.check, color: AppTheme.accentColor, size: 18)
                : null,
            onTap: () => Navigator.pop(ctx, opt),
          )),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _InfoRow extends StatelessWidget {
  final String icon, label, desc, value;
  final Color valueColor;

  const _InfoRow({
    required this.icon, required this.label, required this.desc,
    required this.value, required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(desc, style: const TextStyle(fontSize: 9, color: AppTheme.muted2Color)),
              ],
            ),
          ),
          Text(value, style: TextStyle(
            fontFamily: 'JetBrains Mono', fontSize: 11, color: valueColor,
          )),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String icon, label, desc;
  final VoidCallback onTap;
  final bool dangerous;

  const _ActionRow({
    required this.icon, required this.label, required this.desc,
    required this.onTap, this.dangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: dangerous ? AppTheme.redColor : AppTheme.textColor,
                  )),
                  Text(desc, style: const TextStyle(fontSize: 9, color: AppTheme.muted2Color)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.mutedColor),
          ],
        ),
      ),
    );
  }
}
