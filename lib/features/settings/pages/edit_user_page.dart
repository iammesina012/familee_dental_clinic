import 'package:flutter/material.dart';
import 'package:familee_dental/features/settings/controller/edit_user_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';

class EditUserPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const EditUserPage({super.key, required this.user});

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _controller = EditUserController();
  final _settingsActivityController = SettingsActivityController();
  final _formKey = GlobalKey<FormState>();
  final _userRoleProvider = UserRoleProvider();

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _emailController;

  // Form state
  String _selectedStatus = 'Active';
  String _selectedRole = 'Admin';
  bool _isLoading = false;
  bool _isSaving = false;
  Map<String, String?> validationErrors = {};
  bool _hasUnsavedChanges = false;

  // Store original values to compare against
  String _originalName = '';
  String _originalUsername = '';
  String _originalEmail = '';
  String _originalRole = 'Admin';
  String _originalStatus = 'Active';

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _checkPermissions();
  }

  void _checkPermissions() {
    // Check if current user can manage the target user's role
    final targetUserRole = widget.user['role'] ?? 'Staff';
    if (!_userRoleProvider.canManageRole(targetUserRole)) {
      // If cannot manage this role, show error and go back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You do not have permission to edit this user'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.maybePop(context);
        }
      });
    }
  }

  void _initializeForm() {
    _nameController = TextEditingController(
        text: widget.user['displayName'] ?? widget.user['name'] ?? '');
    _usernameController = TextEditingController(
        text: widget.user['username'] ?? widget.user['displayName'] ?? '');
    _emailController = TextEditingController(text: widget.user['email'] ?? '');

    // Initialize status based on isActive field, with fallback
    final isActive = widget.user['isActive'];

    if (isActive == true) {
      _selectedStatus = 'Active';
    } else if (isActive == false) {
      _selectedStatus = 'Inactive';
    } else {
      // Fallback if isActive is null or undefined
      _selectedStatus = 'Active';
    }

    // Initialize role
    _selectedRole = widget.user['role'] ?? 'Admin';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildValidationError(String? error) {
    if (error == null) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
      child: Text(
        error,
        style: TextStyle(
          color: Colors.red,
          fontSize: 12,
          fontFamily: 'SF Pro',
        ),
      ),
    );
  }

  void _markAsChanged() {
    final currentName = _nameController.text.trim();
    final currentUsername = _usernameController.text.trim();
    final currentEmail = _emailController.text.trim();
    final currentRole = _selectedRole;
    final currentStatus = _selectedStatus;

    final hasChanges = currentName != _originalName ||
        currentUsername != _originalUsername ||
        currentEmail != _originalEmail ||
        currentRole != _originalRole ||
        currentStatus != _originalStatus;

    if (_hasUnsavedChanges != hasChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Unsaved Changes',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You have unsaved changes. Are you sure you want to leave?',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Stay',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Leave',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon:
                Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 28),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Edit Employee',
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
            maxWidth: 900,
            child: Align(
              alignment: Alignment.topCenter,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width < 768
                            ? 1.0
                            : 16.0,
                        vertical: 12.0,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name Field
                            _buildTextField(
                              controller: _nameController,
                              label: 'Name',
                              hint: 'Enter name',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Name is required';
                                }
                                return null;
                              },
                              theme: theme,
                              fieldKey: 'name',
                            ),
                            const SizedBox(height: 12),

                            // Username Field
                            _buildTextField(
                              controller: _usernameController,
                              label: 'Username',
                              hint: 'Enter username',
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Username is required';
                                }
                                return null;
                              },
                              theme: theme,
                              fieldKey: 'username',
                            ),
                            const SizedBox(height: 12),

                            // Email Field (Enabled)
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'Enter email address',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Email is required';
                                }
                                if (!_controller.isEmailValid(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                              theme: theme,
                              fieldKey: 'email',
                            ),
                            const SizedBox(height: 12),

                            // Role and Status Row
                            Row(
                              children: [
                                // Role Dropdown
                                Expanded(
                                  child: _buildRoleDropdown(theme),
                                ),
                                const SizedBox(width: 12),
                                // Status Dropdown
                                Expanded(
                                  child: _buildStatusDropdown(theme),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Reset Password Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => _showResetPasswordDialog(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 1,
                                ),
                                child: const Text(
                                  'Reset Password',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveUser,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00D4AA),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    required ThemeData theme,
    String? fieldKey,
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
          onChanged: (value) {
            _markAsChanged();
            if (fieldKey != null && validationErrors[fieldKey] != null) {
              setState(() {
                validationErrors[fieldKey] = null;
              });
            }
          },
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'SF Pro',
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00D4AA), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        if (fieldKey != null) _buildValidationError(validationErrors[fieldKey]),
      ],
    );
  }

  Widget _buildStatusDropdown(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              isExpanded: true,
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
              ),
              hint: Text(
                'Select Status',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                ),
              ),
              items: ['Active', 'Inactive'].map((String status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    status,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 16,
                      color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _markAsChanged();
                  setState(() {
                    _selectedStatus = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown(ThemeData theme) {
    // Get available roles based on current user's permissions
    final availableRoles = _userRoleProvider.getAvailableRolesToAssign();

    // If current user cannot assign any roles, show role as read-only
    if (availableRoles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Role',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? theme.colorScheme.surface
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Text(
              _selectedRole,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
                color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Role',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surface
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedRole,
              isExpanded: true,
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
              ),
              hint: Text(
                'Select Role',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  color: theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                ),
              ),
              items: availableRoles.map((String role) {
                return DropdownMenuItem<String>(
                  value: role,
                  child: Text(
                    role,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 16,
                      color: theme.textTheme.bodyLarge?.color ?? Colors.black,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  _markAsChanged();
                  setState(() {
                    _selectedRole = newValue;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    // Security check: Prevent role escalation
    final availableRoles = _userRoleProvider.getAvailableRolesToAssign();
    if (availableRoles.isNotEmpty && !availableRoles.contains(_selectedRole)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to assign this role'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final result = await _controller.saveUserChanges(
      uid: widget.user['uid'],
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      isActive: _selectedStatus == 'Active',
      role: _selectedRole,
    );

    setState(() => _isSaving = false);

    if (result['success'] == true) {
      // Log employee profile edited activity
      await _settingsActivityController.logEmployeeProfileEdited(
        employeeName: _nameController.text.trim(),
        originalName: widget.user['displayName'] ?? widget.user['name'] ?? '',
        employeeRole: _selectedRole,
        originalRole: widget.user['role'] ?? 'Admin',
        employeeStatus: _selectedStatus,
        originalStatus: widget.user['isActive'] == true ? 'Active' : 'Inactive',
      );

      final successMsg =
          (result['message'] as String?) ?? 'User updated successfully';
      if (mounted) {
        _hasUnsavedChanges = false; // Reset flag on successful save
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: const Color(0xFF00D4AA),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } else {
      final errMsg = (result['error'] as String?) ??
          (result['message'] as String?) ??
          'Update failed. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $errMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResetPasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
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
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_reset,
                    color: Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Reset Password',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Content
                Text(
                  'Are you sure you want to reset the password for "${widget.user['name'] ?? widget.user['displayName']}"?\n\nThis will set their password to the default password.',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
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
                          Navigator.of(context).pop();
                          await _resetPassword();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Reset Password',
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
  }

  Future<void> _resetPassword() async {
    setState(() => _isSaving = true);

    try {
      final result = await _controller.resetPassword(
        uid: widget.user['uid'],
        newPassword: 'famiLee2021',
      );

      setState(() => _isSaving = false);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset successfully to default password'),
              backgroundColor: Color(0xFF00D4AA),
            ),
          );
        }
      } else {
        final errMsg = (result['error'] as String?) ??
            (result['message'] as String?) ??
            'Password reset failed. Please try again.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting password: $errMsg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
