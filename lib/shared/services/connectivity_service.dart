import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to check internet connectivity
///
/// This service provides methods to check if the device has an active
/// internet connection, not just network connectivity.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has an active internet connection
  ///
  /// Returns true if device is connected to a network (WiFi/Mobile data).
  /// For write operations, we use a fail-open approach: only block if we're
  /// CERTAIN there's no connection. If uncertain, allow the operation to proceed
  /// and let Supabase handle errors gracefully. This prevents false positives
  /// especially on desktop platforms where connectivity_plus may be unreliable.
  Future<bool> hasInternetConnection() async {
    try {
      // Check if device has network connectivity (WiFi/Mobile data)
      // Use timeout to prevent hanging on platforms where this might be slow
      List<ConnectivityResult> connectivityResults;
      try {
        connectivityResults = await _connectivity
            .checkConnectivity()
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Timeout - can't determine, fail open (allow operation)
        return true;
      }

      // Fail-open: If we get empty results or can't determine, assume connected
      // (allow operation to proceed, Supabase will handle errors)
      if (connectivityResults.isEmpty) {
        // Can't determine - allow operation (fail open)
        return true;
      }

      // Only block if we're CERTAIN there's no connection
      // (explicitly contains ConnectivityResult.none and nothing else)
      final hasNoConnection = connectivityResults.length == 1 &&
          connectivityResults.contains(ConnectivityResult.none);

      // Return false only if we're certain there's no connection
      return !hasNoConnection;
    } catch (e) {
      // If any error occurs during check, fail open (allow operation)
      // This prevents false positives on platforms where connectivity_plus
      // may not work well (e.g., Windows desktop)
      return true;
    }
  }

  /// Check if device has verified internet access (with DNS lookup)
  ///
  /// This is a stricter check that verifies actual internet connectivity
  /// by attempting to resolve a hostname. Use this for read operations
  /// where you want to be certain about internet availability.
  Future<bool> hasVerifiedInternetConnection() async {
    try {
      // First check if device has network connectivity
      final connectivityResults = await _connectivity.checkConnectivity();

      // If no network connection at all, return false immediately
      if (connectivityResults.isEmpty ||
          connectivityResults.contains(ConnectivityResult.none)) {
        return false;
      }

      // Verify actual internet access by attempting to connect to a reliable host
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));

        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (e) {
        // Connection failed or timed out
        return false;
      }

      return false;
    } catch (e) {
      // If any error occurs, assume no connection
      return false;
    }
  }

  /// Check if device has network connectivity (WiFi/Mobile data)
  ///
  /// Returns true if device is connected to a network, false otherwise.
  /// Note: This doesn't verify actual internet access, just network connectivity.
  Future<bool> hasNetworkConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      return connectivityResults.isNotEmpty &&
          !connectivityResults.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Stream of connectivity changes
  ///
  /// Listen to this stream to be notified when connectivity status changes.
  Stream<List<ConnectivityResult>> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged;
  }
}
