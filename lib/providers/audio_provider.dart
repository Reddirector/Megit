import 'dart:async';
import 'package:flutter/material.dart' show SnackBar, Text;
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/api/music_api.dart';
import '../data/models/song.dart';
import '../core/utils/thumbnail_utils.dart';
import '../services/audio_handler.dart';
import '../services/crossfade_engine.dart';
import '../services/stream_extractor.dart';
import '../main.dart' show scaffoldMessengerKey;
import 'auth_provider.dart';
import 'download_provider.dart';
import 'settings_provider.dart';
import 'playlist_provider.dart';

enum RepeatMode { off, all, one }

class AudioState {
  final Song? currentSong;
  final String? contextPlaylistId;
  final bool isPlaying;
  final bool isLoading;
  final Duration progress;
  final Duration bufferedProgress;
  final Duration duration;
  final List<Song> queue;
  final List<Song> baseQueue;
  final List<Song> history;
  final bool isShuffled;
  final RepeatMode repeatMode;

  const AudioState({
    this.currentSong,
    this.contextPlaylistId,
    this.isPlaying = false,
    this.isLoading = false,
    this.progress = Duration.zero,
    this.bufferedProgress = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.baseQueue = const [],
    this.history = const [],
    this.isShuffled = false,
    this.repeatMode = RepeatMode.off,
  });

