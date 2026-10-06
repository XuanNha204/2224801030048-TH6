import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../controllers/music_controller.dart';
import '../models/song.dart';
import 'theme.dart';

class SongCover extends StatelessWidget {
  const SongCover({
    super.key,
    required this.song,
    this.size = 56,
    this.radius = 12,
  });
  final Song song;
  final double size;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/covers/${song.id}.jpg',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.network(
          song.coverUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF68548E), Color(0xFF263B50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: size * .4,
              color: Colors.white70,
            ),
          ),
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
          ),
          child: Icon(icon, color: AppColors.accent, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.controller,
    required this.onPlay,
    required this.onAdd,
    this.onRemove,
    this.number,
  });
  final Song song;
  final MusicController controller;
  final VoidCallback onPlay;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final selected = controller.currentSong?.id == song.id;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPlay,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 2, 10),
            child: Row(
              children: [
                if (number != null) ...[
                  SizedBox(
                    width: 22,
                    child: Text(
                      '$number',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                SongCover(song: song, size: 52, radius: 10),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.accent : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected && controller.playing)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                IconButton(
                  tooltip: controller.favorites.contains(song.id)
                      ? 'Bỏ thích'
                      : 'Thích bài hát',
                  onPressed: controller.libraryLoading
                      ? null
                      : () => controller.toggleFavorite(song),
                  icon: Icon(
                    controller.favorites.contains(song.id)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 21,
                    color: controller.favorites.contains(song.id)
                        ? AppColors.accent
                        : AppColors.muted,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn bài hát',
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.muted,
                  ),
                  onSelected: (value) {
                    if (value == 'add') {
                      onAdd();
                    } else {
                      onRemove?.call();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'add',
                      child: Text('Thêm vào playlist'),
                    ),
                    if (onRemove != null)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Xóa khỏi playlist'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String formatDuration(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class PlaybackProgress extends StatefulWidget {
  const PlaybackProgress({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final MusicController controller;
  final bool compact;
  @override
  State<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<PlaybackProgress> {
  double? _dragValue;
  @override
  Widget build(BuildContext context) => StreamBuilder<Duration?>(
    stream: widget.controller.player.durationStream,
    initialData: widget.controller.player.duration,
    builder: (context, durationSnapshot) => StreamBuilder<Duration>(
      stream: widget.controller.player.positionStream,
      initialData: widget.controller.player.position,
      builder: (context, positionSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final total = duration.inMilliseconds.toDouble();
        final position = positionSnapshot.data ?? Duration.zero;
        final value = (_dragValue ?? position.inMilliseconds.toDouble()).clamp(
          0.0,
          total > 0 ? total : 1.0,
        );
        if (widget.compact) {
          return LinearProgressIndicator(
            value: total > 0 ? value / total : 0,
            minHeight: 2,
            backgroundColor: AppColors.border,
          );
        }
        return Column(
          children: [
            StreamBuilder<Duration>(
              stream: widget.controller.player.bufferedPositionStream,
              initialData: widget.controller.player.bufferedPosition,
              builder: (context, buffered) => SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  label: formatDuration(Duration(milliseconds: value.round())),
                  value: value,
                  min: 0,
                  max: total > 0 ? total : 1,
                  secondaryTrackValue: total > 0
                      ? (buffered.data?.inMilliseconds.toDouble() ?? 0).clamp(
                          value,
                          total,
                        )
                      : 0,
                  onChanged: total > 0 && !widget.controller.loading
                      ? (next) => setState(() => _dragValue = next)
                      : null,
                  onChangeEnd: total > 0
                      ? (next) {
                          widget.controller.seek(
                            Duration(milliseconds: next.round()),
                          );
                          setState(() => _dragValue = null);
                        }
                      : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(formatDuration(Duration(milliseconds: value.round()))),
                  Text(formatDuration(duration)),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.controller, this.size = 56});
  final MusicController controller;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: IconButton.filled(
      tooltip: controller.buffering
          ? 'Đang tải nhạc'
          : controller.playing
          ? 'Tạm dừng'
          : 'Phát nhạc',
      style: IconButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.background,
      ),
      onPressed: controller.buffering ? null : controller.togglePlayback,
      icon: controller.buffering
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            )
          : Icon(
              controller.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: size * .55,
            ),
    ),
  );
}

class PlaybackControls extends StatelessWidget {
  const PlaybackControls({super.key, required this.controller});
  final MusicController controller;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      IconButton(
        tooltip: controller.player.shuffleModeEnabled
            ? 'Tắt phát ngẫu nhiên'
            : 'Phát ngẫu nhiên',
        onPressed: controller.toggleShuffle,
        icon: Icon(
          Icons.shuffle_rounded,
          color: controller.player.shuffleModeEnabled
              ? AppColors.accent
              : AppColors.muted,
        ),
      ),
      IconButton(
        tooltip: 'Bài trước',
        onPressed: controller.buffering ? null : controller.previous,
        icon: const Icon(Icons.skip_previous_rounded, size: 36),
      ),
      PlayButton(controller: controller, size: 72),
      IconButton(
        tooltip: 'Bài tiếp theo',
        onPressed: controller.buffering ? null : controller.next,
        icon: const Icon(Icons.skip_next_rounded, size: 36),
      ),
      IconButton(
        tooltip: switch (controller.player.loopMode) {
          LoopMode.off => 'Bật lặp playlist',
          LoopMode.all => 'Lặp một bài',
          LoopMode.one => 'Tắt lặp',
        },
        onPressed: controller.cycleRepeat,
        icon: Icon(
          controller.player.loopMode == LoopMode.one
              ? Icons.repeat_one_rounded
              : Icons.repeat_rounded,
          color: controller.player.loopMode == LoopMode.off
              ? AppColors.muted
              : AppColors.accent,
        ),
      ),
    ],
  );
}
