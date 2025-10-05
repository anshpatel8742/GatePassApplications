import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import '../../models/student.dart';
import '../../services/image_service.dart';
import '../../providers/auth_provider.dart';

class StudentProfileTab extends StatefulWidget {
  const StudentProfileTab({Key? key}) : super(key: key);

  @override
  State<StudentProfileTab> createState() => _StudentProfileTabState();
}

class _StudentProfileTabState extends State<StudentProfileTab> {
  bool _isUpdatingPhoto = false;
  bool _isInitialLoad = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

 Future<void> _loadInitialData() async {
  if (!mounted) return;
  
  setState(() => _isInitialLoad = true);
  try {
    // Get both providers
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    // Check if user is authenticated
    if (authProvider.user == null) {
      throw Exception('User not authenticated');
    }
    
    // Use the Firebase UID from auth provider
    await studentProvider.initialize(authProvider.user!.uid);
  } catch (e) {
    debugPrint('Initial load error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: ${e.toString()}')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isInitialLoad = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final studentProvider = Provider.of<StudentProvider>(context);
    final student = studentProvider.student;

    return Scaffold(
      body: _isInitialLoad
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (student == null)
                          _buildProfileNotFound(context)
                        else
                          Column(
                            children: [
                              _buildProfileHeader(context, student),
                              const SizedBox(height: 16),
                              _buildProfileCompletionBanner(student),
                              const SizedBox(height: 24),
                              _buildPersonalInfoSection(context, student),
                              const SizedBox(height: 24),
                              _buildAcademicInfoSection(context, student),
                              const SizedBox(height: 24),
                              _buildParentInfoSection(context, student),
                              const SizedBox(height: 24),
                              _buildEmergencyContactSection(context, studentProvider),
                              const SizedBox(height: 24),
                              _buildTimetableSection(context, student),
                              const SizedBox(height: 48),
                            ],
                          ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: student != null
          ? FloatingActionButton(
              onPressed: () => _showEditDialog(context, student),
              tooltip: 'Edit Profile',
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }
Future<void> _refreshData() async {
  if (_isRefreshing) return;
  
  setState(() => _isRefreshing = true);
  try {
    // Get both providers properly
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final studentProvider = Provider.of<StudentProvider>(context, listen: false);
    
    // Check if user is authenticated
    if (authProvider.user == null) {
      throw Exception('User not authenticated');
    }
    
    // Use the UID from auth provider
    await studentProvider.initialize(authProvider.user!.uid);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refresh failed: ${e.toString()}')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }
}


  Widget _buildTimetableSection(BuildContext context, Student student) {
    return _buildInfoCard(
      context,
      title: 'Class Timetable',
      icon: Icons.schedule,
      children: [
        if (student.timetableImageUrl != null)
          GestureDetector(
            onTap: () => _showTimetableImage(context, student.timetableImageUrl!),
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(student.timetableImageUrl!),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          )
        else
          const Text('No timetable uploaded yet'),
        if (student.timetableImageUrl != null && student.timetableLastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Last updated: ${_formatDate(student.timetableLastUpdated!)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
      ],
    );
  }

  void _showTimetableImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.network(imageUrl),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }


  Widget _buildProfileNotFound(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Profile Not Available',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We couldn\'t load your profile information. '
              'Please check your connection or contact support.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
           ElevatedButton.icon(
                onPressed: () async {
                  final provider = Provider.of<StudentProvider>(context, listen: false);
                  try {
                    // Directly use the UID from provider
                    final uid = provider.student?.uid;
                    
                    if (uid == null || uid.isEmpty) {
                      throw Exception('No student data available');
                    }
                    
                    await provider.initialize(uid);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile refreshed successfully')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
                    }
                  }
                },
  icon: const Icon(Icons.refresh),
  label: const Text('Try Again'),
),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCompletionBanner(Student student) {
    final completionStatus = _calculateProfileCompletion(student);
    
    if (completionStatus >= 1.0) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              Text(
                'Profile ${(completionStatus * 100).toStringAsFixed(0)}% Complete',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: completionStatus,
            backgroundColor: Colors.orange.shade100,
            color: Colors.orange.shade600,
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Text(
            _getCompletionMessage(student),
            style: TextStyle(
              fontSize: 12,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateProfileCompletion(Student student) {
    int completedFields = 0;
    const totalFields = 7; // Adjust based on your fields
    
    if (student.phone.isNotEmpty) completedFields++;
    if (student.email.isNotEmpty) completedFields++;
    if (student.parentPhone.isNotEmpty) completedFields++;
    if (student.branch.isNotEmpty && student.branch != 'UNASSIGNED') completedFields++;
    if (student.year != 0) completedFields++;
    if (student.hostelName.isNotEmpty && student.hostelName != 'UNASSIGNED') completedFields++;
    if (student.photoUrl != null && student.photoUrl!.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }

  String _getCompletionMessage(Student student) {
    if (student.branch.isEmpty || student.branch == 'UNASSIGNED') return 'Your academic details need completion';
    if (student.hostelName.isEmpty || student.hostelName == 'UNASSIGNED') return 'Hostel assignment pending';
    if (student.parentPhone.isEmpty) return 'Parent contact information required';
    if (student.phone.isEmpty) return 'Your phone number is required';
    if (student.photoUrl == null || student.photoUrl!.isEmpty) return 'Profile photo required';
    return 'Please complete all profile sections';
  }

  Widget _buildProfileHeader(BuildContext context, Student student) {
    final theme = Theme.of(context);
    return Column(
      children: [
        GestureDetector(
          onTap: () => _updateProfilePhoto(context, student),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _isUpdatingPhoto
                      ? const Center(child: CircularProgressIndicator())
                      : student.photoUrl != null && student.photoUrl!.isNotEmpty
                          ? Image.network(
                              student.photoUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                return progress == null
                                    ? child
                                    : Center(child: CircularProgressIndicator(
                                        value: progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded / 
                                              progress.expectedTotalBytes!
                                            : null,
                                      ));
                              },
                              errorBuilder: (_, __, ___) => _buildDefaultAvatar(theme),
                            )
                          : _buildDefaultAvatar(theme),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          student.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          student.rollNumber,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

Future<void> _updateProfilePhoto(BuildContext context, Student student) async {
  if (_isUpdatingPhoto) return;

  setState(() => _isUpdatingPhoto = true);
  
  try {
    final imageUrl = await ImageService().pickAndUploadImage(
      context: context,
      uploadPath: 'students/${student.rollNumber}/profile',
    );

    if (imageUrl != null && mounted) {
      // Remove student.uid parameter - just pass imageUrl
      await Provider.of<StudentProvider>(context, listen: false)
          .uploadProfilePhoto(imageUrl);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: ${e.toString()}')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isUpdatingPhoto = false);
    }
  }
}
  Widget _buildDefaultAvatar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primary.withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.person,
          size: 60,
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context, Student student) {
    return _buildInfoCard(
      context,
      title: 'Personal Information',
      icon: Icons.person,
      children: [
        _buildInfoTile(Icons.phone, 'Phone', 
            student.phone.isNotEmpty ? student.phone : 'Not provided'),
        _buildInfoTile(Icons.email, 'Email', student.email),
      ],
    );
  }

  Widget _buildAcademicInfoSection(BuildContext context, Student student) {
    return _buildInfoCard(
      context,
      title: 'Academic Information',
      icon: Icons.school,
      children: [
        _buildInfoTile(Icons.engineering, 'Branch', 
            student.branch.isNotEmpty ? student.branch : 'Not assigned'),
        _buildInfoTile(Icons.calendar_today, 'Year', 
            student.year != 0 ? 'Year ${student.year}' : 'Not assigned'),
        _buildInfoTile(Icons.location_city, 'Hostel', 
            student.hostelName.isNotEmpty ? student.hostelName : 'Not assigned'),
        if (student.roomNumber != null)
          _buildInfoTile(Icons.door_sliding, 'Room', student.roomNumber!),
        if (student.floorNumber != null)
          _buildInfoTile(Icons.stairs, 'Floor', student.floorNumber.toString()),
      ],
    );
  }

  Widget _buildParentInfoSection(BuildContext context, Student student) {
    return _buildInfoCard(
      context,
      title: 'Parent/Guardian',
      icon: Icons.family_restroom,
      children: [
        _buildInfoTile(Icons.phone, 'Contact', 
            student.parentPhone.isNotEmpty ? student.parentPhone : 'Not provided'),
      ],
    );
  }

  Widget _buildEmergencyContactSection(BuildContext context, StudentProvider provider) {
    final contact = provider.emergencyContact;
    
    return _buildInfoCard(
      context,
      title: 'Emergency Contacts',
      icon: Icons.emergency,
      children: [
        if (contact != null) ...[
          _buildInfoTile(Icons.person, 'Name', contact.name),
          _buildInfoTile(Icons.phone, 'Phone', contact.primaryPhone),
          if (contact.relationship.isNotEmpty)
            _buildInfoTile(Icons.people, 'Relationship', contact.relationship),
        ] else ...[
          _buildInfoTile(Icons.info, 'No emergency contact', 
              'Please set up in profile settings'),
        ],
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
 void _showEditDialog(BuildContext context, Student student) {
    final formKey = GlobalKey<FormState>();
    
    // Local state for form fields
    String name = student.name;
    String phone = student.phone;
    String parentPhone = student.parentPhone;
    String hostelName = student.hostelName;
    String? roomNumber = student.roomNumber;
    int? floorNumber = student.floorNumber;
    String? emergencyContact = student.emergencyContact;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Update Profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              // Name Field
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (value) => name = value,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 3) return 'Name too short';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Phone Field
              TextFormField(
                initialValue: phone,
                decoration: const InputDecoration(
                  labelText: 'Your Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => phone = value,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 10) return 'Invalid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Parent Phone Field
              TextFormField(
                initialValue: parentPhone,
                decoration: const InputDecoration(
                  labelText: 'Parent/Guardian Phone',
                  prefixIcon: Icon(Icons.people),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => parentPhone = value,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  if (value.length < 10) return 'Invalid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Hostel Info Section
              Text(
                'Hostel Information',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              
              TextFormField(
                initialValue: hostelName,
                decoration: const InputDecoration(
                  labelText: 'Hostel Name',
                  prefixIcon: Icon(Icons.home),
                ),
                onChanged: (value) => hostelName = value,
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: roomNumber,
                      decoration: const InputDecoration(
                        labelText: 'Room Number',
                        prefixIcon: Icon(Icons.door_back_door),
                      ),
                      onChanged: (value) => roomNumber = value,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: floorNumber?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Floor',
                        prefixIcon: Icon(Icons.stairs),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          floorNumber = int.tryParse(value);
                        } else {
                          floorNumber = null;
                        }
                      },
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final floor = int.tryParse(value);
                          if (floor == null || floor <= 0) {
                            return 'Invalid floor';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Emergency Contact
              TextFormField(
                initialValue: emergencyContact,
                decoration: const InputDecoration(
                  labelText: 'Emergency Contact Name',
                  prefixIcon: Icon(Icons.emergency),
                ),
                onChanged: (value) => emergencyContact = value,
              ),
              const SizedBox(height: 24),
              
              // Save Button with loading state
              Consumer<StudentProvider>(
                builder: (context, provider, _) {
                  return provider.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            try {
                              await provider.updateProfile(
                                name: name,
                                phone: phone,
                                parentPhone: parentPhone,
                                hostelName: hostelName,
                                roomNumber: roomNumber,
                                floorNumber: floorNumber,
                                emergencyContact: emergencyContact,
                              );
                              
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated successfully'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Update failed: ${e.toString()}'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Save Changes'),
                        );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}