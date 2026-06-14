import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Custom [BaseAudioHandler] for Megit — bridges `just_audio` with `audio_service`
/// to provide background playback and lock screen / notification controls.
class MegitAudioHandler extends BaseAudioHandler with SeekHandler {
  AudioPlayer _activePlayer;
  AudioPlayer? _crossfadePlayer;

  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<PlayerState>? _stateSub;

  void Function()? onTrackEnded;
  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;
  void Function()? onLikePressed;

  bool _isLiked = false;

  void updateLikedState(bool liked) {
    _isLiked = liked;
    _broadcastState(_activePlayer.playerState);
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'like') onLikePressed?.call();
    await super.customAction(name, extras);
  }

  MegitAudioHandler(this._activePlayer) {
    _initListeners();
  }

  void _initListeners() {
    _stateSub?.cancel();
    _eventSub?.cancel();

    _stateSub = _activePlayer.playerStateStream.listen((playerState) {
      _broadcastState(playerState);
    });

    _eventSub = _activePlayer.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.completed) {
        onTrackEnded?.call();
      }
    });
  }

  @override
  Future<void> updateMediaItem(MediaItem item) async {
    mediaItem.add(item);
  }

  Future<void> playUrl(String url, {Map<String, String>? headers}) async {
    await _activePlayer.setUrl(url, headers: headers);
    await _activePlayer.play();
  }

  Future<void> playFile(String path) async {
    await _activePlayer.setFilePath(path);
    await _activePlayer.play();
  }

  Future<void> stopCurrent() async {
    await _activePlayer.stop();
  }

  void setBufferingState() {
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.buffering,
    ));
  }

  @override
  Future<void> play() async => await _activePlayer.play();
  @override
  Future<void> pause() async => await _activePlayer.pause();
  @override
  Future<void> stop() async {
    await _activePlayer.stop();
    await super.stop();
  }
  @override
  Future<void> seek(Duration position) async => await _activePlayer.seek(position);
  @override
  Future<void> skipToNext() async => onSkipToNext?.call();
  @override
  Future<void> skipToPrevious() async => onSkipToPrevious?.call();

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await Future.delayed(const Duration(milliseconds: 200));
    exit(0);
  }

  AudioPlayer get primaryPlayer => _activePlayer;
  AudioPlayer get crossfadePlayer {
    _crossfadePlayer ??= AudioPlayer();
    return _crossfadePlayer!;
  }

  void setPrimaryPlayer(AudioPlayer newPrimary) {
    _activePlayer = newPrimary;
    _initListeners();
    _broadcastState(_activePlayer.playerState);
  }

  void _broadcastState(PlayerState playerState) {
    final playing = playerState.playing;
    final processingState = _mapProcessingState(playerState.processingState);
    final likeIcon = _isLiked ? 'drawable/ic_favorite' : 'drawable/ic_favorite_outline';

    playbackState.add(PlaybackState(
      controls: [
        const MediaControl(androidIcon: 'drawable/ic_skip_previous', label: 'Previous', action: MediaAction.skipToPrevious),
        if (playing)
          const MediaControl(androidIcon: 'drawable/ic_pause_circle_fill', label: 'Pause', action: MediaAction.pause)
        else
          const MediaControl(androidIcon: 'drawable/ic_play_circle_fill', label: 'Play', action: MediaAction.play),
        const MediaControl(androidIcon: 'drawable/ic_skip_next', label: 'Next', action: MediaAction.skipToNext),
        MediaControl.custom(androidIcon: likeIcon, label: _isLiked ? 'Unlike' : 'Like', name: 'like'),
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: processingState,
      playing: playing,
      updatePosition: _activePlayer.position,
      bufferedPosition: _activePlayer.bufferedPosition,
      speed: _activePlayer.speed,
    ));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _stateSub?.cancel();
    await _activePlayer.dispose();
    await _crossfadePlayer?.dispose();
  }
}

Future<MegitAudioHandler> initAudioService() async {
  final player = AudioPlayer();
  return await AudioService.init(
    builder: () => MegitAudioHandler(player),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.megit.music.channel',
      androidNotificationChannelName: 'Megit Music',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'drawable/ic_logo',
    ),
  );
}
