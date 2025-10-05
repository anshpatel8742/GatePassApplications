import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/student_provider.dart';
import '../../models/emergency_contact.dart';
import '../../models/enums.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final contact = context.watch<StudentProvider>().emergencyContact;
    final studentProvider = context.read<StudentProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    try {
                      await studentProvider.refreshAllData();
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
          ),
        ],
      ),
      body: _buildBody(contact),
    );
  }

  Widget _buildBody(EmergencyContact? contact) {
    if (contact == null) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => context.read<StudentProvider>().refreshAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildContactSection(
              title: 'Primary Contacts',
              contacts: [
                _buildContactItem(
                  context,
                  title: 'Parent/Guardian',
                  name: contact.name,
                  phone: contact.primaryPhone,
                  secondaryPhone: contact.secondaryPhone,
                  email: contact.email,
                  isVerified: contact.isVerified,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildContactSection(
              title: 'Hostel Contacts',
              contacts: [
                _buildContactItem(
                  context,
                  title: 'Warden',
                  name: context.watch<StudentProvider>().warden?.name ?? 'Not Available',
                  phone: context.watch<StudentProvider>().warden?.phone ?? 'Not Available',
                  email: context.watch<StudentProvider>().warden?.email,
                ),
                _buildContactItem(
                  context,
                  title: 'Hostel Guard',
                  name: context.watch<StudentProvider>().guard?.name ?? 'Not Available',
                  phone: context.watch<StudentProvider>().guard?.phone ?? 'Not Available',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection({
    required String title,
    required List<Widget> contacts,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
          ),
        ),
        const SizedBox(height: 8),
        ...contacts,
      ],
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required String title,
    required String name,
    required String phone,
    String? secondaryPhone,
    String? email,
    bool isVerified = true,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (!isVerified) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Unverified',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange,
                        ),
                  ),
                ]
              ],
            ),
            const SizedBox(height: 12),
            _buildContactRow(
              icon: Icons.person_outline,
              label: 'Name',
              value: name,
            ),
            _buildContactRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: phone,
              isActionable: true,
              onTap: () => _makePhoneCall(phone),
            ),
            if (secondaryPhone != null)
              _buildContactRow(
                icon: Icons.phone_android_outlined,
                label: 'Alt. Phone',
                value: secondaryPhone,
                isActionable: true,
                onTap: () => _makePhoneCall(secondaryPhone),
              ),
            if (email != null)
              _buildContactRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: email,
                isActionable: true,
                onTap: () => _sendEmail(email),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    bool isActionable = false,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                GestureDetector(
                  onTap: isActionable ? onTap : null,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isActionable
                              ? Theme.of(context).primaryColor
                              : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_emergency_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No emergency contacts found',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<StudentProvider>().refreshAllData(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: phoneNumber,
      );
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _showErrorSnackbar('Cannot make phone call');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to make call: ${e.toString()}');
    }
  }

  Future<void> _sendEmail(String email) async {
    try {
      final Uri launchUri = Uri(
        scheme: 'mailto',
        path: email,
      );
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        _showErrorSnackbar('Cannot send email');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to send email: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}