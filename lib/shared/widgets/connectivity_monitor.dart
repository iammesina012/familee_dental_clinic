import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/toast.dart';

/// Global connectivity monitor that shows toast notifications
/// when internet connection is lost or restored
class ConnectivityMonitor extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const ConnectivityMonitor({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  State<ConnectivityMonitor> createState() => _ConnectivityMonitorState();
}

class _ConnectivityMonitorState extends State<ConnectivityMonitor> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _previousConnectionStatus;
  Timer? _retryTimer;
  bool? _pendingToastStatus;

  @override
  void initState() {
    super.initState();
    // Initialize listener without blocking initial check
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    // Listen to connectivity changes directly (non-blocking)
    final connectivityService = ConnectivityService();

    // Get initial status immediately without blocking
    connectivityService.onConnectivityChanged.first.then((results) {
      final hasConnection = results.any((result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet);
      _previousConnectionStatus = hasConnection;
    });

    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        // Determine if we have connection (same logic as other pages)
        final hasConnection = results.any((result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet);

        // Only show toast if status actually changed
        if (_previousConnectionStatus != null &&
            _previousConnectionStatus != hasConnection) {
          // Cancel any pending retry
          _retryTimer?.cancel();
          _pendingToastStatus = hasConnection;

          // Try to show immediately (don't wait for post-frame)
          if (mounted) {
            // Try immediate first
            _showConnectivityToast(hasConnection, retryCount: 0);

            // Also schedule a retry in case immediate failed
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _pendingToastStatus == hasConnection) {
                _tryShowToast(hasConnection, retryCount: 1);
              }
            });
          }
        }

        // Update previous status
        _previousConnectionStatus = hasConnection;
      },
      onError: (error) {
        // Ignore errors to prevent app freezing
      },
    );
  }

  void _tryShowToast(bool isConnected, {int retryCount = 0}) {
    if (!mounted) {
      return;
    }

    // Wait for next frame first
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      // Then try to show with a small delay to ensure overlay is ready
      final delay = Duration(milliseconds: 100 * (retryCount + 1));

      Future.delayed(delay, () {
        if (!mounted) {
          return;
        }
        _showConnectivityToast(isConnected, retryCount: retryCount);
      });
    });
  }

  void _showConnectivityToast(bool isConnected, {int retryCount = 0}) {
    if (!mounted) {
      return;
    }

    // Try to get NavigatorState's overlay directly (most reliable method)
    final navigatorState = widget.navigatorKey.currentState;
    OverlayState? overlay;
    BuildContext? contextToUse;

    if (navigatorState != null) {
      try {
        // NavigatorState has direct access to overlay
        overlay = navigatorState.overlay;
        final navContext = navigatorState.context;

        if (overlay != null && navContext.mounted) {
          contextToUse = navContext;
        }
      } catch (e) {
        overlay = null;
        contextToUse = null;
      }
    }

    // Fallback to NavigatorKey context
    if (contextToUse == null) {
      contextToUse = widget.navigatorKey.currentContext;
    }

    // If we still don't have context, retry multiple times with increasing delays
    if (contextToUse == null || !contextToUse.mounted) {
      if (retryCount < 10) {
        _retryTimer?.cancel();

        // Use exponential backoff: 100ms, 200ms, 400ms, 800ms, etc. up to 1600ms
        final delayMs = (retryCount < 5)
            ? 100 * (1 << retryCount) // Exponential: 100, 200, 400, 800, 1600
            : 1600; // Cap at 1600ms for later retries

        _retryTimer = Timer(Duration(milliseconds: delayMs), () {
          if (mounted && _pendingToastStatus != null) {
            _tryShowToast(_pendingToastStatus!, retryCount: retryCount + 1);
          }
        });
        return;
      } else {
        _pendingToastStatus = null;
        return;
      }
    }

    // Clear pending status and cancel retry timer since we're showing it now
    _pendingToastStatus = null;
    _retryTimer?.cancel();

    try {
      Toast.show(
        contextToUse,
        message: isConnected
            ? 'Your internet connection was restored'
            : 'You are currently offline',
        backgroundColor: isConnected ? const Color(0xFF00D4AA) : Colors.orange,
        duration: const Duration(seconds: 3),
        position: ToastPosition.bottom,
        overlay: overlay, // Pass overlay directly if we have it
      );
    } catch (e) {
      // Retry one more time if showing failed
      if (retryCount < 10) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _pendingToastStatus != null) {
            _tryShowToast(_pendingToastStatus!, retryCount: retryCount + 1);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if we have a pending toast to show when widget rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pendingToastStatus != null) {
        // Try once more when widget rebuilds (like when user interacts)
        _tryShowToast(_pendingToastStatus!, retryCount: 0);
      }
    });

    return widget.child;
  }
}
