import 'package:flutter/material.dart';
import 'package:familee_dental/features/settings/controller/edit_profile_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/features/settings/controller/edit_user_controller.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const EditProfilePage({super.key, this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = EditProfileController();
  final _editUserController = EditUserController();
  final _settingsActivityController = SettingsActivityController();

  // ✅ Stable key for the Change Password dialog's form
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();

  // Profile fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Password fields
  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isSaving = false;

  // Validation errors
  String? _usernameError;
  String? _emailError;
  String? _currentPasswordError;

  // Current user data
  String _currentUserId = 'Unknown';
  String _currentUserRole = 'Admin'; // Default role

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    try {
      // Get current user from Supabase Auth
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // Try to get user data from user_roles table
        final response = await supabase
            .from('user_roles')
            .select('*')
            .eq('id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          // Use data from user_roles table
          setState(() {
            _currentUserId = response['id'] ?? currentUser.id;
            _currentUserRole = response['role'] ?? 'Admin';
            _nameController.text = response['name'] ?? '';
            _usernameController.text = response['username'] ?? '';
            _emailController.text = response['email'] ?? '';
          });
        } else {
          // Fallback to auth user data
          setState(() {
            _currentUserId = currentUser.id;
            _currentUserRole = 'Admin'; // Default role for auth users
            _nameController.text =
                currentUser.userMetadata?['display_name'] ?? '';
            _usernameController.text =
                currentUser.userMetadata?['username'] ?? '';
            _emailController.text = currentUser.email ?? '';
          });
        }
      } else if (widget.user != null) {
        // Use passed user data as fallback
        _nameController.text =
            widget.user!['name'] ?? widget.user!['displayName'] ?? '';
        _usernameController.text = widget.user!['username'] ?? '';
        _emailController.text = widget.user!['email'] ?? '';
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Use passed user data as fallback
      if (widget.user != null) {
        _nameController.text =
            widget.user!['name'] ?? widget.user!['displayName'] ?? '';
        _usernameController.text = widget.user!['username'] ?? '';
        _emailController.text = widget.user!['email'] ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
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
          'Edit Profile',
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
      body: SafeArea(
        top: false,
        child: ResponsiveContainer(
          maxWidth: 1000,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: MediaQuery.of(context).size.width < 768
                  ? const EdgeInsets.all(8.0)
                  : const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      label: 'Name',
                      controller: _nameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                      theme: theme,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      label: 'Username',
                      controller: _usernameController,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (_usernameError != null) {
                          return _usernameError;
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (_usernameError != null) {
                          setState(() => _usernameError = null);
                          _formKey.currentState?.validate();
                        }
                      },
                      theme: theme,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!_editUserController.isEmailValid(value)) {
                          return 'Please enter a valid email address';
                        }
                        if (_emailError != null) {
                          return _emailError;
                        }
                        return null;
                      },
                      onChanged: (value) {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                          _formKey.currentState?.validate();
                        }
                      },
                      theme: theme,
                    ),
                    const SizedBox(height: 20),

                    // Change Password Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showChangePasswordDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Change Password',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Save Changes Button
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
                                'Save Changes',
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
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    required ThemeData theme,
  }) {
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
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 16,
          ),
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    required ThemeData theme,
  }) {
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
          onChanged: onChanged,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 16,
          ),
          decoration: InputDecoration(
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
        ),
      ],
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 8,
              backgroundColor: theme.dialogBackgroundColor,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: theme.dialogBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon and Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4AA).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Color(0xFF00D4AA),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Change Password',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Password Fields
                    Form(
                      key: _passwordFormKey, // ✅ stable key
                      child: Column(
                        children: [
                          _buildPasswordField(
                            label: 'Current Password',
                            controller: _currentPassword,
                            isVisible: _showCurrent,
                            onToggle: () => setDialogState(
                                () => _showCurrent = !_showCurrent),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your current password';
                              }
                              if (_currentPasswordError != null) {
                                return _currentPasswordError;
                              }
                              return null;
                            },
                            // ✅ clear external error and re-validate without rebuilding dialog
                            onChanged: (value) {
                              if (_currentPasswordError != null) {
                                _currentPasswordError = null;
                                _passwordFormKey.currentState?.validate();
                              }
                            },
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                            label: 'New Password',
                            controller: _newPassword,
                            isVisible: _showNew,
                            onToggle: () =>
                                setDialogState(() => _showNew = !_showNew),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'Enter a new password';

                              // Inline validation if new == current
                              if (text == _currentPassword.text.trim()) {
                                return 'New password should be different from the old password.';
                              }

                              return _passwordController.isPasswordValid(text)
                                  ? null
                                  : 'Use 8+ chars with letters, numbers, and uppercase';
                            },
                            theme: theme,
                          ),
                          const SizedBox(height: 16),
                          _buildPasswordField(
                            label: 'Confirm Password',
                            controller: _confirmPassword,
                            isVisible: _showConfirm,
                            onToggle: () => setDialogState(
                                () => _showConfirm = !_showConfirm),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your new password';
                              }
                              if (value != _newPassword.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: theme.dividerColor),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              // ✅ validate inside the dialog first
                              final isValid =
                                  _passwordFormKey.currentState?.validate() ??
                                      false;
                              if (!isValid) return;

                              await _handlePasswordChange();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00D4AA),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Update Password',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handlePasswordChange() async {
    // Clear previous errors
    _currentPasswordError = null;
    _passwordFormKey.currentState?.validate();

    if (_currentPassword.text.isEmpty) {
      _currentPasswordError = 'Please enter your current password';
      _passwordFormKey.currentState
          ?.validate(); // show inline error immediately
      return;
    }

    if (_newPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a new password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_newPassword.text != _confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_passwordController.isPasswordValid(_newPassword.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Password must be 8+ characters with letters and numbers'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate current password against authentication
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser?.email == null) {
        _currentPasswordError = 'No email found for current user';
        _passwordFormKey.currentState?.validate();
        return;
      }

      // Validate current password by attempting to sign in
      await supabase.auth.signInWithPassword(
        email: currentUser!.email!,
        password: _currentPassword.text.trim(),
      );
    } catch (e) {
      // Wrong current password -> show inline error, keep dialog open
      _currentPasswordError = 'Current password is incorrect';
      _passwordFormKey.currentState?.validate();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await _passwordController.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (result['success'] == true) {
          // Log password change activity
          await _settingsActivityController.logPasswordChange(
            userName: _nameController.text.trim(),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password updated successfully'),
              backgroundColor: Color(0xFF00D4AA),
            ),
          );
          // Clear password fields
          _currentPassword.clear();
          _newPassword.clear();
          _confirmPassword.clear();

          // ✅ Close dialog only on success
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating password: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Update profile information
      final profileResult = await _editUserController.updateUserProfile(
        uid: _currentUserId,
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        role: _currentUserRole, // Use current user's role
      );

      if (!profileResult['success']) {
        final error =
            profileResult['error'] as String? ?? 'Failed to update profile';

        // Check for specific errors
        if (error.toLowerCase().contains('username')) {
          setState(() => _usernameError = 'Username already exists');
        } else if (error.toLowerCase().contains('email')) {
          setState(() => _emailError = 'Email already exists');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating profile: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Log profile edit activity (without additional details for privacy)
      final newName = _nameController.text.trim();

      await _settingsActivityController.logProfileEdit(
        userName: newName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF00D4AA),
          ),
        );
        Navigator.maybePop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
