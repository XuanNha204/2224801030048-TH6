import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}

MockAudioPlayer makePlayer() {
  registerFallbackValue(<AudioSource>[]);
  registerFallbackValue(Duration.zero);
  registerFallbackValue(LoopMode.off);
  final player = MockAudioPlayer();
  when(() => player.playerStateStream).thenAnswer((_) => const Stream.empty());
  when(() => player.currentIndexStream).thenAnswer((_) => const Stream.empty());
  when(() => player.errorStream).thenAnswer((_) => const Stream.empty());
  when(
    () => player.durationStream,
  ).thenAnswer((_) => Stream.value(const Duration(minutes: 4)));
  when(
    () => player.positionStream,
  ).thenAnswer((_) => Stream.value(Duration.zero));
  when(
    () => player.bufferedPositionStream,
  ).thenAnswer((_) => Stream.value(const Duration(minutes: 1)));
  when(() => player.duration).thenReturn(const Duration(minutes: 4));
  when(() => player.position).thenReturn(Duration.zero);
  when(() => player.bufferedPosition).thenReturn(const Duration(minutes: 1));
  when(() => player.currentIndex).thenReturn(0);
  when(() => player.playing).thenReturn(false);
  when(() => player.processingState).thenReturn(ProcessingState.ready);
  when(() => player.hasNext).thenReturn(true);
  when(() => player.hasPrevious).thenReturn(false);
  when(() => player.shuffleModeEnabled).thenReturn(false);
  when(() => player.loopMode).thenReturn(LoopMode.off);
  when(
    () => player.setAudioSources(
      any(),
      initialIndex: any(named: 'initialIndex'),
      initialPosition: any(named: 'initialPosition'),
    ),
  ).thenAnswer((_) async => const Duration(minutes: 4));
  when(() => player.play()).thenAnswer((_) async {});
  when(() => player.pause()).thenAnswer((_) async {});
  when(
    () => player.seek(any(), index: any(named: 'index')),
  ).thenAnswer((_) async {});
  when(() => player.seekToNext()).thenAnswer((_) async {});
  when(() => player.seekToPrevious()).thenAnswer((_) async {});
  when(() => player.setShuffleModeEnabled(any())).thenAnswer((_) async {});
  when(() => player.setLoopMode(any())).thenAnswer((_) async {});
  when(() => player.dispose()).thenAnswer((_) async {});
  return player;
}
