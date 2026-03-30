import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/models.dart';

// ── Sensor Card ───────────────────────────────────────────
class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String sub;
  final Color accentColor;
  final bool isAlert;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.sub,
    required this.accentColor,
    this.isAlert = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: isAlert
            ? accentColor.withOpacity(0.07)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isAlert ? accentColor.withOpacity(0.4) : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent bar
          Container(
            height: 2, width: 24,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Syne',
              fontSize: 8, fontWeight: FontWeight.w700,
              letterSpacing: 1, color: AppTheme.mutedColor,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'Syne'),
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: unit.isEmpty ? 13 : 17,
                    fontWeight: FontWeight.w800,
                    color: isAlert ? accentColor : AppTheme.textColor,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.muted2Color,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isAlert ? accentColor : AppTheme.greenColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 8, fontWeight: FontWeight.w700,
                  color: isAlert ? accentColor : AppTheme.greenColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Event Tile ────────────────────────────────────────────
class EventTile extends StatelessWidget {
  final SecurityEvent event;
  final VoidCallback? onTap;

  const EventTile({super.key, required this.event, this.onTap});

  Color get _color => switch (event.type) {
    EventType.motion    => AppTheme.yellowColor,
    EventType.impact    => AppTheme.redColor,
    EventType.sound     => AppTheme.purpleColor,
    EventType.proximity => AppTheme.accentColor,
    EventType.scheduled => AppTheme.greenColor,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: event.isRead ? AppTheme.surfaceColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: event.isRead ? AppTheme.borderColor : _color.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(event.typeEmoji,
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
            const SizedBox(width: 11),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${event.typeLabel} Detected',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _formatTime(event.timestamp) +
                        (event.sensorValue != null
                            ? ' · ${event.sensorValue!.toStringAsFixed(1)} ${_sensorUnit}'
                            : ''),
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 9, color: AppTheme.muted2Color,
                    ),
                  ),
                ],
              ),
            ),

            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                event.typeLabel,
                style: TextStyle(
                  fontFamily: 'Syne', fontSize: 8,
                  fontWeight: FontWeight.w700, color: _color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today · ${DateFormat('hh:mm a').format(dt)}';
    if (diff.inDays == 1) return 'Yesterday · ${DateFormat('hh:mm a').format(dt)}';
    return DateFormat('MMM d · hh:mm a').format(dt);
  }

  String get _sensorUnit => switch (event.type) {
    EventType.vibrationG => 'g',
    EventType.proximity  => 'm',
    _                    => '',
  };
}

// ── Section Header ────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(
            fontFamily: 'Syne',
            fontSize: 10, fontWeight: FontWeight.w700,
            letterSpacing: 2, color: AppTheme.mutedColor,
          )),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: const TextStyle(
                fontSize: 10, color: AppTheme.accentColor,
              )),
            ),
        ],
      ),
    );
  }
}
