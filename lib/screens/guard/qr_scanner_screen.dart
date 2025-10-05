import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../providers/trip_provider.dart';
import '../../models/enums.dart';
import '../../models/trip.dart';
import '../../services/qr_service.dart';
import '../../providers/guard_provider.dart';

class GuardScanScreen extends StatefulWidget {
  final GateEventType expectedEventType;
  final String scannerTitle;

  const GuardScanScreen({
    super.key,
    required this.expectedEventType,
    required this.scannerTitle,
  });

  @override
  State<GuardScanScreen> createState() => _GuardScanScreenState();
}

class _GuardScanScreenState extends State<GuardScanScreen> {
  late MobileScannerController _cameraController;
  bool _isProcessing = false;
  String? _lastError;
  bool _torchEnabled = false;
  bool _shouldScan = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: _torchEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scannerTitle),
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: Theme.of(context).colorScheme.onBackground,
            ),
            onPressed: _toggleTorch,
            tooltip: 'Toggle flash',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showScanInstructions,
            tooltip: 'Scan instructions',
          ),
        ],
      ),
      body: _buildScannerBody(),
    );
  }

  Widget _buildScannerBody() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: _handleDetection,
        ),
        _buildScanOverlay(),
        _buildStatusFooter(),
        if (!_shouldScan) _buildPauseOverlay(),
      ],
    );
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {

     final guardProvider = Provider.of<GuardProvider>(context, listen: false);
  
  // Add this check
  // if (!guardProvider.isInitialized) {
  //   throw ScanException("Guard session not initialized. Please wait or restart the app.");
  // }
    if (_isProcessing || !_shouldScan) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() {
      _isProcessing = true;
      _lastError = null;
      _shouldScan = false;
    });

    try {
      final qrData = barcode!.rawValue!;
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      
   

      // Then process the scan
      final result = await tripProvider.processGateScan(
        qrData: qrData,
        attemptedEventType: widget.expectedEventType,
      );

      if (!result.isSuccess) {
        throw result.error ?? 'Scan processing failed';
      }

      await _showSuccessDialog(result.trip!);
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _shouldScan = true;
        });
      }
    }
  }

  void _handleError(dynamic error) {
    String errorMessage = 'An error occurrsed during scanning';

    if (error is WrongSequenceException) {
      errorMessage = 'Invalid sequence. Next scan should be at ${error.expectedEvent?.displayName}';
    } else if (error is InvalidQRException || error is FormatException) {
      errorMessage = 'Invalid QR code format. Please try again.';
    } else if (error is FirebaseException) {
      errorMessage = 'Network error: ${error.message ?? 'Unable to connect to server'}';
    } else if (error is String) {
      errorMessage = error;
    } else if (error is ScanException) {
      errorMessage = error.message;
    }

    _showError(errorMessage);
    debugPrint('QR Scan Error: ${error.toString()}');
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Processing scan...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 250,
        decoration: BoxDecoration(
          border: Border.all(
            color: _isProcessing ? Colors.amber : Colors.white.withOpacity(0.7),
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildStatusFooter() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isProcessing)
              const Column(
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 8),
                  Text('Validating scan...', style: TextStyle(color: Colors.white)),
                ],
              )
            else if (_lastError != null)
              Text(
                _lastError!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              'Scan for: ${widget.expectedEventType.displayName.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog(Trip trip) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Scan Successful', style: TextStyle(color: Colors.green)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Student Name:', trip.studentName),
              _buildInfoRow('Roll Number:', trip.studentRoll),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Action:',
                widget.expectedEventType.displayName,
                isBold: true,
              ),
              if (trip.nextExpectedEvent != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Next Step:',
                  trip.nextExpectedEvent!.displayName,
                  color: Colors.green,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleTorch() {
    setState(() => _torchEnabled = !_torchEnabled);
    _cameraController.toggleTorch();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showScanInstructions() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Scanning Instructions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstructionStep('1', 'Position QR code within the frame'),
              _buildInstructionStep('2', 'Ensure good lighting conditions'),
              _buildInstructionStep('3', 'Hold steady until scan completes'),
              _buildInstructionStep('4', 'Verify student identity before proceeding'),
              const SizedBox(height: 16),
              Text(
                'Note: QR codes are valid only for the current trip',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}

class ScanException implements Exception {
  final String message;
  ScanException(this.message);
  
  @override
  String toString() => 'ScanException: $message';
}

class InvalidQRException implements Exception {
  @override
  String toString() => 'Invalid QR code format';
}

class WrongSequenceException implements Exception {
  final GateEventType? expectedEvent;
  WrongSequenceException(this.expectedEvent);
  
  @override
  String toString() => 'Wrong scan sequence. Expected: ${expectedEvent?.displayName}';
}