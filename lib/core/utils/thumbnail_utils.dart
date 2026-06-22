/// Thumbnail utilities — enhanced for HD/Ultra-HD visual experience.
class ThumbnailUtils {
  ThumbnailUtils._();

  /// Upgrades a YouTube/Google thumbnail URL to the highest available resolution.
  /// Standard sizes: 120 (tiles), 400 (cards), 800 (header/player), 1200 (HD Banner).
  static String getHighRes(String? url, {int size = 800}) {
    if (url == null || url.isEmpty) return '';

    // Force HTTPS
    var result = url.replaceFirst('http://', 'https://');
    if (result.startsWith('//')) {
      result = 'https:$result';
    }

    try {
      // 1. Handle YouTube Content (lh3.googleusercontent.com / ggpht.com)
      if (result.contains('googleusercontent.com') || result.contains('ggpht.com')) {
        // Upgrade existing width-height parameters
        var newUrl = result.replaceFirstMapped(
          RegExp(r'=w\d+-h\d+'),
          (m) => '=w$size-h$size',
        );
        
        // Upgrade existing square size parameters
        if (newUrl == result) {
          newUrl = result.replaceFirstMapped(
            RegExp(r'=s\d+'),
            (m) => '=s$size',
          );
        }
        
        // Inject parameters if missing
        if (newUrl == result && !result.contains('=w') && !result.contains('=s')) {
          if (result.contains('-c')) {
            newUrl = result.replaceFirst('-c', '=w$size-h$size-c-rj'); // -rj is better for JPEG quality
          } else {
            newUrl = '$result=w$size-h$size-rj';
          }
        }
        
        return newUrl;
      }

      // 2. Handle YouTube Image CDN (i.ytimg.com / img.youtube.com)
      if (result.contains('ytimg.com') || result.contains('youtube.com/vi/')) {
        // For banners and player art, we ALWAYS want maxresdefault if possible
        if (size >= 800) {
          // Find the video ID (11 chars)
          final vidMatch = RegExp(r'/vi/([a-zA-Z0-9_-]{11})').firstMatch(result);
          if (vidMatch != null) {
            return 'https://i.ytimg.com/vi/${vidMatch.group(1)}/maxresdefault.jpg';
          }
          
          // Fallback if URL is already a direct image link
          return result.replaceFirstMapped(
            RegExp(r'/(default|mqdefault|hqdefault|sddefault)\.jpg'),
            (m) => '/maxresdefault.jpg',
          );
        }

        // For smaller tiles, hqdefault is usually best/fastest
        return result.replaceFirstMapped(
          RegExp(r'/(default|mqdefault|sddefault|maxresdefault)\.jpg'),
          (m) => '/hqdefault.jpg',
        );
      }
    } catch (_) {
      // If parsing fails, return original
    }

    return result;
  }
}
