import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonic_music/controllers/music_controller.dart';
import 'package:sonic_music/data/catalog.dart';
import 'package:sonic_music/models/song.dart';

import 'helpers.dart';

Future<void> flushStreams() =>
    Future<void>.delayed(const Duration(milliseconds: 25));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAudioPlayer player;
  late MusicController controller;
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    player = makePlayer();
    controller = MusicController(preferences: preferences, audioPlayer: player);
    await controller.initialize(configureAudioSession: false);
  });
  tearDown(() => controller.dispose());

  test('search ignores Vietnamese accents, case and surrounding spaces', () {
    const song = Song(
      id: 'vi',
      title: 'Một ngày bình yên',
      artist: 'Đức',
      genre: 'Chill',
      url: 'https://example.com/a.mp3',
      coverUrl: 'https://example.com/a.jpg',
    );
    expect(song.matches('  MOT NGAY  '), isTrue);
    expect(song.matches('duc'), isTrue);
    expect(song.matches('rock'), isFalse);
  });

  test('favorites and playlist persist after closing and reopening', () async {
    await controller.toggleFavorite(catalog.first);
    final playlist = (await controller.createPlaylist('  Nhạc học bài  '))!;
    await controller.addToPlaylist(playlist, catalog[2]);
    await controller.addToPlaylist(playlist, catalog[2]);
    final reopened = MusicController(
      preferences: preferences,
      audioPlayer: makePlayer(),
    );
    await reopened.initialize(configureAudioSession: false);
    expect(reopened.favorites, {'sh1'});
    expect(reopened.playlists.single.name, 'Nhạc học bài');
    expect(reopened.songsIn(reopened.playlists.single).single.id, 'sh3');
    reopened.dispose();
    await controller.removeFromPlaylist(playlist, catalog[2]);
    expect(controller.songsIn(playlist), isEmpty);
    await controller.deletePlaylist(playlist);
    expect(controller.playlists, isEmpty);
  });

  test('rapid library mutations persist the latest state', () async {
    await Future.wait([
      controller.toggleFavorite(catalog[0]),
      controller.toggleFavorite(catalog[1]),
      controller.toggleFavorite(catalog[0]),
    ]);
    final reopened = MusicController(
      preferences: preferences,
      audioPlayer: makePlayer(),
    );
    await reopened.initialize(configureAudioSession: false);
    expect(reopened.favorites, {'sh2'});
    reopened.dispose();
  });

  test('selected playlist determines queue and selected index', () async {
    final songs = [catalog[3], catalog[1]];
    await controller.playSongs(songs, index: 1);
    when(() => player.currentIndex).thenReturn(1);
    expect(controller.queue, songs);
    expect(controller.currentSong?.id, 'sh2');
    verify(
      () => player.setAudioSources(
        any(),
        initialIndex: 1,
        initialPosition: Duration.zero,
      ),
    ).called(1);
    verify(() => player.play()).called(1);
    expect(controller.loading, isFalse);
  });

  test('next wraps at end and previous restarts after three seconds', () async {
    controller.queue = catalog.toList();
    when(() => player.hasNext).thenReturn(false);
    await controller.next();
    verify(() => player.seek(Duration.zero, index: 0)).called(1);
    when(() => player.position).thenReturn(const Duration(seconds: 10));
    await controller.previous();
    verify(() => player.seek(Duration.zero)).called(1);
    when(() => player.position).thenReturn(Duration.zero);
    await controller.previous();
    verify(() => player.seek(Duration.zero, index: 7)).called(1);
  });

  test('completed queue can restart and playing track can pause', () async {
    controller.queue = catalog.toList();
    when(() => player.playing).thenReturn(true);
    when(() => player.processingState).thenReturn(ProcessingState.completed);
    expect(controller.playing, isFalse);
    await controller.togglePlayback();
    verify(() => player.seek(Duration.zero, index: 0)).called(1);
    verify(() => player.play()).called(1);
    when(() => player.processingState).thenReturn(ProcessingState.ready);
    await controller.togglePlayback();
    verify(() => player.pause()).called(1);
  });

  test('failed MP3 load clears loading state and permits retry', () async {
    when(
      () => player.setAudioSources(
        any(),
        initialIndex: any(named: 'initialIndex'),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenThrow(PlayerException(404, 'Not found', 0));
    await controller.playSongs([catalog.first]);
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
    when(
      () => player.setAudioSources(
        any(),
        initialIndex: any(named: 'initialIndex'),
        initialPosition: any(named: 'initialPosition'),
      ),
    ).thenAnswer((_) async => const Duration(minutes: 4));
    await controller.togglePlayback();
    expect(controller.error, isNull);
    verify(() => player.play()).called(1);
  });

  test(
    'guest and authenticated libraries remain isolated and synchronize',
    () async {
      controller.dispose();
      final auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'alice', email: 'alice@example.com'),
      );
      final firestore = FakeFirebaseFirestore();
      controller = MusicController(
        preferences: preferences,
        audioPlayer: makePlayer(),
        auth: auth,
        firestore: firestore,
      );
      await controller.initialize(configureAudioSession: false);
      await flushStreams();
      await controller.toggleFavorite(catalog.first);
      await auth.signInWithEmailAndPassword(
        email: 'alice@example.com',
        password: 'password',
      );
      await flushStreams();
      expect(controller.user?.uid, 'alice');
      expect(controller.favorites, isEmpty);
      await controller.toggleFavorite(catalog[1]);
      final playlist = (await controller.createPlaylist('Của Alice'))!;
      await controller.addToPlaylist(playlist, catalog[1]);
      await flushStreams();
      final saved = (await firestore.collection('users').doc('alice').get())
          .data()!;
      expect(saved['favorites'], ['sh2']);
      expect((saved['playlists'] as List).single['songIds'], ['sh2']);
      await controller.signOut();
      await flushStreams();
      expect(controller.user, isNull);
      expect(controller.favorites, {'sh1'});
      expect(controller.playlists, isEmpty);
      await auth.signInWithEmailAndPassword(
        email: 'alice@example.com',
        password: 'password',
      );
      await flushStreams();
      expect(controller.favorites, {'sh2'});
      expect(controller.playlists.single.name, 'Của Alice');
    },
  );

  test('authenticated user cannot access another users library', () async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'alice'));
    final firestore = FakeFirebaseFirestore(
      // This fake supports the owner predicate, but cannot parse the production
      // rules' request.resource schema validation or rules_version directive.
      securityRules: '''
      service cloud.firestore {
        match /databases/{database}/documents {
          match /users/{userId} {
            allow read, write: if request.auth != null && request.auth.uid == userId;
          }
        }
      }''',
      authObject: auth.authForFakeFirestore,
    );
    await auth.signInWithEmailAndPassword(
      email: 'alice@example.com',
      password: 'password',
    );
    await flushStreams();
    await firestore.collection('users').doc('alice').set({
      'favorites': ['sh1'],
      'playlists': [],
    });
    expect(
      (await firestore.collection('users').doc('alice').get()).exists,
      isTrue,
    );
    await expectLater(
      firestore.collection('users').doc('bob').get(),
      throwsException,
    );
    await expectLater(
      firestore.collection('users').doc('bob').set({
        'favorites': [],
        'playlists': [],
      }),
      throwsException,
    );
    await auth.signOut();
    await flushStreams();
    await expectLater(
      firestore.collection('users').doc('alice').get(),
      throwsException,
    );
  });
}
