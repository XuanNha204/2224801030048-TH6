import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalog.dart';
import '../models/song.dart';

class MusicController extends ChangeNotifier {
  MusicController({
    required this.preferences,
    AudioPlayer? audioPlayer,
    this.auth,
    this.firestore,
    this.firebaseSetupError,
  }) : player = audioPlayer ?? AudioPlayer() {
    _subscriptions.add(player.playerStateStream.listen((_) => _notify()));
    _subscriptions.add(player.currentIndexStream.listen((_) => _notify()));
    _subscriptions.add(
      player.errorStream.listen((_) {
        error = 'Không thể phát bài hát. Kiểm tra kết nối và thử lại.';
        loading = false;
        _notify();
      }),
    );
  }

  final SharedPreferences preferences;
  final AudioPlayer player;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final String? firebaseSetupError;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _cloudSubscription;
  List<Song> queue = [];
  Set<String> favorites = {};
  List<MusicPlaylist> playlists = [];
  User? user;
  String? error;
  bool loading = false;
  bool libraryLoading = false;
  bool _disposed = false;
  int _loadVersion = 0;
  int _scopeVersion = 0;
  final Map<int, int> _pendingSaves = {};
  int _requestedIndex = 0;
  Future<void> _saveTask = Future.value();

  bool get firebaseAvailable => auth != null;
  bool get playing =>
      player.playing && player.processingState != ProcessingState.completed;
  bool get buffering =>
      loading ||
      player.processingState == ProcessingState.loading ||
      player.processingState == ProcessingState.buffering;
  Song? get currentSong {
    if (queue.isEmpty) return null;
    final index = loading ? _requestedIndex : player.currentIndex ?? 0;
    return queue[index.clamp(0, queue.length - 1)];
  }

  List<Song> get likedSongs =>
      catalog.where((song) => favorites.contains(song.id)).toList();
  String get _storageKey => 'library_${user?.uid ?? 'guest'}';

