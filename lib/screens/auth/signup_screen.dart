import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:email_validator/email_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../models/enums.dart'; // Make sure this imports your UserRole enum

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  final _phoneController = TextEditingController();
  final _branchController = TextEditingController();
  final _hostelController = TextEditingController();
  final _roomController = TextEditingController();
  final _floorController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  UserRole _selectedRole = UserRole.student;
  List<String> _selectedHostels = [];
  int? _selectedYear;
  bool _isCheckingAvailability = false;
  bool _isSubmitting = false;

  static const List<String> _branchOptions = ['CSE', 'ECE', 'ME', 'CE', 'EE', 'CHE'];
  static const List<String> _hostelOptions = ['Hostel-A', 'Hostel-B', 'Hostel-C', 'Hostel-D'];

  // Fixed extension declaration
  static String _getDashboardRoute(UserRole role) {
    switch (role) {
      case UserRole.student:
        return '/student-dashboard';
      case UserRole.hostelGuard:
      case UserRole.mainGuard:
        return '/guard-dashboard';
      case UserRole.warden:
        return '/warden-dashboard';
      default:
        return '/login';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _rollNumberController.dispose();
    _parentPhoneController.dispose();
    _phoneController.dispose();
    _branchController.dispose();
    _hostelController.dispose();
    _roomController.dispose();
    _floorController.dispose();
    super.dispose();
  }

  String _generateEmployeeId() {
    final random = (DateTime.now().millisecondsSinceEpoch % 900) + 100;
    switch (_selectedRole) {
      case UserRole.hostelGuard:
        final hostelCode = _hostelController.text.isNotEmpty 
            ? _hostelController.text.substring(6, 7) 
            : 'A';
        return 'GRD-H$hostelCode-$random';
      case UserRole.mainGuard:
        return 'GRD-M-$random';
      case UserRole.warden:
        final hostelCode = _selectedHostels.isNotEmpty 
            ? _selectedHostels.first.substring(6, 7) 
            : 'A';
        return 'WDN-$hostelCode-$random';
      default:
        return '';
    }
  }

  Future<bool> _checkIdAvailability() async {
    if (_selectedRole != UserRole.student) return true;

    setState(() => _isCheckingAvailability = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(_rollNumberController.text)
          .get();

      if (snapshot.exists) throw 'Roll number already registered';

      final guardsSnapshot = await FirebaseFirestore.instance
          .collection('guards')
          .doc(_rollNumberController.text)
          .get();

      final wardensSnapshot = await FirebaseFirestore.instance
          .collection('wardens')
          .doc(_rollNumberController.text)
          .get();

      if (guardsSnapshot.exists || wardensSnapshot.exists) {
        throw 'This ID is already in use by another role';
      }

      return true;
    } catch (e) {
      _showErrorSnackbar(e.toString());
      return false;
    } finally {
      setState(() => _isCheckingAvailability = false);
    }
  }


  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == UserRole.student && !await _checkIdAvailability()) return;

    if (_selectedRole == UserRole.hostelGuard && _hostelController.text.isEmpty) {
    _showErrorSnackbar('Hostel guards must select a hostel');
    return;
  }

  // Ensure type is set correctly in roleData
  final roleData = _prepareRoleData();
  if (_selectedRole == UserRole.hostelGuard || _selectedRole == UserRole.mainGuard) {
    roleData['type'] = _selectedRole.toString().split('.').last.toLowerCase();
  }

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();

    try {
      final roleData = _prepareRoleData();
      final documentId = _selectedRole == UserRole.student
          ? _rollNumberController.text
          : _generateEmployeeId();

      final success = await auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        userData: {
          'name': _nameController.text,
          'email': _emailController.text,
          'role': _selectedRole.value,
          if (_selectedRole == UserRole.student) 'rollNumber': documentId,
        },
        roleData: roleData,
        role: _selectedRole,
        documentId: documentId,
      );

      if (success && mounted) {
        Navigator.pushReplacementNamed(
          context, 
          _getDashboardRoute(_selectedRole),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar('Authentication error: ${e.message ?? 'Unknown error'}');
    } catch (e) {
      _showErrorSnackbar('Signup failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isStudentProfileComplete() {
  return _branchController.text.isNotEmpty &&
         _selectedYear != null &&
         _hostelController.text.isNotEmpty &&
         _roomController.text.isNotEmpty &&
         _parentPhoneController.text.length == 10 &&
         _phoneController.text.length == 10;
}

  Map<String, dynamic> _prepareRoleData() {
    final commonData = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };
     // Add dynamic profileComplete check for students
   // ...
  final isProfileComplete = _selectedRole != UserRole.student || _isStudentProfileComplete();

    switch (_selectedRole) {
      case UserRole.student:
        return {
          ...commonData,
          'rollNumber': _rollNumberController.text,
          'branch': _branchController.text,
          'year': _selectedYear,
          'hostelName': _hostelController.text,
          'roomNumber': _roomController.text,
          'floorNumber': _floorController.text.isNotEmpty 
              ? int.tryParse(_floorController.text) 
              : null,
          'parentPhone': _parentPhoneController.text,
          'activeLeaveIds': [],
           'profileComplete': isProfileComplete,
        };
      
      case UserRole.hostelGuard:
        return {
          ...commonData,
          'employeeId': _generateEmployeeId(),
          'type': 'hostel',
          'assignedHostel': _hostelController.text,
          'role': 'hostel_guard', // Consistent with enum
        };
      
      case UserRole.mainGuard:
        return {
          ...commonData,
          'employeeId': _generateEmployeeId(),
          'type': 'main',
          'role': 'main_guard',
        };
      
      case UserRole.warden:
        return {
          ...commonData,
          'employeeId': _generateEmployeeId(),
          'managedHostels': _selectedHostels,
        };
      
      default:
        return {};
    }
  }

  Widget _buildStudentFields() {
    return Column(
      children: [
        CustomTextField(
          label: 'Roll Number (9 digits)',
          controller: _rollNumberController,
          prefixIcon: const Icon(Icons.numbers),
          keyboardType: TextInputType.number,
          validator: (value) => 
              RegExp(r'^\d{9}$').hasMatch(value ?? '') ? null : 'Must be exactly 9 digits',
        ),
        const SizedBox(height: 16),
        _buildBranchDropdown(),
        const SizedBox(height: 16),
        _buildYearDropdown(),
        const SizedBox(height: 16),
        _buildHostelDropdown(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: CustomTextField(
                label: 'Room Number',
                controller: _roomController,
                prefixIcon: const Icon(Icons.door_sliding),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: CustomTextField(
                label: 'Floor',
                controller: _floorController,
                prefixIcon: const Icon(Icons.stairs),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Parent Phone',
          controller: _parentPhoneController,
          prefixIcon: const Icon(Icons.phone),
          keyboardType: TextInputType.phone,
          validator: (value) => 
              value != null && value.length == 10 ? null : 'Enter 10-digit number',
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Your Phone',
          controller: _phoneController,
          prefixIcon: const Icon(Icons.phone_android),
          keyboardType: TextInputType.phone,
          validator: (value) => 
              value != null && value.length == 10 ? null : 'Enter 10-digit number',
        ),
      ],
    );
  }

  Widget _buildGuardFields() {
    return Column(
      children: [
        _buildRoleDropdown(),
        const SizedBox(height: 16),
        if (_selectedRole == UserRole.hostelGuard) ...[
          _buildHostelDropdown(),
          const SizedBox(height: 16),
        ],
        CustomTextField(
          label: 'Phone Number',
          controller: _phoneController,
          prefixIcon: const Icon(Icons.phone),
          keyboardType: TextInputType.phone,
          validator: (value) => 
              value != null && value.length == 10 ? null : 'Enter 10-digit number',
        ),
      ],
    );
  }

  Widget _buildWardenFields() {
    return Column(
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Managed Hostels',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.home_work),
          ),
          child: Row(
            children: [
              Text(_selectedHostels.isEmpty 
                  ? 'Select Hostels' 
                  : _selectedHostels.join(', ')),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_drop_down),
                onPressed: () => _selectHostels(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          label: 'Phone Number',
          controller: _phoneController,
          prefixIcon: const Icon(Icons.phone),
          keyboardType: TextInputType.phone,
          validator: (value) => 
              value != null && value.length == 10 ? null : 'Enter 10-digit number',
        ),
      ],
    );
  }

  Widget _buildBranchDropdown() {
    return DropdownButtonFormField<String>(
      value: _branchController.text.isEmpty ? null : _branchController.text,
      decoration: const InputDecoration(
        labelText: 'Branch',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.school),
      ),
      items: _branchOptions.map((branch) => 
        DropdownMenuItem<String>(
          value: branch,
          child: Text(branch),
        ),
      ).toList(),
      validator: (value) => value == null ? 'Select your branch' : null,
      onChanged: (value) {
        if (value != null) {
          setState(() => _branchController.text = value);
        }
      },
    );
  }

  Widget _buildHostelDropdown() {
    return DropdownButtonFormField<String>(
      value: _hostelController.text.isEmpty ? null : _hostelController.text,
      decoration: const InputDecoration(
        labelText: 'Hostel',
        prefixIcon: Icon(Icons.home_work),
        border: OutlineInputBorder(),
      ),
      items: _hostelOptions.map((hostel) => 
        DropdownMenuItem<String>(
          value: hostel,
          child: Text(hostel),
        ),
      ).toList(),
      validator: (value) => value == null ? 'Select your hostel' : null,
      onChanged: (value) {
        if (value != null) {
          setState(() => _hostelController.text = value);
        }
      },
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedYear,
      decoration: const InputDecoration(
        labelText: 'Year',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calendar_today),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('Year 1')),
        DropdownMenuItem(value: 2, child: Text('Year 2')),
        DropdownMenuItem(value: 3, child: Text('Year 3')),
        DropdownMenuItem(value: 4, child: Text('Year 4')),
      ],
      validator: (value) => value == null ? 'Select your year' : null,
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedYear = value);
        }
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<UserRole>(
      value: _selectedRole,
      decoration: const InputDecoration(
        labelText: 'Role',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.people_alt),
      ),
      items: const [
        DropdownMenuItem(
          value: UserRole.student,
          child: Text('Student'),
        ),
        DropdownMenuItem(
          value: UserRole.hostelGuard,
          child: Text('Hostel Guard'),
        ),
        DropdownMenuItem(
          value: UserRole.mainGuard,
          child: Text('Main Gate Guard'),
        ),
        DropdownMenuItem(
          value: UserRole.warden,
          child: Text('Warden'),
        ),
      ],
      validator: (value) => value == null ? 'Select your role' : null,
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedRole = value);
        }
      },
    );
  }

  Future<void> _selectHostels(BuildContext context) async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Hostels'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _hostelOptions.length,
            itemBuilder: (ctx, i) => CheckboxListTile(
              title: Text(_hostelOptions[i]),
              value: _selectedHostels.contains(_hostelOptions[i]),
              onChanged: (v) {
                setState(() {
                  v! 
                    ? _selectedHostels.add(_hostelOptions[i]) 
                    : _selectedHostels.remove(_hostelOptions[i]);
                });
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _selectedHostels),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _selectedHostels = result);
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const FlutterLogo(size: 100),
                  const SizedBox(height: 20),
                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  CustomTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Email',
                    controller: _emailController,
                    prefixIcon: const Icon(Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (!EmailValidator.validate(value!)) return 'Invalid email';
                      if (_selectedRole == UserRole.student && 
                          !value.endsWith('@nitdelhi.ac.in')) {
                        return 'Use college email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildRoleDropdown(),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedRole == UserRole.student 
                        ? _buildStudentFields()
                        : _selectedRole == UserRole.hostelGuard || _selectedRole == UserRole.mainGuard
                            ? _buildGuardFields()
                            : _selectedRole == UserRole.warden
                                ? _buildWardenFields()
                                : const SizedBox(),
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    label: 'Password',
                    controller: _passwordController,
                    isPassword: !_isPasswordVisible,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => 
                          setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    validator: (value) => 
                        value != null && value.length >= 8 ? null : 'Minimum 8 characters',
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    isPassword: !_isConfirmPasswordVisible,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () => setState(
                          () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                    ),
                    validator: (value) => 
                        value == _passwordController.text ? null : 'Passwords don\'t match',
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _signup,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('SIGN UP'),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: 'Login',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
}

