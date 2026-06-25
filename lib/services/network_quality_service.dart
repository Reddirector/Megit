import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Resolves the user's streaming-quality preference ('automatic' | 'low' |
/// 'normal' | 'high') into a concrete value the [StreamExtractor] understands,
/// taking the current network connection into account.
///
/// Why this exists: 'automatic' previously fell through to the exact same
/// code path as 'high' in StreamExtractor — it never actually looked at the
/// connection. That's the main reason songs that load instantly on Wi-Fi
/// would stall or never start on mobile data: the player was always being
/// handed the highest-bitrate audio stream available, regardless of how much
/// throughput the connection could actually sustain.
class NetworkQualityService {
  static final Connectivity _connectivity = Connectivity();

  /// True if the active connection is cellular (or tethered off a phone's
  /// cellular connection) rather than Wi-Fi/ethernet.
  static Future<bool> isOnCellular() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        return false;
      }
      return results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.bluetooth);
    } catch (e) {
      debugPrint('[NetworkQualityService] checkConnectivity failed: $e');
      // If we can't tell, don't gamble on a stream the connection might not
      // sustain — prefer the safer, lower-bitrate choice.
      return true;
    }
  }

  /// Resolves [preference] into a concrete quality: 'low' | 'normal' | 'high'.
  /// Only 'automatic' is network-aware; an explicit user choice is always
  /// honored as-is, even on mobile data.
  static Future<String> resolveQuality(String preference) async {
    if (preference != 'automatic') return preference;
    return await isOnCellular() ? 'normal' : 'high';
  }
}
