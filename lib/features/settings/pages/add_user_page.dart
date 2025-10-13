import 'package:flutter/material.dart';
import 'package:familee_dental/features/settings/controller/add_user_controller.dart';
import 'package:familee_dental/shared/widgets/responsive_container.dart';
import 'package:familee_dental/shared/providers/user_role_provider.dart';
import 'package:familee_dental/features/activity_log/controller/settings_activity_controller.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _controller = AddUserController();
  final _settingsActivityController = SettingsActivityController();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  // Form state
  String _selectedRole = 'Staff';
  bool _isCreating = false;

  // Validation state
  String? _usernameError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _initializeRole();
  }

  void _initializeRole() {
    final availableRoles = _controller.getAvailableRoles();

    // If only one role available (Admin can only assign Staff), auto-select it
    if (availableRoles.length == 1) {
      _selectedRole = availableRoles.first;
    }
    // Otherwise, default to first available role (Owner can choose between Admin/Staff)
    else if (availableRoles.isNotEmpty) {
      _selectedRole = availableRoles.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userRoleProvider = UserRoleProvider();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Add Employee',
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
      body: ResponsiveContainer(
        maxWidth: 900,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(
                MediaQuery.of(context).size.width < 768 ? 8.0 : 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Default Password Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Default password: familee2021',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 14,
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name Field
                  _buildTextField(
                    controller: _nameController,
                    label: 'Name',
                    hint: 'Enter display name',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // Username Field
                  _buildTextField(
                    controller: _usernameController,
                    label: 'Username',
                    hint: 'Enter username',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Username is required';
                      }
                      if (_usernameError != null) {
                        return _usernameError;
                      }
                      return null;
                    },
                    onChanged: (value) async {
                      // Clear previous error
                      setState(() {
                        _usernameError = null;
                      });

                      // Real-time username validation
                      if (value.isNotEmpty) {
                        final isTaken =
                            await _controller.isUsernameTaken(value.trim());
                        if (isTaken && mounted) {
                          setState(() {
                            _usernameError = 'Username is already taken';
                          });
                        }
                      }
                    },
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // Email Field
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
                      if (_emailError != null) {
                        return _emailError;
                      }
                      return null;
                    },
                    onChanged: (value) async {
                      // Clear previous error
                      setState(() {
                        _emailError = null;
                      });

                      // Real-time email validation
                      if (value.isNotEmpty && _controller.isEmailValid(value)) {
                        final isTaken =
                            await _controller.isEmailTaken(value.trim());
                        if (isTaken && mounted) {
                          setState(() {
                            _emailError = 'Email is already taken';
                          });
                        }
                      }
                    },
                    theme: theme,
                  ),
                  const SizedBox(height: 16),

                  // Role Field - Only show if there are multiple role options
                  if (_controller.getAvailableRoles().length > 1) ...[
                    _buildRoleDropdown(theme),
                    const SizedBox(height: 16),
                  ],

                  // Show role info if Admin (since they can only assign Staff)
                  if (userRoleProvider.isAdmin &&
                      _controller.getAvailableRoles().length == 1) ...[
                    _buildRoleInfo(theme),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 16),

                  // Create User Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D4AA),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Create User',
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Function(String)? onChanged,
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
      ],
    );
  }

  Widget _buildRoleDropdown(ThemeData theme) {
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
              items: _controller.getAvailableRoles().map((String role) {
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

  Widget _buildRoleInfo(ThemeData theme) {
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
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Staff',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                'Auto-assigned',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    // Check for duplicates before creating
    final isUsernameTaken =
        await _controller.isUsernameTaken(_usernameController.text.trim());
    final isEmailTaken =
        await _controller.isEmailTaken(_emailController.text.trim());

    if (isUsernameTaken) {
      setState(() {
        _isCreating = false;
        _usernameError = 'Username is already taken';
      });
      return;
    }

    if (isEmailTaken) {
      setState(() {
        _isCreating = false;
        _emailError = 'Email is already taken';
      });
      return;
    }

    final result = await _controller.createUser(
      name: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: 'familee2021', // Default password for all new users
      role: _selectedRole,
      isActive: true, // Always create new users as active
    );

    setState(() {
      _isCreating = false;
      _usernameError = null;
      _emailError = null;
    });

    if (result['success']) {
      // Log employee added activity
      await _settingsActivityController.logEmployeeAdded(
        employeeName: _nameController.text.trim(),
        employeeRole: _selectedRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User created successfully'),
            backgroundColor: Color(0xFF00D4AA),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating user: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
