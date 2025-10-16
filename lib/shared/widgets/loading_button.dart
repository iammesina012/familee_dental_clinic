import 'package:flutter/material.dart';

/// A reusable button widget that prevents multiple clicks and shows loading state
class LoadingButton extends StatefulWidget {
  final String text;
  final Future<void> Function()? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final Widget? icon;
  final bool isEnabled;

  const LoadingButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
    this.icon,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool _isProcessing = false;

  bool get _isDisabled =>
      widget.isLoading || _isProcessing || !widget.isEnabled;

  void _handlePress() async {
    if (_isDisabled || widget.onPressed == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.isLoading || _isProcessing;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ElevatedButton(
        onPressed: _isDisabled ? null : _handlePress,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor,
          foregroundColor: widget.textColor,
          padding: widget.padding ??
              const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
          shape: RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.textColor ?? Colors.white,
                  ),
                ),
              )
            : widget.icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.icon!,
                      const SizedBox(width: 8),
                      Text(widget.text),
                    ],
                  )
                : Text(widget.text),
      ),
    );
  }
}

/// A simplified loading button for common use cases
class SimpleLoadingButton extends StatelessWidget {
  final String text;
  final Future<void> Function()? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;

  const SimpleLoadingButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LoadingButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }
}
