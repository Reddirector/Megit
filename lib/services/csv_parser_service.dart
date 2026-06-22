import 'dart:convert';
import 'dart:io';

class CSVTrackData {
  final String title;
  final String artist;
  
  CSVTrackData({required this.title, required this.artist});
}

class CSVPlaylistData {
  final String name;
  final List<CSVTrackData> tracks;
  CSVPlaylistData({required this.name, required this.tracks});
}

class CSVParserService {
  /// Parses a CSV file and extracts track information.
  /// Expects a header row. Tries to find 'title'/'name' and 'artist' columns.
  static Future<CSVPlaylistData> parseFile(File file) async {
    final List<String> lines = await file.readAsLines();
    if (lines.isEmpty) throw Exception('CSV file is empty');

    final String fileName = file.path.split('/').last.split('.').first;
    final List<CSVTrackData> tracks = [];

    // Parse Header
    final List<String> header = _splitCsvLine(lines.first);
    int titleIdx = -1;
    int artistIdx = -1;

    for (int i = 0; i < header.length; i++) {
      final col = header[i].toLowerCase().trim();
      if (col == 'title' || col == 'name' || col == 'track name') titleIdx = i;
      if (col == 'artist' || col == 'artist name') artistIdx = i;
    }

    // Fallback indices if header detection fails
    if (titleIdx == -1) titleIdx = 0;
    if (artistIdx == -1 && header.length > 1) artistIdx = 1;

    // Parse Data Rows
    for (int i = 1; i < lines.length; i++) {
      final List<String> row = _splitCsvLine(lines[i]);
      if (row.length <= titleIdx) continue;

      final title = row[titleIdx].trim();
      final artist = artistIdx != -1 && row.length > artistIdx ? row[artistIdx].trim() : 'Unknown';

      if (title.isNotEmpty) {
        tracks.add(CSVTrackData(title: title, artist: artist));
      }
    }

    if (tracks.isEmpty) throw Exception('No valid tracks found in CSV');

    return CSVPlaylistData(name: fileName, tracks: tracks);
  }

  /// Simple CSV line splitter handling quoted values
  static List<String> _splitCsvLine(String line) {
    final List<String> result = [];
    bool inQuotes = false;
    StringBuffer current = StringBuffer();

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }
}
