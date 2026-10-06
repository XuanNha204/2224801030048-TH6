import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonic_music/controllers/music_controller.dart';
import 'package:sonic_music/data/catalog.dart';
import 'package:sonic_music/main.dart';
import 'package:sonic_music/ui/player_screen.dart';
import 'package:sonic_music/ui/theme.dart';
import 'helpers.dart';

void main() {
  Future<MusicController> makeController() async {
    SharedPreferences.setMockInitialValues({});
    final controller = MusicController(
      preferences: await SharedPreferences.getInstance(),
      audioPlayer: makePlayer(),
    );
    await controller.initialize(configureAudioSession: false);
    return controller;
  }

  testWidgets('mobile search filters songs and displays an empty result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(SonicApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Song 3');
    await tester.pumpAndSettle();
    expect(find.text('SoundHelix Song 3'), findsOneWidget);
    expect(find.text('SoundHelix Song 1'), findsNothing);
    await tester.enterText(find.byType(TextField), 'not-a-song');
    await tester.pumpAndSettle();
    expect(find.text('Chưa tìm thấy bài hát'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest creates playlist and navigates to its empty detail', (
    tester,
  ) async {
    final controller = await makeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(SonicApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playlist').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo playlist').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Nhạc của tôi');
    await tester.tap(find.text('Tạo playlist').last);
    await tester.pumpAndSettle();
    expect(find.text('Nhạc của tôi'), findsOneWidget);
    expect(find.text('Playlist đang chờ giai điệu'), findsOneWidget);
    expect(controller.playlists.single.name, 'Nhạc của tôi');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('home and player fit viewport width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await makeController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(SonicApp(controller: controller));
      await tester.pumpAndSettle();
      controller.queue = catalog.toList();
      await tester.pumpWidget(
        MaterialApp(
          theme: sonicTheme,
          home: PlayerScreen(controller: controller, onAdd: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Phát nhạc'), findsOneWidget);
      expect(find.byTooltip('Bài trước'), findsOneWidget);
      expect(find.byTooltip('Bài tiếp theo'), findsOneWidget);
    });
  }
}
