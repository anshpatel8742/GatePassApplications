import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/student_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:intl/intl.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({Key? key}) : super(key: key);

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  bool _isUploading = false;
  bool _isDeleting = false;
  String? _uploadError;
  UploadTask? _uploadTask;

  @override
  void dispose() {
    _uploadTask?.cancel();
    super.dispose();
  }

  Future<void> _uploadTimetable() async {
    final picker = ImagePicker();
    final studentProvider = context.read<StudentProvider>();
    final authProvider = context.read<AuthProvider>();

    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (authProvider.user == null) throw Exception('User not authenticated');

      // Validate image
      final file = File(pickedFile.path);
      final size = await file.length();
      if (size > 5 * 1024 * 1024) { // 5MB limit
        throw Exception('Image too large (max 5MB)');
      }

      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      // Upload with progress tracking
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('timetables/${authProvider.user!.uid}/$timestamp.jpg');

      _uploadTask = storageRef.putFile(file);
      final snapshot = await _uploadTask!;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore
      await studentProvider.uploadTimetable(downloadUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Timetable upload error: $e');
      if (mounted) {
        setState(() => _uploadError = 'Upload failed: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _uploadTimetable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadTask = null;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Timetable'),
        content: const Text('Are you sure you want to remove your timetable?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTimetable();
    }
  }

  Future<void> _deleteTimetable() async {
    final studentProvider = context.read<StudentProvider>();
    
    try {
      if (studentProvider.student?.timetableImageUrl == null) return;

      setState(() => _isDeleting = true);

      // Delete from storage
      final url = studentProvider.student!.timetableImageUrl!;
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();

      // Update Firestore
      await studentProvider.deleteTimetable();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable removed successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Timetable delete error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _deleteTimetable,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final timetableImageUrl = studentProvider.student?.timetableImageUrl;
    final lastUpdated = studentProvider.student?.timetableLastUpdated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timetable'),
        actions: [
          if (timetableImageUrl != null)
            IconButton(
              icon: _isDeleting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _confirmDelete,
              tooltip: 'Remove Timetable',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _uploadTimetable,
        child: _isUploading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.upload),
      ),
      body: _buildBody(timetableImageUrl, lastUpdated),
    );
  }

  Widget _buildBody(String? timetableImageUrl, DateTime? lastUpdated) {
    if (_isUploading && _uploadTask != null) {
      return _buildUploadProgress();
    }

    if (_uploadError != null && timetableImageUrl == null) {
      return _buildErrorState();
    }

    if (timetableImageUrl == null) {
      return _buildEmptyState();
    }

    return _buildTimetableImage(timetableImageUrl, lastUpdated);
  }

  Widget _buildUploadProgress() {
    return StreamBuilder<TaskSnapshot>(
      stream: _uploadTask?.snapshotEvents,
      builder: (context, snapshot) {
        final progress = snapshot.data?.bytesTransferred ?? 0;
        final total = snapshot.data?.totalBytes ?? 1;
        final percentage = (progress / total * 100).round();

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(value: progress / total),
              const SizedBox(height: 16),
              Text('Uploading: $percentage%'),
              const SizedBox(height: 8),
              Text(
                '${(progress / 1024).round()} KB of ${(total / 1024).round()} KB',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _uploadError ?? 'An error occurred',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _uploadTimetable,
            child: const Text('Try Again'),
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
          Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No timetable uploaded',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your class schedule to view it here',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTimetableImage(String imageUrl, DateTime? lastUpdated) {
    return Column(
      children: [
        if (lastUpdated != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Last updated: ${DateFormat('MMM dd, yyyy - hh:mm a').format(lastUpdated)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        Expanded(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 3.0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => _buildErrorState(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}