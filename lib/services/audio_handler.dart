import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
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
    if (name == 'forward10') onForward10?.call();
    if (name == 'rewind10') onBackward10?.call();
    await super.customAction(name, extras);
  }

  MegitAudioHandler(this._activePlayer) {
    _initListeners();
  }

  void Function()? onForward10;
  void Function()? onBackward10;

  void _initListeners() {
    _stateSub?.cancel();
    _eventSub?.cancel();

    _stateSub = _activePlayer.playerStateStream.listen(
      (playerState) {
        _broadcastState(playerState);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[AudioHandler] playerStateStream error: $e');
      },
    );

    _eventSub = _activePlayer.playbackEventStream.listen(
      (event) {
        if (event.processingState == ProcessingState.completed) {
          onTrackEnded?.call();
        }
      },
      onError: (Object e, StackTrace st) {
        debugPrint('[AudioHandler] playbackEventStream error: $e');
      },
    );
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
  Future<void> fastForward() async => onForward10?.call();
  @override
  Future<void> rewind() async => onBackward10?.call();

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
        MediaControl.skipToPrevious,
        const MediaControl(androidIcon: 'drawable/ic_replay_10', label: 'Rewind 10s', action: MediaAction.rewind),
        if (playing) MediaControl.pause else MediaControl.play,
        const MediaControl(androidIcon: 'drawable/ic_forward_10', label: 'Forward 10s', action: MediaAction.fastForward),
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.fastForward,
        MediaAction.rewind,
      },
      androidCompactActionIndices: const [0, 2, 4],
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
  // Use a standard mobile User-Agent to reduce YouTube throttling
  final player = AudioPlayer(
    userAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Mobile Safari/537.36',
    // Audio is low-bitrate (a few KB/s) — there's no need for video-sized buffer
    // targets here. The previous config forced a flat 5s wait before ANY sound
    // played, and a 10s wait to resume after any mid-song stutter, on every
    // single song. These values match what keeps Spotify/YouTube Music feeling
    // instant while still holding enough buffer to avoid frequent rebuffering.
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        // Aggressively lowered buffer targets to satisfy the "small chunks" requirement.
        // This makes the player start almost instantly and only hold a small amount
        // of data in memory at any time.
        minBufferDuration: Duration(seconds: 5),
        maxBufferDuration: Duration(seconds: 20),
        bufferForPlaybackDuration: Duration(milliseconds: 500),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 1),
      ),
    ),
  );
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
