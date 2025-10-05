import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import '../../models/enums.dart';
import '../../models/student.dart';
import '../../models/data_error.dart';
import '../../providers/auth_provider.dart';

class StudentRequestLeaveTab extends StatefulWidget {
  const StudentRequestLeaveTab({Key? key}) : super(key: key);

  @override
  State<StudentRequestLeaveTab> createState() => _StudentRequestLeaveTabState();
}

class _StudentRequestLeaveTabState extends State<StudentRequestLeaveTab> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  LeaveType _leaveType = LeaveType.day;
  DateTime? _exitTime;
  DateTime? _returnTime;
  String? _parentConsentUrl;
  bool _isSubmitting = false;

 @override
void initState() {
  super.initState();
  _initializeStudentData();
}

Future<void> _initializeStudentData() async {
  final provider = context.read<StudentProvider>();
  final auth = context.read<AuthProvider>();
  
  if (provider.student == null && auth.user != null) {
    await provider.initialize(auth.user!.uid);
  }
}

 @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }


  Future<void> _selectDateTime(BuildContext context, bool isExitTime) async {
    final initialDate = _getInitialDate(isExitTime);
    final dateTime = await _showDateTimePicker(context, initialDate);
    if (dateTime == null || !mounted) return;

    setState(() {
      if (isExitTime) {
        _exitTime = dateTime;
        // Reset return time if it's before new exit time
        if (_returnTime != null && !_returnTime!.isAfter(_exitTime!)) {
          _returnTime = null;
        }
      } else {
        _returnTime = dateTime;
      }
    });
  }

  DateTime _getInitialDate(bool isExitTime) => isExitTime
      ? DateTime.now().add(const Duration(minutes: 30)) // Default to 30 mins from now
      : (_exitTime ?? DateTime.now()).add(const Duration(hours: 12)); // Default to 12 hours after exit

  Future<DateTime?> _showDateTimePicker(BuildContext context, DateTime initialDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: _datePickerTheme,
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      builder: _timePickerTheme,
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Widget _datePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: _colorScheme,
      ),
      child: child!,
    );
  }

  Widget _timePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: _colorScheme,
        timePickerTheme: TimePickerThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      child: child!,
    );
  }

  ColorScheme get _colorScheme => ColorScheme.light(
        primary: Colors.blue.shade700,
        onPrimary: Colors.white,
        onSurface: Colors.black,
      );

  Future<void> _attachParentConsent() async {
    try {
      // Simulate file picker and upload
      // In real app, use file_picker and upload to storage
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      
      setState(() => _parentConsentUrl = 'uploaded_consent_${DateTime.now().millisecondsSinceEpoch}');
      _showSnackBar('Parent consent uploaded successfully');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to upload consent: ${e.toString()}');
    }
  }


Future<void> _submitRequest() async {
  if (!_formKey.currentState!.validate()) return;

  // Validate time selections
  if (_exitTime == null || (_leaveType == LeaveType.home && _returnTime == null)) {
    _showSnackBar('Please select all required times');
    return;
  }

  if (_exitTime!.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
    _showSnackBar('Exit time must be at least 5 minutes from now');
    return;
  }

  if (_leaveType == LeaveType.home && 
      _returnTime!.difference(_exitTime!) < const Duration(hours: 12)) {
    _showSnackBar('Home leave must be at least 12 hours');
    return;
  }

  setState(() => _isSubmitting = true);

  try {
    final requestId = await context.read<StudentProvider>().submitLeaveRequest(
      type: _leaveType,
      reason: _reasonController.text,
      exitTime: _exitTime!,
      returnTime: _leaveType == LeaveType.home ? _returnTime : null,
      attachmentUrls: _parentConsentUrl != null ? [_parentConsentUrl!] : null,
    );

    if (mounted) {
      Navigator.pop(context);
      _showSnackBar('Leave request submitted successfully! ID: $requestId');
    }
  } on DataError catch (e) {
    if (mounted) _showSnackBar(e.message);
  } catch (e) {
    if (mounted) _showSnackBar('Failed to submit request: ${e.toString()}');
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  
  }

  // Add this error scaffold builder method
  Widget _buildErrorScreen(String error, {VoidCallback? onRetry}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }


 @override
  Widget build(BuildContext context) {
    final provider = context.watch<StudentProvider>();
    final auth = context.watch<AuthProvider>();

    if (provider.isLoading && provider.student == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null) {
      return _buildErrorScreen(
        provider.error!,
        onRetry: () => provider.initialize(auth.user!.uid),
      );
    }

    final student = provider.student;
    if (student == null) {
      return _buildErrorScreen(
        'Student data not available',
        onRetry: () => provider.initialize(auth.user!.uid),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: const Text('New Leave Request')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : MediaQuery.of(context).size.width * 0.2,
          vertical: 16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudentInfoCard(student),
              const SizedBox(height: 20),
              _buildLeaveTypeSelector(),
              const SizedBox(height: 20),
              _buildDateTimePickerCard(
                title: 'Exit Time',
                value: _exitTime,
                onTap: () => _selectDateTime(context, true),
              ),
              if (_leaveType == LeaveType.home) ...[
                const SizedBox(height: 16),
                _buildDateTimePickerCard(
                  title: 'Return Time',
                  value: _returnTime,
                  onTap: _exitTime == null ? null : () => _selectDateTime(context, false),
                  enabled: _exitTime != null,
                ),
              ],
              const SizedBox(height: 20),
              _buildReasonField(),
              if (_leaveType == LeaveType.home) ...[
                const SizedBox(height: 16),
                _buildParentConsentSection(),
              ],
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }



 Widget _buildStudentInfoCard(Student student) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Student Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Name', student.name),
            _buildInfoRow('Roll No.', student.rollNumber),
            _buildInfoRow('Branch', student.branch),
            _buildInfoRow('Year', student.year.toString()),
            _buildInfoRow('Hostel', student.hostelName),
          ],
        ),
      ),
    );
  }


 Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }



  Widget _buildLeaveTypeSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave Type',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<LeaveType>(
              segments: const [
                ButtonSegment(
                  value: LeaveType.day,
                  label: Text('Day Pass'),
                  icon: Icon(Icons.sunny),
                ),
                ButtonSegment(
                  value: LeaveType.home,
                  label: Text('Home Pass'),
                  icon: Icon(Icons.home),
                ),
              ],
              selected: {_leaveType},
              onSelectionChanged: (newSelection) {
                setState(() {
                  _leaveType = newSelection.first;
                  if (_leaveType == LeaveType.day) _returnTime = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePickerCard({
    required String title,
    required DateTime? value,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: enabled ? _colorScheme.primary : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: enabled ? Colors.black : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value != null
                          ? DateFormat('MMM dd, yyyy - hh:mm a').format(value)
                          : 'Select date & time',
                      style: TextStyle(
                        color: enabled ? Colors.black54 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: enabled ? Colors.grey : Colors.grey.shade300,
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildReasonField() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reason for Leave',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Enter your reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a reason';
                }
                if (value.length < 10) {
                  return 'Reason should be at least 10 characters';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentConsentSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parent Consent',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Home leaves require parent consent document',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _attachParentConsent,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _parentConsentUrl != null 
                        ? Colors.green.shade100 
                        : null,
                    foregroundColor: _parentConsentUrl != null 
                        ? Colors.green.shade800 
                        : null,
                  ),
                ),
                if (_parentConsentUrl != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Text(
                'SUBMIT ${_leaveType == LeaveType.day ? 'DAY' : 'HOME'} REQUEST',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}