import 'package:flutter/material.dart';
import 'package:familee_dental/shared/themes/font.dart';

class Toast {
  static OverlayEntry? _currentToast;
  static bool _isShowing = false;

  static void show(
    BuildContext context, {
    required String message,
    Color backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 3),
    ToastPosition position = ToastPosition.bottom,
    OverlayState? overlay,
  }) {
    try {
      // Remove existing toast if any
      _removeCurrentToast(context);

      // Use provided overlay or try to find one
      OverlayState? overlayToUse = overlay;

      if (overlayToUse == null) {
        // Method 1: Try Navigator's overlay directly (most reliable)
        try {
          final navigatorState =
              Navigator.maybeOf(context, rootNavigator: true);
          if (navigatorState != null) {
            overlayToUse = navigatorState.overlay;
          }
        } catch (e) {
          // Ignore errors
        }
      }

      // Method 2: Try Overlay.maybeOf with rootOverlay
      if (overlayToUse == null) {
        overlayToUse = Overlay.maybeOf(context, rootOverlay: true);
      }

      // Method 3: Try regular Overlay.maybeOf
      if (overlayToUse == null) {
        overlayToUse = Overlay.maybeOf(context);
      }

      if (overlayToUse == null) {
        return;
      }

      _isShowing = true;

      _currentToast = OverlayEntry(
        builder: (context) => _ToastWidget(
          message: message,
          backgroundColor: backgroundColor,
          position: position,
        ),
      );

      overlayToUse.insert(_currentToast!);

      // Auto-remove after duration
      Future.delayed(duration, () {
        if (_isShowing && _currentToast != null) {
          _currentToast!.remove();
          _currentToast = null;
          _isShowing = false;
        }
      });
    } catch (e) {
      // Silently fail - don't crash the app
    }
  }

  static void _removeCurrentToast(BuildContext context) {
    try {
      if (_isShowing && _currentToast != null) {
        _currentToast!.remove();
        _currentToast = null;
        _isShowing = false;
      }
    } catch (e) {
      _currentToast = null;
      _isShowing = false;
    }
  }
}

enum ToastPosition {
  top,
  bottom,
  center,
}

class _ToastWidget extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final ToastPosition position;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: position == ToastPosition.top
              ? MediaQuery.of(context).padding.top + 16
              : position == ToastPosition.center
                  ? MediaQuery.of(context).size.height / 2 - 30
                  : null,
          bottom: position == ToastPosition.bottom
              ? MediaQuery.of(context).padding.bottom + 16
              : null,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 300),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: AppFonts.sfProStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
