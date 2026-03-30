import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/section_header.dart';
import 'clip_player_screen.dart';

class ClipsScreen extends ConsumerWidget {
  const ClipsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clipsAsync = ref.watch(clipsProvider);
    final filter = ref.watch(clipTypeFilterProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
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
                        TextSpan(text: 'SAVED ', color: AppTheme.textColor),
                        TextSpan(text: 'CLIPS', color: AppTheme.accentColor),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _ClipsStorageBadge(clipsAsync),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => ref.read(clipsProvider.notifier).refresh(),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: const Icon(Icons.refresh,
                              size: 18, color: AppTheme.muted2Color),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Filter chips ──────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'ALL',
                    active: filter == null,
                    onTap: () => ref.read(clipTypeFilterProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 6),
                  ...EventType.values.map((t) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: t.name.toUpperCase(),
                      active: filter == t,
                      onTap: () =>
                          ref.read(clipTypeFilterProvider.notifier).state = t,
                    ),
                  )),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Clips list ────────────────────────────────
            Expanded(
              child: clipsAsync.when(
                data: (clips) {
                  if (clips.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🎞', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 12),
                          Text('No clips yet',
                              style: TextStyle(
                                  color: AppTheme.muted2Color,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }

                  // Group by day
                  final grouped = _groupByDay(clips);
                  return RefreshIndicator(
                    color: AppTheme.accentColor,
                    backgroundColor: AppTheme.surfaceColor,
                    onRefresh: () => ref.read(clipsProvider.notifier).refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: grouped.length,
                      itemBuilder: (ctx, i) {
                        final entry = grouped[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader(
                              title: '${entry.key.toUpperCase()} · ${entry.value.length} CLIP${entry.value.length > 1 ? 'S' : ''}',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 9,
                                crossAxisSpacing: 9,
                                childAspectRatio: 0.85,
                                children: entry.value.map((clip) => _ClipCard(
                                  clip: clip,
                                  onTap: () => Navigator.push(
                                    ctx,
                                    MaterialPageRoute(
                                      builder: (_) => ClipPlayerScreen(clip: clip),
                                    ),
                                  ),
                                  onDelete: () => ref.read(clipsProvider.notifier).deleteClip(clip.id),
                                )).toList(),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.accentColor, strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.redColor, size: 32),
                      const SizedBox(height: 8),
                      Text('Failed to load clips',
                          style: TextStyle(color: AppTheme.muted2Color)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref.read(clipsProvider.notifier).refresh(),
                        child: const Text('Retry', style: TextStyle(color: AppTheme.accentColor)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, List<VideoClip>>> _groupByDay(List<VideoClip> clips) {
    final map = <String, List<VideoClip>>{};
    final now = DateTime.now();
    for (final clip in clips) {
      final diff = now.difference(clip.timestamp).inDays;
      final key = diff == 0
          ? 'Today'
          : diff == 1
              ? 'Yesterday'
              : DateFormat('MMM d').format(clip.timestamp);
      map.putIfAbsent(key, () => []).add(clip);
    }
    return map.entries.toList();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accentColor.withOpacity(0.1) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppTheme.accentColor.withOpacity(0.4)
                : AppTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 10, fontWeight: FontWeight.w700,
            color: active ? AppTheme.accentColor : AppTheme.muted2Color,
          ),
        ),
      ),
    );
  }
}

class _ClipCard extends StatelessWidget {
  final VideoClip clip;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ClipCard({required this.clip, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFF0A1420),
                      child: const Center(
                        child: Text('🎬', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    Positioned(
                      bottom: 5, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          clip.formattedDuration,
                          style: const TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 8, color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    if (clip.isCloudSynced)
                      Positioned(
                        top: 5, right: 6,
                        child: const Icon(Icons.cloud_done,
                            size: 14, color: AppTheme.accentColor),
                      ),
                  ],
                ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('hh:mm a').format(clip.timestamp),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${clip.formattedSize} · ${clip.resolution}',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 8, color: AppTheme.muted2Color,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _EventTag(type: clip.eventType),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTag extends StatelessWidget {
  final EventType type;
  const _EventTag({required this.type});

  Color get _color => switch (type) {
    EventType.motion    => AppTheme.yellowColor,
    EventType.impact    => AppTheme.redColor,
    EventType.sound     => AppTheme.purpleColor,
    EventType.proximity => AppTheme.accentColor,
    EventType.scheduled => AppTheme.greenColor,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.typeLabel,
        style: TextStyle(
          fontFamily: 'Syne', fontSize: 8, fontWeight: FontWeight.w700, color: _color,
        ),
      ),
    );
  }
}

class _ClipsStorageBadge extends StatelessWidget {
  final AsyncValue<List<VideoClip>> clipsAsync;
  const _ClipsStorageBadge(this.clipsAsync);

  @override
  Widget build(BuildContext context) {
    final count = clipsAsync.value?.length ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Text(
        '$count clips',
        style: const TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 10, color: AppTheme.muted2Color,
        ),
      ),
    );
  }
}