  AudioState copyWith({
    Song? currentSong,
    String? contextPlaylistId,
    bool clearContextPlaylistId = false,
    bool? isPlaying,
    bool? isLoading,
    Duration? progress,
    Duration? bufferedProgress,
    Duration? duration,
    List<Song>? queue,
    List<Song>? baseQueue,
    List<Song>? history,
    bool? isShuffled,
    RepeatMode? repeatMode,
  }) {
    return AudioState(
      currentSong: currentSong ?? this.currentSong,
      contextPlaylistId: clearContextPlaylistId ? null : (contextPlaylistId ?? this.contextPlaylistId),
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      bufferedProgress: bufferedProgress ?? this.bufferedProgress,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      baseQueue: baseQueue ?? this.baseQueue,
      history: history ?? this.history,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

class AudioNotifier extends Notifier<AudioState> {
  late MegitAudioHandler _handler;
  late CrossfadeEngine _crossfadeEngine;
  final _musicApi = MusicApi();

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _bufferedSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  int _loadGeneration = 0;
  bool _statsThresholdReached = false;
  String? _preloadedNextSongId;
  bool _isPreloadingNext = false;
  int _consecutiveFailures = 0;
  bool _isInitialized = false;

  @override
  AudioState build() {
    ref.onDispose(_dispose);
    ref.listen(playlistProvider, (_, __) {
      if (!_isInitialized) return;
      if (state.currentSong != null) {
        _handler.updateLikedState(ref.read(playlistProvider.notifier).isLiked(state.currentSong!.videoId));
      }
    });
    ref.listen(authProvider, (previous, next) {
      if (previous?.user != null && next.user == null) {
        stop();
      }
    });
    return const AudioState();
  }

  void initialize(MegitAudioHandler handler) {
    _handler = handler;
    _isInitialized = true;
    _crossfadeEngine = CrossfadeEngine(primaryPlayer: _handler.primaryPlayer, crossfadePlayer: _handler.crossfadePlayer);
    _handler.onTrackEnded = _onTrackEnded;
    _handler.onSkipToNext = playNext;
    _handler.onSkipToPrevious = playPrev;
    _handler.onForward10 = seekForward;
    _handler.onBackward10 = seekBackward;
    _handler.onLikePressed = () {
      final s = state.currentSong;
      if (s != null) {
        ref.read(playlistProvider.notifier).toggleLike(s);
        _handler.updateLikedState(ref.read(playlistProvider.notifier).isLiked(s.videoId));
      }
    };
    _crossfadeEngine.onSwapComplete = _onCrossfadeSwapComplete;
    _attachPlayerListeners(_handler.primaryPlayer);
  }

  DateTime _lastPositionBroadcast = DateTime.fromMillisecondsSinceEpoch(0);

  // True for the brief window between calling player.stop() to clear the old
  // track and successfully starting the new one. just_audio emits a real
  // "idle/paused" state the instant stop() runs — without this guard, that
  // transient state flows straight into the UI (looks like the new song
  // loaded paused, with the old song's last-known position still showing)
  // even though we're already committed to playing the new track.
  bool _isTransitioning = false;

  void _attachPlayerListeners(AudioPlayer player) {
    _positionSub?.cancel();
    _bufferedSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();

    _positionSub = player.positionStream.listen((pos) {
      if (_isTransitioning) return; // ignore stale position from the track we're switching away from
      _runSideEffects(pos, player);
      final now = DateTime.now();
      // Throttle progress updates to 500ms to reduce UI rebuilds/lag
      if (now.difference(_lastPositionBroadcast).inMilliseconds >= 500) {
        _lastPositionBroadcast = now;
        state = state.copyWith(progress: pos);
      }
    });

    _bufferedSub = player.bufferedPositionStream.listen((buffered) {
      if (_isTransitioning) return;
      state = state.copyWith(bufferedProgress: buffered);
    });

    _durationSub = player.durationStream.listen((dur) {
      if (_isTransitioning) return;
      if (dur != null) {
        state = state.copyWith(duration: dur);
        _updateMediaItemDuration(dur);
      }
    });

    _playerStateSub = player.playerStateStream.listen((ps) {
      if (_isTransitioning) return; // our own stop() call mid-switch isn't a real pause
      
      // Fix: Don't let buffering state hide the play/pause button if we're actually playing.
      // We only show the full-screen/major loader if it's the initial 'loading' phase
      // or if playback is stalled (buffering while NOT playing).
      final isLoading = ps.processingState == ProcessingState.loading || 
                        (ps.processingState == ProcessingState.buffering && !ps.playing);
      
      state = state.copyWith(isPlaying: ps.playing, isLoading: isLoading);
      if (ps.playing) WakelockPlus.enable(); else WakelockPlus.disable();
    });
  }

  void _runSideEffects(Duration position, AudioPlayer player) {
    final settings = ref.read(settingsProvider);
    final fadeSecs = settings.crossfadeDuration;
    final dur = player.duration;

    if (fadeSecs > 0 && dur != null && dur.inSeconds > 0 && state.repeatMode != RepeatMode.one) {
      final timeLeft = (dur.inMilliseconds - position.inMilliseconds) / 1000.0;
      if (timeLeft <= (fadeSecs + 20) && timeLeft > fadeSecs) _preloadNextSong();
      if (!_crossfadeEngine.isCrossfading && !_isCrossfadePending && timeLeft <= fadeSecs && timeLeft > 0) _triggerCrossfade(fadeSecs);
    } else if (dur != null && dur.inSeconds > 0) {
      final timeLeft = (dur.inMilliseconds - position.inMilliseconds) / 1000.0;
      if (timeLeft <= 40 && timeLeft > 0) _preloadNextSong();
    }

    if (!_statsThresholdReached && dur != null && dur.inSeconds > 0) {
      if (position.inSeconds > 30 || position.inSeconds > dur.inSeconds / 2) {
        _reportStats();
        _statsThresholdReached = true;
      }
    }
  }

  void _onTrackEnded() {
    if (_crossfadeEngine.isCrossfading || _isCrossfadePending) return;
    if (state.repeatMode == RepeatMode.one) {
      _crossfadeEngine.primaryPlayer.seek(Duration.zero);
      _crossfadeEngine.primaryPlayer.play();
    } else playNext();
  }

  Future<void> playSong(Song song, {String? offlineFilePath, bool clearQueue = false, String? contextPlaylistId}) async {
    final normalized = song.copyWith(id: song.videoId.isNotEmpty ? song.videoId : song.id, videoId: song.videoId.isNotEmpty ? song.videoId : song.id);
    if (normalized.videoId.isEmpty || (normalized.videoId.length != 11 && offlineFilePath == null)) return;

    if (state.currentSong?.videoId == normalized.videoId && offlineFilePath == null) {
      if (contextPlaylistId != null) state = state.copyWith(contextPlaylistId: contextPlaylistId);
      togglePlay();
      return;
    }

    // --- STEP 1: IMMEDIATE FEEDBACK ---
    final myGen = ++_loadGeneration;
    _crossfadeEngine.cancelCrossfade();
    _statsThresholdReached = false;
    
    state = state.copyWith(
      isLoading: true, 
      currentSong: normalized, 
      isPlaying: true, 
      progress: Duration.zero, 
      bufferedProgress: Duration.zero,
      // Fix: Use song's metadata duration as a fallback if the player hasn't resolved it yet.
      // This prevents the "0:00" duration issue.
      duration: normalized.duration > 0 ? Duration(seconds: normalized.duration) : Duration.zero,
      queue: clearQueue ? [] : state.queue,
      baseQueue: clearQueue ? [] : state.baseQueue,
      contextPlaylistId: contextPlaylistId,
      clearContextPlaylistId: normalized.playlistId == '__suggested__' || (clearQueue && contextPlaylistId == null),
    );

    // --- STEP 2: IMMEDIATE PLAYBACK START ---
    _startPlayback(normalized, offlineFilePath, myGen);

    // --- STEP 3: DEFER HEAVY SIDE EFFECTS ---
    Future.microtask(() async {
      if (_loadGeneration != myGen) return;
      
      _updateMediaItem(normalized);
      _handler.updateLikedState(ref.read(playlistProvider.notifier).isLiked(normalized.videoId));

      if (state.queue.length <= 10) {
        final seedId = state.queue.isEmpty ? normalized.videoId : state.queue.last.videoId;
        _fetchWatchNext(seedId);
      }
      
      if (state.currentSong != null && state.currentSong!.videoId != normalized.videoId) {
        final hist = [state.currentSong!, ...state.history];
        state = state.copyWith(history: hist.length > 50 ? hist.sublist(0, 50) : hist);
      }
    });
  }

  Future<void> _startPlayback(Song normalized, String? offlineFilePath, int myGen) async {
    _isTransitioning = true;
    try {
      final player = _crossfadeEngine.primaryPlayer;
      await player.stop();
      // Once stop() is done, we're no longer transitioning from an OLD track's state.
      // Resetting this flag now allows the loading/buffering states of the NEW track
      // to be reflected in the UI immediately.
      _isTransitioning = false;
      
      player.setVolume(1.0);

      if (offlineFilePath != null) {
        await player.setFilePath(offlineFilePath);
        if (_loadGeneration == myGen) await player.play();
        return;
      }

      final downloads = ref.read(downloadProvider.notifier);
      if (normalized.videoId.length == 11 && await downloads.isDownloaded(normalized.videoId)) {
        final path = await downloads.getFilePath(normalized.videoId);
        if (path != null) {
          await player.setFilePath(path);
          if (_loadGeneration == myGen) await player.play();
          return;
        }
      }

      // Robust extraction
      final streamUrl = await StreamExtractor.getAudioStreamUrl(normalized.videoId, 
        quality: ref.read(settingsProvider).streamingQuality
      ).timeout(const Duration(seconds: 20));
      
      if (_loadGeneration != myGen) return;
      
      await player.setUrl(streamUrl);
      if (_loadGeneration == myGen) {
        await player.play();
        _consecutiveFailures = 0; // Success: reset circuit breaker
      }
    } catch (e) {
      if (_loadGeneration == myGen) {
        debugPrint('[Audio] Playback error: $e');

        // Force-silence the player no matter what failed above (extraction,
        // setUrl, play() — even the initial stop() itself can occasionally
        // throw on ExoPlayer). Without this, a failed attempt could leave
        // whatever was previously loaded still audible while the UI has
        // already moved on to showing the new track.
        try {
          await _crossfadeEngine.primaryPlayer.stop();
        } catch (_) {}

        state = state.copyWith(isLoading: false);
        
        // Circuit breaker: stop loop after 3 consecutive song failures
        _consecutiveFailures++;
        _isTransitioning = false;
        if (_consecutiveFailures >= 3) {
          state = state.copyWith(isPlaying: false);
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text("Couldn't load this track right now. Streaming may be temporarily unavailable — try again shortly."))
          );
        } else {
          // Move to next track automatically on failure (single attempt per song)
          playNext();
        }
      }
    } finally {
      // Safety check to ensure flag is cleared.
      if (_loadGeneration == myGen) _isTransitioning = false;
    }
  }

  void playNext() {
    _statsThresholdReached = false;
    if (state.queue.isNotEmpty) {
      final next = state.queue.first;
      state = state.copyWith(queue: state.queue.sublist(1));
      playSong(next);
    } else if (state.repeatMode == RepeatMode.all && state.baseQueue.isNotEmpty) {
      final rebuilt = state.isShuffled ? ([...state.baseQueue]..shuffle()) : [...state.baseQueue];
      state = state.copyWith(queue: rebuilt.sublist(1));
      playSong(rebuilt.first);
    } else if (state.currentSong != null) {
      // Transition to loading state so notification stays active while fetching next batch
      state = state.copyWith(isLoading: true);
      _fetchWatchNextAndPlayFirst(state.currentSong!.videoId);
    } else {
      state = state.copyWith(isPlaying: false, progress: Duration.zero);
      _crossfadeEngine.primaryPlayer.stop();
    }
  }

  void playPrev() {
    if (state.progress.inSeconds > 3) {
      _crossfadeEngine.primaryPlayer.seek(Duration.zero);
      state = state.copyWith(progress: Duration.zero);
    } else if (state.history.isNotEmpty) {
      final prev = state.history.first;
      state = state.copyWith(queue: state.currentSong != null ? [state.currentSong!, ...state.queue] : state.queue, history: state.history.sublist(1));
      playSong(prev);
    } else {
      _crossfadeEngine.primaryPlayer.seek(Duration.zero);
      state = state.copyWith(progress: Duration.zero);
    }
  }

  void addToQueue(Song s) {
    final n = s.copyWith(id: s.videoId.isNotEmpty ? s.videoId : s.id, videoId: s.videoId.isNotEmpty ? s.videoId : s.id);
    state = state.copyWith(queue: [n, ...state.queue], baseQueue: [n, ...state.baseQueue]);
  }

  void playFromQueue(int i) {
    if (i < 0 || i >= state.queue.length) return;
    final s = state.queue[i];
    final before = state.queue.sublist(0, i);
    state = state.copyWith(queue: state.queue.sublist(i + 1), history: [...before.reversed, ...state.history].length > 50 ? [...before.reversed, ...state.history].sublist(0, 50) : [...before.reversed, ...state.history]);
    playSong(s);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final list = List<Song>.from(state.queue);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = state.copyWith(queue: list);
  }

  void removeFromQueue(int i) {
    final list = List<Song>.from(state.queue);
    list.removeAt(i);
    state = state.copyWith(queue: list);
  }

  Future<void> startRadio(Song seed) async {
    await playSong(seed, clearQueue: true);
  }

  void replaceQueue(List<Song> q) {
    state = state.copyWith(baseQueue: q, queue: state.isShuffled ? ([...q]..shuffle()) : q);
  }

  void toggleShuffle() {
    final s = !state.isShuffled;
    state = state.copyWith(isShuffled: s, queue: s ? ([...state.queue]..shuffle()) : state.baseQueue.where((x) => state.queue.any((y) => y.videoId == x.videoId)).toList());
  }

  void toggleRepeat() {
    final next = switch (state.repeatMode) { RepeatMode.off => RepeatMode.all, RepeatMode.all => RepeatMode.one, RepeatMode.one => RepeatMode.off };
    state = state.copyWith(repeatMode: next);
    _crossfadeEngine.primaryPlayer.setLoopMode(next == RepeatMode.one ? LoopMode.one : LoopMode.off);
  }

  void togglePlay() {
    if (state.currentSong == null) return;
    if (_crossfadeEngine.primaryPlayer.playing) _crossfadeEngine.primaryPlayer.pause(); else _crossfadeEngine.primaryPlayer.play();
  }

  void seekForward() {
    final current = _crossfadeEngine.primaryPlayer.position;
    final duration = _crossfadeEngine.primaryPlayer.duration ?? Duration.zero;
    final next = current + const Duration(seconds: 10);
    seek(next > duration ? duration : next);
  }

  void seekBackward() {
    final current = _crossfadeEngine.primaryPlayer.position;
    final next = current - const Duration(seconds: 10);
    seek(next < Duration.zero ? Duration.zero : next);
  }

  void seek(Duration p) {
    _crossfadeEngine.primaryPlayer.seek(p);
    state = state.copyWith(progress: p);
  }

  void stop() {
    _loadGeneration++;
    if (_isInitialized) {
      try {
        _crossfadeEngine.cancelCrossfade();
        _crossfadeEngine.primaryPlayer.stop();
        _crossfadeEngine.crossfadePlayer.stop();
      } catch (e) {
        debugPrint('[Audio] Stop error: $e');
      }
    }
    state = const AudioState();
  }

  Future<void> _preloadNextSong() async {
    if (_isPreloadingNext) return;
    Song? next;
    if (state.queue.isNotEmpty) next = state.queue.first;
    else if (state.repeatMode == RepeatMode.all && state.baseQueue.isNotEmpty) next = (state.isShuffled ? ([...state.baseQueue]..shuffle()) : state.baseQueue).first;
    if (next == null || next.videoId.isEmpty || _preloadedNextSongId == next.videoId) return;

    _isPreloadingNext = true;
    try {
      final dls = ref.read(downloadProvider.notifier);
      String? path; String? url;
      if (await dls.isDownloaded(next.videoId)) path = await dls.getFilePath(next.videoId);
      else url = await StreamExtractor.getAudioStreamUrl(next.videoId, quality: ref.read(settingsProvider).streamingQuality).timeout(const Duration(seconds: 15));
      if (await _crossfadeEngine.prepareCrossfade(nextUrl: url, localFilePath: path)) _preloadedNextSongId = next.videoId;
    } catch (_) {} finally { _isPreloadingNext = false; }
  }

  bool _isCrossfadePending = false;
  Future<void> _triggerCrossfade(int fade) async {
    final gen = _loadGeneration;
    Song? next; List<Song> rem = state.queue;
    if (state.queue.isNotEmpty) { next = state.queue.first; rem = state.queue.sublist(1); }
    else if (state.repeatMode == RepeatMode.all && state.baseQueue.isNotEmpty) {
       final r = state.isShuffled ? ([...state.baseQueue]..shuffle()) : state.baseQueue;
       next = r.first; rem = r.sublist(1);
    }
    if (next == null || next.videoId.isEmpty) return;
    _isCrossfadePending = true;
    String? path; String? url;
    if (_preloadedNextSongId != next.videoId) {
      try {
        final dls = ref.read(downloadProvider.notifier);
        if (await dls.isDownloaded(next.videoId)) path = await dls.getFilePath(next.videoId);
        else url = await StreamExtractor.getAudioStreamUrl(next.videoId, quality: ref.read(settingsProvider).streamingQuality).timeout(const Duration(seconds: 15));
      } catch (_) { if (_loadGeneration == gen) { _isCrossfadePending = false; playNext(); } return; }
    }
    _preloadedNextSongId = null;
    if (_loadGeneration != gen) { _isCrossfadePending = false; return; }
    try {
      final ok = await _crossfadeEngine.startCrossfade(fadeDuration: fade, nextUrl: url, localFilePath: path);
      if (_loadGeneration == gen) { if (ok) { _pendingSong = next; _pendingQueue = rem; } else playNext(); }
    } catch (_) { if (_loadGeneration == gen) playNext(); } finally { if (_loadGeneration == gen) _isCrossfadePending = false; }
  }

  Song? _pendingSong; List<Song>? _pendingQueue;
  void _onCrossfadeSwapComplete(AudioPlayer p) {
    _attachPlayerListeners(p); _handler.setPrimaryPlayer(p);
    if (_pendingSong != null) {
      _statsThresholdReached = false;
      state = state.copyWith(currentSong: _pendingSong, isPlaying: true, duration: p.duration ?? Duration.zero, progress: p.position, queue: _pendingQueue ?? state.queue);
      _updateMediaItem(_pendingSong!);
    }
    _pendingSong = null; _pendingQueue = null;
  }

  Future<void> _fetchWatchNext(String vid) async {
    try {
      final ts = await _musicApi.getWatchNext(vid);
      if (ts.isNotEmpty) {
        final curIds = state.queue.map((s) => s.videoId).toSet();
        final news = ts.where((t) => t.videoId != state.currentSong?.videoId && !curIds.contains(t.videoId)).map((t) => t.copyWith(playlistId: '__suggested__')).toList();
        if (news.isNotEmpty) state = state.copyWith(queue: [...state.queue, ...news], baseQueue: [...state.baseQueue, ...news]);
      }
    } catch (_) {}
  }

  Future<void> _fetchWatchNextAndPlayFirst(String vid) async {
    try {
      final ts = await _musicApi.getWatchNext(vid);
      if (ts.isNotEmpty) {
        final news = ts.map((t) => t.copyWith(playlistId: '__suggested__')).toList();
        state = state.copyWith(queue: news.sublist(1)); playSong(news.first);
      } else { state = state.copyWith(isPlaying: false); _crossfadeEngine.primaryPlayer.stop(); }
    } catch (_) { state = state.copyWith(isPlaying: false); _crossfadeEngine.primaryPlayer.stop(); }
  }

  void _updateMediaItem(Song s) {
    final art = s.thumbnail.isNotEmpty ? ThumbnailUtils.getHighRes(s.thumbnail, size: 800) : '';
    _handler.updateMediaItem(MediaItem(id: s.videoId, title: s.title, artist: s.artist, album: s.album, duration: s.duration > 0 ? Duration(seconds: s.duration) : null, artUri: art.isNotEmpty ? Uri.parse(art) : null));
  }

  void _updateMediaItemDuration(Duration d) {
    final c = state.currentSong; if (c == null) return;
    final art = c.thumbnail.isNotEmpty ? ThumbnailUtils.getHighRes(c.thumbnail, size: 800) : '';
    _handler.updateMediaItem(MediaItem(id: c.videoId, title: c.title, artist: c.artist, album: c.album, duration: d, artUri: art.isNotEmpty ? Uri.parse(art) : null));
  }

  void _reportStats() {
    final s = state.currentSong; if (s == null) return;
    ref.read(authProvider.notifier).updatePlaybackStats(videoId: s.videoId, secondsListened: state.progress.inSeconds, title: s.title, artist: s.artist, cover: s.thumbnail);
  }

  void _dispose() {
    _positionSub?.cancel(); _bufferedSub?.cancel(); _durationSub?.cancel(); _playerStateSub?.cancel();
    _crossfadeEngine.dispose(); _handler.dispose(); WakelockPlus.disable();
  }
}

final audioProvider = NotifierProvider<AudioNotifier, AudioState>(AudioNotifier.new);
final audioHandlerProvider = Provider<MegitAudioHandler>((ref) => throw UnimplementedError());
