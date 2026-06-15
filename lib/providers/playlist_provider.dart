import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/models/song.dart';
import '../data/models/playlist.dart';
import 'auth_provider.dart';
import '../data/local/download_db.dart';

class PlaylistState {
  final List<Playlist> playlists;
  final bool loading;

  const PlaylistState({
    this.playlists = const [],
    this.loading = true,
  });

  PlaylistState copyWith({
    List<Playlist>? playlists,
    bool? loading,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      loading: loading ?? this.loading,
    );
  }
}

const _maxSongsPerDoc = 3500;

class PlaylistNotifier extends Notifier<PlaylistState> {
  StreamSubscription? _firestoreSub;
  final _db = FirebaseFirestore.instance;
  Timer? _lastPlayedTimer;

  @override
  PlaylistState build() {
    final auth = ref.watch(authProvider);
    _subscribe(auth.user?.uid);
    ref.onDispose(() {
      _firestoreSub?.cancel();
      _lastPlayedTimer?.cancel();
    });
    return const PlaylistState(loading: true);
  }

  void _subscribe(String? userId) {
    _firestoreSub?.cancel();
    if (userId == null) {
      state = const PlaylistState(playlists: [], loading: false);
      return;
    }
    
    // Restore offline playlists from cloud on login
    restoreOfflinePlaylists();

    final query = _db.collection('playlists').where('members', arrayContains: userId);
    _firestoreSub = query.snapshots().listen((snapshot) {
      final playlists = snapshot.docs.map((doc) {
        final data = doc.data();
        return Playlist.fromJson({...data, 'id': doc.id});
      }).toList();

      playlists.sort((a, b) {
         final aDoc = snapshot.docs.firstWhere((d) => d.id == a.id).data();
         final bDoc = snapshot.docs.firstWhere((d) => d.id == b.id).data();
         int getMs(Map<String, dynamic> d, String f) => (d[f] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
         final tA = getMs(aDoc, 'lastPlayedAt') > 0 ? getMs(aDoc, 'lastPlayedAt') : getMs(aDoc, 'createdAt');
         final tB = getMs(bDoc, 'lastPlayedAt') > 0 ? getMs(bDoc, 'lastPlayedAt') : getMs(bDoc, 'createdAt');
         return tB.compareTo(tA);
      });
      state = PlaylistState(playlists: playlists, loading: false);
    }, onError: (e) {
      debugPrint('[Playlist] Sync error: $e');
      state = state.copyWith(loading: false);
    });
  }

  Future<String?> createPlaylist({String name = 'New Playlist', List<Song> initialSongs = const []}) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return null;
    try {
      final docRef = await _db.collection('playlists').add({
        'name': name,
        'createdBy': auth.user!.uid,
        'ownerName': auth.displayName ?? 'Megit User',
        'members': [auth.user!.uid],
        'songs': initialSongs.map((s) => s.toJson()).toList(),
        'visibility': 'Public',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;
    try {
      final ref2 = _db.collection('playlists').doc(playlistId);
      final snap = await ref2.get();
      final currentSongs = (snap.data()?['songs'] as List?) ?? [];
      if (currentSongs.length >= _maxSongsPerDoc) throw Exception('Playlist limit reached');
      ref2.update({
        'songs': FieldValue.arrayUnion([{...song.toJson(), 'addedByUid': auth.user!.uid}]),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) { rethrow; }
  }

  Future<void> removeSongFromPlaylist(String playlistId, int index) async {
    try {
      final playlist = state.playlists.firstWhere((p) => p.id == playlistId);
      final newSongs = List<Song>.from(playlist.songs)..removeAt(index);
      await updatePlaylist(playlistId, {
        'songs': newSongs.map((s) => s.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('[Playlist] Remove song error: $e');
    }
  }

  Future<void> updatePlaylist(String playlistId, Map<String, dynamic> updates) async {
    try {
      if (playlistId.startsWith('__pl__')) {
         // This is an offline playlist backup
         final auth = ref.read(authProvider);
         if (auth.user == null) return;
         await _db.collection('users').doc(auth.user!.uid).collection('offlinePlaylists').doc(playlistId).set({
           ...updates,
           'lastUpdated': FieldValue.serverTimestamp(),
         }, SetOptions(merge: true));
         return;
      }
      await _db.collection('playlists').doc(playlistId).update({
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) { debugPrint('[Playlist] Update error: $e'); }
  }

  Future<void> syncOfflinePlaylist(Playlist playlist) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;
    try {
      await _db.collection('users').doc(auth.user!.uid).collection('offlinePlaylists').doc(playlist.id).set({
        'name': playlist.name,
        'songs': playlist.songs.map((s) => s.toJson()).toList(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'type': 'OFFLINE_PLAYLIST',
      });
    } catch (e) {
      debugPrint('[Playlist] Sync offline error: $e');
    }
  }

  Future<void> restoreOfflinePlaylists() async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;
    try {
      final snap = await _db.collection('users').doc(auth.user!.uid).collection('offlinePlaylists').get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final playlist = Playlist.fromJson({...data, 'id': doc.id});
        await DownloadDb.instance.restorePlaylist(playlist);
      }
    } catch (e) {
      debugPrint('[Playlist] Restore offline error: $e');
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    try {
      if (playlistId.startsWith('__pl__')) {
        final auth = ref.read(authProvider);
        if (auth.user != null) {
          await _db.collection('users').doc(auth.user!.uid).collection('offlinePlaylists').doc(playlistId).delete();
        }
      }
      await DownloadDb.instance.deleteOfflinePlaylist(playlistId);
      if (!playlistId.startsWith('__pl__')) {
        _db.collection('playlists').doc(playlistId).delete();
      }
    } catch (e) { debugPrint('[Playlist] Delete error: $e'); }
  }

  void updateLastPlayed(String playlistId) {
    _lastPlayedTimer?.cancel();
    _lastPlayedTimer = Timer(const Duration(seconds: 10), () async {
      try { await _db.collection('playlists').doc(playlistId).update({'lastPlayedAt': FieldValue.serverTimestamp()}); } catch (_) {}
    });
  }

  bool isLiked(String? songId) {
    if (songId == null) return false;
    final liked = state.playlists.where((p) => p.name == 'Liked Songs').firstOrNull;
    if (liked == null) return false;
    return liked.songs.any((s) => s.videoId == songId);
  }

  Future<void> toggleLike(Song song) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return;
    var liked = state.playlists.where((p) => p.name == 'Liked Songs').firstOrNull;
    if (liked == null) {
      final id = await createPlaylist(name: 'Liked Songs');
      if (id != null) await addSongToPlaylist(id, song);
      return;
    }
    final index = liked.songs.indexWhere((s) => s.videoId == song.videoId);
    if (index >= 0) {
      final newSongs = List<Song>.from(liked.songs)..removeAt(index);
      await updatePlaylist(liked.id, {'songs': newSongs.map((s) => s.toJson()).toList()});
    } else {
      await addSongToPlaylist(liked.id, song);
    }
  }

  Future<String?> importMegitPlaylist(String megitId) async {
    final auth = ref.read(authProvider);
    if (auth.user == null) return null;
    try {
      final snap = await _db.collection('playlists').doc(megitId).get();
      if (!snap.exists) return null;
      final data = snap.data()!;
      final docRef = await _db.collection('playlists').add({
        ...data,
        'createdBy': auth.user!.uid,
        'ownerName': auth.displayName ?? 'Megit User',
        'members': [auth.user!.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (_) { return null; }
  }
}

final playlistProvider = NotifierProvider<PlaylistNotifier, PlaylistState>(PlaylistNotifier.new);
