import 'package:flutter/material.dart';
import '../controllers/music_controller.dart';
import '../models/song.dart';
import 'theme.dart';
import 'widgets.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    super.key,
    required this.controller,
    required this.onAdd,
  });
  final MusicController controller;
  final void Function(Song) onAdd;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final song = controller.currentSong;
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Thu nhỏ trình phát',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Column(
            children: [
              Text(
                'ĐANG PHÁT',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2,
                  color: AppColors.muted,
                ),
              ),
              SizedBox(height: 4),
              Text('Giai điệu của bạn', style: TextStyle(fontSize: 14)),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: 'Thêm vào playlist',
              onPressed: song == null ? null : () => onAdd(song),
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          ],
        ),
        body: song == null
            ? const EmptyState(
                icon: Icons.headphones_rounded,
                title: 'Chọn một bài hát',
                subtitle: 'Khám phá một giai điệu để bắt đầu.',
              )
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final coverSize = (constraints.maxWidth - 64).clamp(
                      160.0,
                      360.0,
                    );
                    return SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF8E7AD2,
                                        ).withValues(alpha: .18),
                                        blurRadius: 60,
                                        offset: const Offset(0, 18),
                                      ),
                                    ],
                                  ),
                                  child: SongCover(
                                    song: song,
                                    size: coverSize,
                                    radius: 24,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.headlineMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            song.artist,
                                            style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip:
                                          controller.favorites.contains(song.id)
                                          ? 'Bỏ thích'
                                          : 'Thích bài hát',
                                      onPressed: controller.libraryLoading
                                          ? null
                                          : () =>
                                                controller.toggleFavorite(song),
                                      icon: Icon(
                                        controller.favorites.contains(song.id)
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: AppColors.accent,
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                if (controller.error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      controller.error!,
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                PlaybackProgress(controller: controller),
                                const SizedBox(height: 24),
                                PlaybackControls(controller: controller),
                                const SizedBox(height: 36),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.wifi_rounded,
                                        color: AppColors.accent,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Phát trực tuyến',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${song.genre} • SoundHelix',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.equalizer_rounded,
                                        color: AppColors.muted,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 26),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Tiếp theo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                    Text(
                                      '${controller.queue.length} bài hát',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...controller.queue.asMap().entries.map(
                                  (entry) => SongTile(
                                    song: entry.value,
                                    controller: controller,
                                    onPlay: () => controller.playSongs(
                                      controller.queue,
                                      index: entry.key,
                                    ),
                                    onAdd: () => onAdd(entry.value),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      );
    },
  );
}
