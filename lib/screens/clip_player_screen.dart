import 'package:flutter/material.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ClipPlayerScreen extends StatefulWidget {
  final VideoClip clip;
  const ClipPlayerScreen({super.key, required this.clip});

  @override
  State<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends State<ClipPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      // Get signed stream URL from backend (AWS S3 presigned or local)
      final url = widget.clip.cloudUrl ??
          await ApiService().getClipStreamUrl(widget.clip.id);

      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accentColor,
          handleColor: AppTheme.accentColor,
          bufferedColor: AppTheme.accentColor.withOpacity(0.3),
          backgroundColor: AppTheme.surface2,
        ),
      );

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clip.eventType.typeLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.clip.formattedDuration} · ${widget.clip.formattedSize}',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10, color: AppTheme.muted2Color,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.muted2Color),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.accentColor, strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.redColor, size: 32),
                            const SizedBox(height: 8),
                            Text('Could not load clip',
                                style: TextStyle(color: AppTheme.muted2Color)),
                          ],
                        ),
                      )
                    : Chewie(controller: _chewieController!),
          ),

          // Clip metadata
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _MetaBadge(widget.clip.eventType.typeLabel,
                        _eventColor(widget.clip.eventType)),
                    const SizedBox(width: 8),
                    if (widget.clip.isCloudSynced)
                      _MetaBadge('CLOUD SYNCED', AppTheme.accentColor),
                  ],
                ),
                const SizedBox(height: 16),
                _MetaRow('Resolution', widget.clip.resolution),
                _MetaRow('File size', widget.clip.formattedSize),
                _MetaRow('Duration', widget.clip.formattedDuration),
                _MetaRow('Stored', widget.clip.isCloudSynced ? 'AWS S3 + Local' : 'Local SD Card'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _eventColor(EventType type) => switch (type) {
    EventType.motion    => AppTheme.yellowColor,
    EventType.impact    => AppTheme.redColor,
    EventType.sound     => AppTheme.purpleColor,
    EventType.proximity => AppTheme.accentColor,
    EventType.scheduled => AppTheme.greenColor,
  };

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Clip?',
            style: TextStyle(color: AppTheme.textColor)),
        content: const Text('This will remove the clip from local storage and cloud.',
            style: TextStyle(color: AppTheme.muted2Color)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.muted2Color)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.redColor)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pop(context, widget.clip.id); // Return id to delete
    }
  }
}

class _MetaBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(
        fontFamily: 'Syne', fontSize: 9, fontWeight: FontWeight.w700, color: color,
      )),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String key;
  final String value;
  const _MetaRow(this.key, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(key, style: const TextStyle(
              color: AppTheme.mutedColor, fontSize: 11,
              fontFamily: 'JetBrains Mono',
            )),
          ),
          Text(value, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textColor,
          )),
        ],
      ),
    );
  }
}
