import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/models.dart';
import '../widgets/section_header.dart';

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceAsync = ref.watch(deviceStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accentColor,
          backgroundColor: AppTheme.surfaceColor,
          onRefresh: () => ref.read(deviceStatusProvider.notifier).refresh(),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'Syne', fontSize: 22,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3,
                    ),
                    children: [
                      TextSpan(text: 'SYSTEM ', style: TextStyle(color: AppTheme.textColor)),
                      TextSpan(text: 'STATUS', style: TextStyle(color: AppTheme.accentColor)),
                    ],
                  ),
                ),
              ),

              deviceAsync.when(
                data: (status) => status != null
                    ? _StatusBody(status: status)
                    : const _OfflineCard(),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(
                      color: AppTheme.accentColor, strokeWidth: 2,
                    ),
                  ),
                ),
                error: (_, __) => const _OfflineCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  final DeviceStatus status;
  const _StatusBody({required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Storage ring
        _StorageRing(storage: status.storage),
        // Storage bars
        _StorageBars(storage: status.storage),
        // Diagnostics
        const SectionHeader(title: 'HARDWARE DIAGNOSTICS'),
        _DiagnosticsGrid(status: status),
        // Backend status
        const SectionHeader(title: 'BACKEND SERVICES'),
        _BackendCards(),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _StorageRing extends StatelessWidget {
  final StorageInfo storage;
  const _StorageRing({required this.storage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: SizedBox(
          width: 160, height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(160, 160),
                painter: _RingPainter(progress: storage.usedPercent),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(storage.usedPercent * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontFamily: 'Syne',
                      fontSize: 32, fontWeight: FontWeight.w800,
                      color: AppTheme.greenColor,
                    ),
                  ),
                  const Text(
                    'STORAGE',
                    style: TextStyle(
                      fontFamily: 'Syne', fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.5,
                      color: AppTheme.mutedColor,
                    ),
                  ),
                  Text(
                    '${storage.formatBytes(storage.totalBytes)} total',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9, color: AppTheme.mutedColor,
                    ),
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

class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    const strokeWidth = 9.0;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    // Background track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, 2 * math.pi, false,
      Paint()
        ..color = AppTheme.surface2
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Progress fill
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()
        ..color = progress > 0.85 ? AppTheme.redColor : AppTheme.greenColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _StorageBars extends StatelessWidget {
  final StorageInfo storage;
  const _StorageBars({required this.storage});

  @override
  Widget build(BuildContext context) {
    final total = storage.totalBytes.toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          _Bar('Video',    storage.videoBytes, total, AppTheme.accentColor, storage),
          const SizedBox(height: 9),
          _Bar('Logs',     storage.logsBytes,  total, AppTheme.purpleColor, storage),
          const SizedBox(height: 9),
          _Bar('Free',     storage.freeBytes,  total, AppTheme.mutedColor, storage),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int bytes;
  final double total;
  final Color color;
  final StorageInfo storage;

  const _Bar(this.label, this.bytes, this.total, this.color, this.storage);

  @override
  Widget build(BuildContext context) {
    final frac = (bytes / total).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 9, color: AppTheme.muted2Color,
          )),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(
              height: 5,
              color: AppTheme.surface2,
              child: FractionallySizedBox(
                widthFactor: frac,
                alignment: Alignment.centerLeft,
                child: Container(color: color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 50,
          child: Text(
            storage.formatBytes(bytes),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono', fontSize: 9, color: AppTheme.textColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsGrid extends StatelessWidget {
  final DeviceStatus status;
  const _DiagnosticsGrid({required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
        children: [
          const _DiagCard('🔋', 'Power',     'STABLE',  AppTheme.greenColor,  'USB-C 5V / 2A'),
          _DiagCard('📶', 'WiFi',      '${status.wifiRssi} dBm', AppTheme.accentColor, 'Signal strength'),
          _DiagCard('🌡', 'MCU Temp',  '${status.mcuTempC.toStringAsFixed(0)}°C',
              status.mcuTempC > 70 ? AppTheme.redColor : AppTheme.textColor, 'ESP32 internal'),
          _DiagCard('⏱', 'Uptime',    status.formattedUptime, AppTheme.textColor, 'Since last reboot'),
          _DiagCard('🔧', 'Firmware',  status.firmwareVersion, AppTheme.accentColor, 'ESP32 OTA'),
          const _DiagCard('🛡', 'Encryption','AES-256', AppTheme.greenColor, 'Data at rest + transit'),
        ],
      ),
    );
  }
}

class _DiagCard extends StatelessWidget {
  final String icon, label, value;
  final Color valueColor;
  final String sub;

  const _DiagCard(this.icon, this.label, this.value, this.valueColor, this.sub);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const Spacer(),
          Text(value, style: TextStyle(
            fontFamily: 'Syne', fontSize: 14,
            fontWeight: FontWeight.w800, color: valueColor,
          )),
          Text(label, style: const TextStyle(
            fontFamily: 'JetBrains Mono', fontSize: 8, color: AppTheme.muted2Color,
          )),
        ],
      ),
    );
  }
}

class _BackendCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _ServiceRow('🐍', 'FastAPI Backend', 'api.carguard.io · PostgreSQL · JWT', 'ONLINE', AppTheme.greenColor),
          SizedBox(height: 8),
          _ServiceRow('☁️', 'Cloud Storage (AWS S3)', 'AES-256 · Auto-sync ON', 'SYNCED', AppTheme.accentColor),
          SizedBox(height: 8),
          _ServiceRow('🔥', 'Firebase FCM', 'Push delivery active · v2', 'ACTIVE', AppTheme.greenColor),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final String icon, name, sub, status;
  final Color statusColor;

  const _ServiceRow(this.icon, this.name, this.sub, this.status, this.statusColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700)),
                Text(sub, style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 9, color: AppTheme.muted2Color,
                )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(status, style: TextStyle(
              fontFamily: 'Syne', fontSize: 9,
              fontWeight: FontWeight.w700, color: statusColor,
            )),
          ),
        ],
      ),
    );
  }
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            Text('📡', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('Device unreachable',
                style: TextStyle(color: AppTheme.muted2Color, fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Check WiFi and ESP32 power',
                style: TextStyle(color: AppTheme.mutedColor, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
