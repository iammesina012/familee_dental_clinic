import 'package:flutter/material.dart';
import 'package:projects/features/settings/controller/change_password_controller.dart';

class ChangePasswordPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const ChangePasswordPage({super.key, this.user});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = ChangePasswordController();

  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  // bool _showCurrent = false; // TEMPORARILY UNUSED
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isSaving = false;

  // String? _currentPasswordServerError; // TEMPORARILY UNUSED

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
            color: null,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor,
        toolbarHeight: 70,
        iconTheme: theme.appBarTheme.iconTheme,
        elevation: theme.appBarTheme.elevation,
        shadowColor: theme.appBarTheme.shadowColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TEMPORARILY REMOVED: Current Password Field
              // _buildPasswordField(
              //   label: 'Current Password',
              //   controller: _currentPassword,
              //   isVisible: _showCurrent,
              //   onToggle: () => setState(() => _showCurrent = !_showCurrent),
              //   validator: (value) {
              //     if (value == null || value.isEmpty) {
              //       return 'Enter your current password';
              //     }
              //     if (_currentPasswordServerError != null) {
              //       return _currentPasswordServerError;
              //     }
              //     return null;
              //   },
              //   onChanged: (_) {
              //     if (_currentPasswordServerError != null) {
              //       setState(() => _currentPasswordServerError = null);
              //       _formKey.currentState?.validate();
              //     }
              //   },
              // ),
              // const SizedBox(height: 16),
              _buildPasswordField(
                label: 'New Password',
                controller: _newPassword,
                isVisible: _showNew,
                onToggle: () => setState(() => _showNew = !_showNew),
                validator: (value) {
                  final text = value ?? '';
                  if (text.isEmpty) return 'Enter a new password';
                  return _controller.isPasswordValid(text)
                      ? null
                      : 'Use 8+ chars with letters and numbers';
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                label: 'Confirm Password',
                controller: _confirmPassword,
                isVisible: _showConfirm,
                onToggle: () => setState(() => _showConfirm = !_showConfirm),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (value != _newPassword.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4AA),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Update Password',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 16,
          ),
          decoration: InputDecoration(
            // Show visible inline error text
            errorStyle: TextStyle(
              height: 1.2,
              fontSize: 12,
              color: theme.colorScheme.error,
              fontFamily: 'SF Pro',
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(
                color: Color(0xFF00D4AA),
                width: 1,
              ),
            ),
            // Ensure red border on error
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: 1,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility,
                color: theme.iconTheme.color,
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _isSaving = true;
      // _currentPasswordServerError = null; // TEMPORARILY UNUSED
    });

    final result = await _controller.changePassword(
      currentPassword:
          '', // TEMPORARILY: Pass empty string since current password field is removed
      newPassword: _newPassword.text,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    final ok = result['success'] == true;
    final message = (result['message'] as String?) ??
        (ok ? 'Password updated' : 'Unable to update password');

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF00D4AA),
        ),
      );
      Navigator.maybePop(context);
      return;
    }

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );

    final errText = message.toLowerCase();
    final isWrongPassword = errText.contains('incorrect') ||
        errText.contains('wrong-password') ||
        errText.contains('invalid-credential') ||
        errText.contains('wrong password') ||
        errText.contains('invalid credential');

    if (isWrongPassword) {
      // setState(
      //     () => _currentPasswordServerError = 'Current password is incorrect.');
      // _formKey.currentState?.validate();
    } else {
      // No error snackbar; show inline error on current field
      // setState(() => _currentPasswordServerError = message);
      // _formKey.currentState?.validate();
    }
  }
}
