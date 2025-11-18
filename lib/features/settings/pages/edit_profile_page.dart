import 'package:flutter/material.dart';
import 'package:familee_dental/features/settings/controller/edit_profile_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/features/settings/controller/edit_user_controller.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';
import 'package:familee_dental/features/auth/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:familee_dental/shared/services/connectivity_service.dart';
import 'package:familee_dental/shared/widgets/connection_error_dialog.dart';
import 'package:familee_dental/shared/storage/hive_storage.dart';
import 'dart:convert';

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

  // Original values to track changes
  String _originalName = '';
  String _originalUsername = '';
  String _originalEmail = '';

  // In-memory cache for profile data
  Map<String, dynamic>? _cachedProfileData;

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

      if (currentUser == null) {
        // Try to load from cache if no user
        await _loadProfileFromHive();
        return;
      }

      // 1. First, try to load from Hive cache (for offline support)
      await _loadProfileFromHive(currentUser.id);

      // 2. Then try to fetch from Supabase (if online)
      try {
        final response = await supabase
            .from('user_roles')
            .select('*')
            .eq('id', currentUser.id)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          // Use data from user_roles table
          final name = response['name'] ?? '';
          final username = response['username'] ?? '';
          final email = response['email'] ?? '';
          final role = response['role'] ?? 'Admin';
          final id = response['id'] ?? currentUser.id;

          // Save to Hive cache for next time
          await _saveProfileToHive(currentUser.id, {
            'name': name,
            'username': username,
            'email': email,
            'role': role,
            'id': id,
          });

          if (mounted) {
            setState(() {
              _currentUserId = id;
              _currentUserRole = role;
              _nameController.text = name;
              _usernameController.text = username;
              _emailController.text = email;
              // Store original values
              _originalName = name;
              _originalUsername = username;
              _originalEmail = email;
            });
          }
        } else {
          // Fallback to auth user data
          final name = currentUser.userMetadata?['display_name'] ?? '';
          final username = currentUser.userMetadata?['username'] ?? '';
          final email = currentUser.email ?? '';

          // Save to Hive cache
          await _saveProfileToHive(currentUser.id, {
            'name': name,
            'username': username,
            'email': email,
            'role': 'Admin',
            'id': currentUser.id,
          });

          if (mounted) {
            setState(() {
              _currentUserId = currentUser.id;
              _currentUserRole = 'Admin';
              _nameController.text = name;
              _usernameController.text = username;
              _emailController.text = email;
              // Store original values
              _originalName = name;
              _originalUsername = username;
              _originalEmail = email;
            });
          }
        }
      } catch (e) {
        // If Supabase fetch fails (e.g., offline), use cached data
        print('Error fetching from Supabase: $e');
        // _loadProfileFromHive was already called above, so data should be loaded
        if (_cachedProfileData != null && mounted) {
          final name = _cachedProfileData!['name'] ?? '';
          final username = _cachedProfileData!['username'] ?? '';
          final email = _cachedProfileData!['email'] ?? '';
          final role = _cachedProfileData!['role'] ?? 'Admin';
          final id = _cachedProfileData!['id'] ?? currentUser.id;

          setState(() {
            _currentUserId = id;
            _currentUserRole = role;
            _nameController.text = name;
            _usernameController.text = username;
            _emailController.text = email;
            // Store original values
            _originalName = name;
            _originalUsername = username;
            _originalEmail = email;
          });
        } else if (widget.user != null) {
          // Use passed user data as fallback
          final name =
              widget.user!['name'] ?? widget.user!['displayName'] ?? '';
          final username = widget.user!['username'] ?? '';
          final email = widget.user!['email'] ?? '';
          if (mounted) {
            setState(() {
              _nameController.text = name;
              _usernameController.text = username;
              _emailController.text = email;
              // Store original values
              _originalName = name;
              _originalUsername = username;
              _originalEmail = email;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      // Try to load from cache as last resort
      await _loadProfileFromHive();
      // Use passed user data as fallback if cache is empty
      if (_cachedProfileData == null && widget.user != null) {
        final name = widget.user!['name'] ?? widget.user!['displayName'] ?? '';
        final username = widget.user!['username'] ?? '';
        final email = widget.user!['email'] ?? '';
        if (mounted) {
          setState(() {
            _nameController.text = name;
            _usernameController.text = username;
            _emailController.text = email;
            // Store original values
            _originalName = name;
            _originalUsername = username;
            _originalEmail = email;
          });
        }
      }
    }
  }

  /// Load profile data from Hive cache
  Future<void> _loadProfileFromHive([String? userId]) async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = userId != null ? null : supabase.auth.currentUser;
      final targetUserId = userId ?? currentUser?.id;

      if (targetUserId == null) return;

      final box = await HiveStorage.openBox(HiveStorage.editProfileBox);
      final profileDataStr = box.get('profile_$targetUserId') as String?;

      if (profileDataStr != null) {
        _cachedProfileData = jsonDecode(profileDataStr) as Map<String, dynamic>;

        if (mounted && _cachedProfileData != null) {
          final name = _cachedProfileData!['name'] ?? '';
          final username = _cachedProfileData!['username'] ?? '';
          final email = _cachedProfileData!['email'] ?? '';
          final role = _cachedProfileData!['role'] ?? 'Admin';
          final id = _cachedProfileData!['id'] ?? targetUserId;

          setState(() {
            _currentUserId = id;
            _currentUserRole = role;
            _nameController.text = name;
            _usernameController.text = username;
            _emailController.text = email;
            // Store original values
            _originalName = name;
            _originalUsername = username;
            _originalEmail = email;
          });
        }
      }
    } catch (e) {
      print('Error loading profile from Hive: $e');
    }
  }

  /// Save profile data to Hive cache
  Future<void> _saveProfileToHive(
      String userId, Map<String, dynamic> profileData) async {
    try {
      _cachedProfileData = profileData;
      final box = await HiveStorage.openBox(HiveStorage.editProfileBox);
      await box.put('profile_$userId', jsonEncode(profileData));
    } catch (e) {
      print('Error saving profile to Hive: $e');
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
      resizeToAvoidBottomInset: false,
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
              padding: EdgeInsets.symmetric(
                horizontal:
                    MediaQuery.of(context).size.width < 768 ? 1.0 : 16.0,
                vertical: 12.0,
              ),
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
                        // Only allow letters and spaces
                        final namePattern = RegExp(r'^[a-zA-Z\s]+$');
                        if (!namePattern.hasMatch(value.trim())) {
                          return 'Name can only contain letters and spaces';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(
                            () {}); // Trigger rebuild to update button state
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
                        // Only allow letters and numbers
                        final usernamePattern = RegExp(r'^[a-zA-Z0-9]+$');
                        if (!usernamePattern.hasMatch(value.trim())) {
                          return 'Username can only contain letters and numbers';
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
                        setState(
                            () {}); // Trigger rebuild to update button state
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
                        setState(
                            () {}); // Trigger rebuild to update button state
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
                        onPressed: (_isSaving || !_hasChanges())
                            ? null
                            : _showSaveConfirmationDialog,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
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
                  child: SingleChildScrollView(
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
                                  if (text.isEmpty)
                                    return 'Enter a new password';

                                  // Inline validation if new == current
                                  if (text == _currentPassword.text.trim()) {
                                    return 'New password should be different from the old password.';
                                  }

                                  return _passwordController
                                          .isPasswordValid(text)
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                  final isValid = _passwordFormKey.currentState
                                          ?.validate() ??
                                      false;
                                  if (!isValid) return;

                                  // Show confirmation dialog before changing password
                                  await _showPasswordChangeConfirmationDialog();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D4AA),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPasswordChangeConfirmationDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to change your password?',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
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
                          'Yes',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: Text(
                          'No',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color,
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

    if (confirmed == true) {
      await _handlePasswordChange();
    }
  }

  Future<void> _handlePasswordChange() async {
    // Check network connection after confirmation
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      showConnectionErrorDialog(context);
      return;
    }

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

          // Clear password fields
          _currentPassword.clear();
          _newPassword.clear();
          _confirmPassword.clear();

          // ✅ Close password change dialog
          Navigator.of(context).pop();

          // Show relogin dialog
          await _showReloginDialog();
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
        // Check if it's a network error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('socketexception') ||
            errorString.contains('failed host lookup') ||
            errorString.contains('no address associated') ||
            errorString.contains('network is unreachable') ||
            errorString.contains('connection refused') ||
            errorString.contains('connection timed out') ||
            errorString.contains('clientexception') ||
            errorString.contains('connection abort') ||
            errorString.contains('software caused connection abort')) {
          await showConnectionErrorDialog(context);
        } else {
          // Other error - show generic error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating password: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showReloginDialog() async {
    // Logout automatically when dialog is shown
    final authService = AuthService();
    await authService.logout();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Password Changed',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your password has been changed successfully. Please login again with your new password.',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Close the dialog and navigate to login page
                      Navigator.of(context).pop();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      }
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
                      'Go to Login',
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
          ),
        );
      },
    );
  }

  bool _hasChanges() {
    final currentName = _nameController.text.trim();
    final currentUsername = _usernameController.text.trim();
    final currentEmail = _emailController.text.trim();

    return currentName != _originalName ||
        currentUsername != _originalUsername ||
        currentEmail != _originalEmail;
  }

  Future<void> _showSaveConfirmationDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 400,
              minWidth: 350,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4AA).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.save,
                    color: Color(0xFF00D4AA),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Save Changes',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to save these changes?',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
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
                          'Yes',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                        child: Text(
                          'No',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w500,
                            color: theme.textTheme.bodyMedium?.color,
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

    if (confirmed == true) {
      await _handleSave();
    }
  }

  Future<void> _handleSave() async {
    // Check network connection after confirmation
    final hasConnection = await ConnectivityService().hasInternetConnection();
    if (!hasConnection) {
      showConnectionErrorDialog(context);
      return;
    }

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
      final newUsername = _usernameController.text.trim();
      final newEmail = _emailController.text.trim();

      await _settingsActivityController.logProfileEdit(
        userName: newName,
      );

      // Update Hive cache with new data
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await _saveProfileToHive(currentUser.id, {
          'name': newName,
          'username': newUsername,
          'email': newEmail,
          'role': _currentUserRole,
          'id': _currentUserId,
        });
      }

      if (mounted) {
        // Update original values after successful save
        setState(() {
          _originalName = _nameController.text.trim();
          _originalUsername = _usernameController.text.trim();
          _originalEmail = _emailController.text.trim();
        });

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
        // Check if it's a network error
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('socketexception') ||
            errorString.contains('failed host lookup') ||
            errorString.contains('no address associated') ||
            errorString.contains('network is unreachable') ||
            errorString.contains('connection refused') ||
            errorString.contains('connection timed out') ||
            errorString.contains('clientexception') ||
            errorString.contains('connection abort') ||
            errorString.contains('software caused connection abort')) {
          await showConnectionErrorDialog(context);
        } else {
          // Other error - show generic error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating profile: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
