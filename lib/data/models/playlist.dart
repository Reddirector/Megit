import 'song.dart';

/// Playlist model for both Firestore playlists and YT Music playlists.
class Playlist {
  final String id;
  final String name;
  final String? description;
  final String? thumbnail; // Original YTM or fallback
  final String? customThumbnail; // Base64 for custom image
  final String? customColor; // Hex for solid color fallback
  final String? customText; // Text for solid color fallback
  final String createdBy;
  final String ownerName;
  final List<String> members;
  final List<Song> songs;
  final String visibility;
  final String type; // 'MEGIT', 'YTM_PLAYLIST', 'YTM_ALBUM'
  final int? totalTracks; // Header-reported total (may exceed songs.length)
  final DateTime? createdAt;
  final DateTime? lastPlayedAt;

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.thumbnail,
    this.customThumbnail,
    this.customColor,
    this.customText,
    this.createdBy = '',
    this.ownerName = '',
    this.members = const [],
    this.songs = const [],
    this.visibility = 'Public',
    this.type = 'MEGIT',
    this.totalTracks,
    this.createdAt,
    this.lastPlayedAt,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Playlist',
      description: json['description']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      customThumbnail: json['customThumbnail']?.toString(),
      customColor: json['customColor']?.toString(),
      customText: json['customText']?.toString(),
      createdBy: json['createdBy']?.toString() ?? '',
      ownerName: json['ownerName']?.toString() ?? '',
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      songs: (json['songs'] as List<dynamic>?)
              ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList() ??
          (json['tracks'] as List<dynamic>?)
                  ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              [],
      visibility: json['visibility']?.toString() ?? 'Public',
      type: json['type']?.toString() ?? 'MEGIT',
      totalTracks: json['totalTracks'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'thumbnail': thumbnail,
      'customThumbnail': customThumbnail,
      'customColor': customColor,
      'customText': customText,
      'createdBy': createdBy,
      'ownerName': ownerName,
      'members': members,
      'songs': songs.map((s) => s.toJson()).toList(),
      'visibility': visibility,
      'type': type,
      'totalTracks': totalTracks,
    };
  }

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? thumbnail,
    String? customThumbnail,
    String? customColor,
    String? customText,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      thumbnail: thumbnail ?? this.thumbnail,
      customThumbnail: customThumbnail ?? this.customThumbnail,
      customColor: customColor ?? this.customColor,
      customText: customText ?? this.customText,
      createdBy: createdBy,
      ownerName: ownerName,
      members: members,
      songs: songs ?? this.songs,
      visibility: visibility,
      type: type,
      totalTracks: totalTracks,
      createdAt: createdAt,
      lastPlayedAt: lastPlayedAt,
    );
  }
}