  Future<void> initialize({bool configureAudioSession = true}) async {
    await _loadLibrary(null);
    if (auth != null) {
      _subscriptions.add(
        auth!.authStateChanges().listen((nextUser) {
          unawaited(_loadLibrary(nextUser));
        }),
      );
    }
    if (configureAudioSession) {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.music());
      } catch (_) {
        // Some browsers do not provide a native audio session.
      }
    }
  }

  Future<void> _loadLibrary(User? nextUser) async {
    final version = ++_scopeVersion;
    await _cloudSubscription?.cancel();
    if (_disposed || version != _scopeVersion) return;
    user = nextUser;
    favorites = {};
    playlists = [];
    libraryLoading = false;
    final saved = preferences.getString(_storageKey);
    if (saved != null) {
      try {
        _decodeLibrary(jsonDecode(saved) as Map<String, dynamic>);
      } catch (_) {
        error =
            'Dữ liệu thư viện trên máy bị lỗi. Bạn có thể tạo lại playlist.';
      }
    }
    _notify();
    if (nextUser == null || firestore == null) return;
    libraryLoading = true;
    _notify();
    _cloudSubscription = firestore!
        .collection('users')
        .doc(nextUser.uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (version != _scopeVersion ||
                _disposed ||
                (_pendingSaves[version] ?? 0) > 0) {
              return;
            }
            final data = snapshot.data();
            if (data != null) {
              try {
                _decodeLibrary(data);
                unawaited(
                  preferences.setString(
                    _storageKey,
                    jsonEncode(_libraryJson()),
                  ),
                );
              } catch (_) {
                error = 'Không đọc được thư viện cá nhân.';
              }
            }
            libraryLoading = false;
            _notify();
          },
          onError: (Object _) {
            if (version != _scopeVersion) return;
            libraryLoading = false;
            error =
                'Chưa đồng bộ được thư viện. Kiểm tra mạng và quyền Firestore.';
            _notify();
          },
        );
  }

  void _decodeLibrary(Map<String, dynamic> data) {
    favorites = Set<String>.from(data['favorites'] as List? ?? []);
    final existing = {for (final playlist in playlists) playlist.id: playlist};
    playlists = (data['playlists'] as List? ?? [])
        .map(
          (item) =>
              MusicPlaylist.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .map((decoded) {
          final current = existing[decoded.id];
          if (current == null || current.name != decoded.name) return decoded;
          current.songIds
            ..clear()
            ..addAll(decoded.songIds);
          return current;
        })
        .toList();
  }

  Map<String, dynamic> _libraryJson() => {
    'favorites': favorites.toList(),
    'playlists': playlists.map((p) => p.toJson()).toList(),
  };

  Future<void> _saveLibrary() {
    final key = _storageKey;
    final uid = user?.uid;
    // JSON round-trip captures an immutable snapshot before queued writes.
    final data = jsonDecode(jsonEncode(_libraryJson())) as Map<String, dynamic>;
    final version = _scopeVersion;
    _pendingSaves[version] = (_pendingSaves[version] ?? 0) + 1;
    _saveTask = _saveTask.then((_) async {
      try {
        await preferences.setString(key, jsonEncode(data));
        if (uid != null && firestore != null) {
          await firestore!
              .collection('users')
              .doc(uid)
              .set({
                ...data,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 8));
        }
      } catch (_) {
        if (version == _scopeVersion) {
          error = 'Chưa lưu được thư viện. Kiểm tra kết nối và thử lại.';
          _notify();
        }
      } finally {
        final remaining = (_pendingSaves[version] ?? 1) - 1;
        if (remaining == 0) {
          _pendingSaves.remove(version);
        } else {
          _pendingSaves[version] = remaining;
        }
      }
    });
    return _saveTask;
  }

  Future<void> toggleFavorite(Song song) async {
    if (libraryLoading) return;
    if (!favorites.add(song.id)) favorites.remove(song.id);
    _notify();
    await _saveLibrary();
  }

  Future<MusicPlaylist?> createPlaylist(String name) async {
    if (libraryLoading || name.trim().isEmpty) return null;
    final playlist = MusicPlaylist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
    );
    playlists.add(playlist);
    _notify();
    await _saveLibrary();
    return playlist;
  }

  Future<void> addToPlaylist(MusicPlaylist playlist, Song song) async {
    if (libraryLoading || playlist.songIds.contains(song.id)) return;
    playlist.songIds.add(song.id);
    _notify();
    await _saveLibrary();
  }

  Future<void> removeFromPlaylist(MusicPlaylist playlist, Song song) async {
    if (libraryLoading) return;
    playlist.songIds.remove(song.id);
    _notify();
    await _saveLibrary();
  }

  Future<void> deletePlaylist(MusicPlaylist playlist) async {
    if (libraryLoading) return;
    playlists.removeWhere((p) => p.id == playlist.id);
    _notify();
    await _saveLibrary();
  }

  List<Song> songsIn(MusicPlaylist playlist) => playlist.songIds
      .map((id) => catalog.where((song) => song.id == id).firstOrNull)
      .whereType<Song>()
      .toList();

  Future<void> playSongs(List<Song> songs, {int index = 0}) async {
    if (songs.isEmpty) return;
    final version = ++_loadVersion;
    loading = true;
    _requestedIndex = index.clamp(0, songs.length - 1);
    error = null;
    queue = List.of(songs);
    _notify();
    try {
      await player.setAudioSources(
        songs
            .map((song) => AudioSource.uri(Uri.parse(song.url), tag: song))
            .toList(),
        initialIndex: _requestedIndex,
        initialPosition: Duration.zero,
      );
      if (version != _loadVersion || _disposed) return;
      loading = false;
      _notify();
      unawaited(_perform(() => player.play()));
    } on PlayerInterruptedException {
      // A newer selection superseded this request.
    } catch (_) {
      if (version == _loadVersion) {
        loading = false;
        error = 'Không tải được bài hát. Kiểm tra mạng hoặc chọn bài khác.';
        _notify();
      }
    }
  }

  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      error = 'Không thực hiện được thao tác phát nhạc. Vui lòng thử lại.';
      _notify();
    }
  }

  Future<void> togglePlayback() async {
    if (currentSong == null || buffering) return;
    if (error != null || player.processingState == ProcessingState.idle) {
      await playSongs(queue, index: player.currentIndex ?? 0);
      return;
    }
    if (playing) {
      await _perform(() => player.pause());
    } else {
      if (player.processingState == ProcessingState.completed) {
        await _perform(() => player.seek(Duration.zero, index: 0));
      }
      unawaited(_perform(() => player.play()));
    }
  }

  Future<void> next() => _perform(() async {
    if (queue.isEmpty || buffering) return;
    if (player.hasNext) {
      await player.seekToNext();
    } else {
      await player.seek(Duration.zero, index: 0);
    }
  });

  Future<void> previous() => _perform(() async {
    if (queue.isEmpty || buffering) return;
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
    } else if (player.hasPrevious) {
      await player.seekToPrevious();
    } else {
      await player.seek(Duration.zero, index: queue.length - 1);
    }
  });

  Future<void> seek(Duration position) => _perform(() => player.seek(position));
  Future<void> toggleShuffle() => _perform(() async {
    await player.setShuffleModeEnabled(!player.shuffleModeEnabled);
    _notify();
  });
  Future<void> cycleRepeat() => _perform(() async {
    final modes = [LoopMode.off, LoopMode.all, LoopMode.one];
    await player.setLoopMode(modes[(modes.indexOf(player.loopMode) + 1) % 3]);
    _notify();
  });
  Future<void> signOut() async {
    await _saveTask;
    await auth?.signOut();
  }

  void clearError() {
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_cloudSubscription?.cancel() ?? Future.value());
    unawaited(player.dispose());
    super.dispose();
  }
}
