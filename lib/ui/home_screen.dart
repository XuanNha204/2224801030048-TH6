import 'package:flutter/material.dart';

import '../controllers/music_controller.dart';
import '../data/catalog.dart';
import '../models/song.dart';
import 'auth_screen.dart';
import 'player_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});
  final MusicController controller;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  int _tab = 0;
  String _genre = 'Tất cả';
  MusicPlaylist? _playlist;
  MusicController get music => widget.controller;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openPlayer() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerScreen(controller: music, onAdd: _addToPlaylist),
    ),
  );

  void _play(List<Song> songs, int index) {
    music.playSongs(songs, index: index);
    _openPlayer();
  }

  Future<MusicPlaylist?> _createPlaylist() async {
    final input = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Playlist mới'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 60,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Ví dụ: Một chiều thật chill',
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(dialogContext, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (input.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, input.text.trim());
              }
            },
            child: const Text('Tạo playlist'),
          ),
        ],
      ),
    );
    // The dialog route may still animate while its text field is mounted.
    Future<void>.delayed(const Duration(milliseconds: 300), input.dispose);
    if (name == null || !mounted) return null;
    return music.createPlaylist(name);
  }

  Future<void> _addToPlaylist(Song song) async {
    if (music.libraryLoading) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Thêm vào playlist',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.accent,
                ),
                title: const Text('Tạo playlist mới'),
                onTap: () => Navigator.pop(sheetContext, 'new'),
              ),
              ...music.playlists.map(
                (playlist) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songIds.length} bài hát'),
                  trailing: playlist.songIds.contains(song.id)
                      ? const Icon(Icons.check_rounded, color: AppColors.accent)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, playlist.id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final playlist = selected == 'new'
        ? await _createPlaylist()
        : music.playlists.where((p) => p.id == selected).firstOrNull;
    if (playlist == null || !mounted) return;
    final existed = playlist.songIds.contains(song.id);
    await music.addToPlaylist(playlist, song);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existed
                ? 'Bài hát đã có trong playlist này.'
                : 'Đã thêm vào ${playlist.name}',
          ),
        ),
      );
    }
  }

  void _selectTab(int index) => setState(() {
    _tab = index;
    _playlist = null;
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: music,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 950;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide) _sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1150),
                            child: CustomScrollView(
                              slivers: [
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 36 : 22,
                                    22,
                                    wide ? 36 : 22,
                                    24,
                                  ),
                                  sliver: SliverList.list(
                                    children: [
                                      _header(wide),
                                      const SizedBox(height: 28),
                                      if (music.error != null) _errorBanner(),
                                      if (music.libraryLoading)
                                        const LinearProgressIndicator(),
                                      if (_tab == 0) ..._discover(wide),
                                      if (_tab == 1) ..._library(),
                                      if (_tab == 2) ..._favorites(),
                                      if (_tab == 3) ..._account(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (music.currentSong != null) _miniPlayer(wide),
                      if (!wide)
                        NavigationBar(
                          selectedIndex: _tab,
                          onDestinationSelected: _selectTab,
                          backgroundColor: AppColors.background,
                          indicatorColor: AppColors.accent.withValues(
                            alpha: .14,
                          ),
                          labelBehavior:
                              NavigationDestinationLabelBehavior.alwaysShow,
                          destinations: const [
                            NavigationDestination(
                              icon: Icon(Icons.explore_outlined),
                              selectedIcon: Icon(
                                Icons.explore_rounded,
                                color: AppColors.accent,
                              ),
                              label: 'Khám phá',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.library_music_outlined),
                              selectedIcon: Icon(
                                Icons.library_music_rounded,
                                color: AppColors.accent,
                              ),
                              label: 'Playlist',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.favorite_border_rounded),
                              selectedIcon: Icon(
                                Icons.favorite_rounded,
                                color: AppColors.accent,
                              ),
                              label: 'Yêu thích',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.person_outline_rounded),
                              selectedIcon: Icon(
                                Icons.person_rounded,
                                color: AppColors.accent,
                              ),
                              label: 'Tài khoản',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _logo() => const FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.graphic_eq_rounded, size: 32, color: AppColors.accent),
        SizedBox(width: 8),
        Text(
          'sonic',
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 13),
          child: Text(
            '.',
            style: TextStyle(fontSize: 30, color: AppColors.accent),
          ),
        ),
      ],
    ),
  );

  Widget _sidebar() => Container(
    width: 235,
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppColors.border)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _logo(),
          const SizedBox(height: 48),
          const Text(
            'ÂM NHẠC CỦA BẠN',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.muted,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 16),
          ...[
            'Khám phá',
            'Playlist',
            'Yêu thích',
            'Tài khoản',
          ].asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                selected: _tab == entry.key,
                selectedColor: AppColors.accent,
                selectedTileColor: AppColors.accent.withValues(alpha: .1),
                leading: Icon(
                  [
                    Icons.explore_rounded,
                    Icons.library_music_rounded,
                    Icons.favorite_rounded,
                    Icons.person_rounded,
                  ][entry.key],
                ),
                title: Text(entry.value, style: const TextStyle(fontSize: 14)),
                onTap: () => _selectTab(entry.key),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.headphones_rounded, color: AppColors.accent),
                SizedBox(height: 12),
                Text(
                  'Bật nhạc. Thả mình.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Một chút âm nhạc cho mỗi ngày của bạn.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _header(bool wide) => Row(
    children: [
      if (!wide)
        _logo()
      else
        const Text(
          'Không gian âm nhạc của bạn',
          style: TextStyle(color: AppColors.muted),
        ),
      const Spacer(),
      IconButton.filledTonal(
        tooltip: 'Tài khoản',
        onPressed: () => _selectTab(3),
        icon: const Icon(Icons.person_outline_rounded),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.muted,
        ),
      ),
    ],
  );

  Widget _errorBanner() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(music.error!, style: const TextStyle(fontSize: 12)),
          ),
          IconButton(
            tooltip: 'Đóng thông báo',
            onPressed: music.clearError,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    ),
  );

  List<Widget> _discover(bool wide) {
    final results = catalog
        .where(
          (song) =>
              song.matches(_search.text) &&
              (_genre == 'Tất cả' || song.genre == _genre),
        )
        .toList();
    final searching = _search.text.trim().isNotEmpty;
    return [
      Text(
        'Một ngày, nhiều giai điệu.',
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Tìm thấy âm nhạc cho khoảnh khắc của bạn.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Tìm bài hát, nghệ sĩ...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  onPressed: () => setState(_search.clear),
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
      const SizedBox(height: 24),
      if (!searching) ...[_hero(wide), const SizedBox(height: 28)],
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['Tất cả', 'Electronic', 'Instrumental']
              .map(
                (genre) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text(genre),
                    selected: _genre == genre,
                    showCheckmark: false,
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surface,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: _genre == genre
                          ? AppColors.background
                          : AppColors.muted,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    onSelected: (_) => setState(() => _genre = genre),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(
              searching ? 'Kết quả tìm kiếm' : 'Khám phá hôm nay',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            '${results.length} bài hát',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (results.isEmpty)
        const EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Chưa tìm thấy bài hát',
          subtitle: 'Thử tên bài, nghệ sĩ hoặc chọn thể loại khác.',
        ),
      ...results.asMap().entries.map(
        (entry) => SongTile(
          song: entry.value,
          controller: music,
          number: wide ? entry.key + 1 : null,
          onPlay: () => _play(results, entry.key),
          onAdd: () => _addToPlaylist(entry.value),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Bộ sưu tập nhạc mẫu từ SoundHelix • Ảnh minh họa từ Unsplash',
        style: TextStyle(color: AppColors.muted, fontSize: 11),
        textAlign: TextAlign.center,
      ),
    ];
  }

  Widget _hero(bool wide) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: const Color(0xFF383148),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/covers/sh2.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF383148)),
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xEE2E233F),
                  Color(0x882E233F),
                  Color(0x443E3557),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(wide ? 32 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'DÀNH CHO HÔM NAY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Chạm vào\nnhững giai điệu.',
                style: TextStyle(
                  fontSize: wide ? 40 : 30,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Đeo tai nghe và để âm nhạc dẫn lối.',
                style: TextStyle(color: Color(0xFFD9D3E3), fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _play(catalog, 0),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Nghe ngay'),
              ),
            ],
          ),
        ),
        if (wide)
          const Positioned(
            right: 40,
            top: 70,
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 150,
              color: Color(0x99CBF578),
            ),
          ),
      ],
    ),
  );

  List<Widget> _favorites() {
    final songs = music.likedSongs;
    return [
      _pageTitle(
        'Bài hát yêu thích',
        'Những giai điệu bạn muốn nghe thêm lần nữa.',
      ),
      const SizedBox(height: 24),
      if (songs.isNotEmpty)
        FilledButton.icon(
          onPressed: () => _play(songs, 0),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('Phát ${songs.length} bài hát'),
        ),
      if (songs.isEmpty)
        const EmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'Lưu lại một giai điệu',
          subtitle: 'Nhấn trái tim bên cạnh bài hát để thêm vào đây.',
        ),
      const SizedBox(height: 16),
      ...songs.asMap().entries.map(
        (entry) => SongTile(
          song: entry.value,
          controller: music,
          onPlay: () => _play(songs, entry.key),
          onAdd: () => _addToPlaylist(entry.value),
        ),
      ),
    ];
  }

  Widget _pageTitle(String title, String description) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 10),
      Text(description, style: const TextStyle(color: AppColors.muted)),
    ],
  );

  List<Widget> _library() {
    final current = music.playlists
        .where((p) => p.id == _playlist?.id)
        .firstOrNull;
    if (current != null) {
      final songs = music.songsIn(current);
      return [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _playlist = null),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Tất cả playlist'),
          ),
        ),
        const SizedBox(height: 16),
        _pageTitle(
          current.name,
          '${songs.length} bài hát • Bộ sưu tập của bạn',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: songs.isEmpty ? null : () => _play(songs, 0),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Phát playlist'),
            ),
            OutlinedButton.icon(
              onPressed: () => _selectTab(0),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm bài hát'),
            ),
            IconButton(
              tooltip: 'Xóa playlist',
              onPressed: () async {
                final delete = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Xóa playlist?'),
                    content: Text(
                      'Xóa “${current.name}” khỏi thư viện của bạn?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Giữ lại'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Xóa'),
                      ),
                    ],
                  ),
                );
                if (delete == true && mounted) {
                  await music.deletePlaylist(current);
                  if (mounted) setState(() => _playlist = null);
                }
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (songs.isEmpty)
          const EmptyState(
            icon: Icons.queue_music_rounded,
            title: 'Playlist đang chờ giai điệu',
            subtitle:
                'Vào Khám phá, mở tùy chọn bài hát và chọn Thêm vào playlist.',
          ),
        ...songs.asMap().entries.map(
          (entry) => SongTile(
            song: entry.value,
            controller: music,
            onPlay: () => _play(songs, entry.key),
            onAdd: () => _addToPlaylist(entry.value),
            onRemove: () => music.removeFromPlaylist(current, entry.value),
          ),
        ),
      ];
    }
    return [
      _pageTitle(
        'Playlist của bạn',
        'Gom những bài hát hay thành một câu chuyện.',
      ),
      const SizedBox(height: 24),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: music.libraryLoading
              ? null
              : () async {
                  final playlist = await _createPlaylist();
                  if (playlist != null && mounted) {
                    setState(() => _playlist = playlist);
                  }
                },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tạo playlist'),
        ),
      ),
      const SizedBox(height: 24),
      if (music.playlists.isEmpty)
        const EmptyState(
          icon: Icons.library_music_outlined,
          title: 'Bắt đầu bộ sưu tập của bạn',
          subtitle: 'Tạo playlist đầu tiên cho lúc học, đi dạo hay thư giãn.',
        ),
      ...music.playlists.map((playlist) {
        final songs = music.songsIn(playlist);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            tileColor: AppColors.surface,
            contentPadding: const EdgeInsets.all(14),
            leading: songs.isEmpty
                ? Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF39324C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.queue_music_rounded,
                      color: Color(0xFFBCABFA),
                    ),
                  )
                : SongCover(song: songs.first),
            title: Text(
              playlist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${songs.length} bài hát'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => setState(() => _playlist = playlist),
          ),
        );
      }),
      if (music.user == null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Thư viện khách được lưu trên thiết bị này.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
    ];
  }

  List<Widget> _account() => [
    _pageTitle('Không gian của bạn', 'Âm nhạc luôn ở bên bạn.'),
    const SizedBox(height: 28),
    Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Color(0xFF39324C),
            child: Icon(
              Icons.person_outline_rounded,
              color: Color(0xFFBCABFA),
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            music.user?.email ?? 'Bạn đang nghe với tư cách khách',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            music.user != null
                ? 'Bài yêu thích và playlist được đồng bộ vào tài khoản của bạn.'
                : 'Bài yêu thích và playlist được lưu trên thiết bị. Đăng nhập để đồng bộ thư viện cá nhân.',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          if (music.user == null)
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AuthScreen(controller: music),
                ),
              ),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Đăng nhập / Đăng ký'),
            )
          else
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await music.signOut();
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chưa đăng xuất được. Vui lòng thử lại.'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
            ),
        ],
      ),
    ),
    const SizedBox(height: 24),
    Row(
      children: [
        Expanded(child: _stat('${music.favorites.length}', 'Bài yêu thích')),
        const SizedBox(width: 16),
        Expanded(child: _stat('${music.playlists.length}', 'Playlist')),
      ],
    ),
    const SizedBox(height: 32),
    const Text(
      'Sonic • Bài thực hành 6',
      style: TextStyle(color: AppColors.muted),
    ),
    const SizedBox(height: 8),
    const Text(
      'Nhạc mẫu: SoundHelix / T. Schürger\nẢnh minh họa: Unsplash',
      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.7),
    ),
  ];

  Widget _stat(String value, String label) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    ),
  );

  Widget _miniPlayer(bool wide) {
    final song = music.currentSong!;
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 36 : 12, 0, wide ? 36 : 12, 8),
      child: Material(
        color: const Color(0xFF252A37),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openPlayer,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                child: Row(
                  children: [
                    SongCover(song: song, size: 44, radius: 9),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    PlayButton(controller: music, size: 44),
                    IconButton(
                      tooltip: 'Bài tiếp theo',
                      onPressed: music.buffering ? null : music.next,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
              PlaybackProgress(controller: music, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
