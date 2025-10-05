import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Add this import
import '../services/qr_service.dart'; // This imports QrService (lowercase r)

class QrCodeDialog extends StatelessWidget {
  final String qrData;

  const QrCodeDialog({Key? key, required this.qrData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your Gate Pass QR Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView( // Using qr_flutter package directly
            data: qrData,
            version: QrVersions.auto,
            size: 200.0,
          ),
          const SizedBox(height: 16),
          const Text('Show this at hostel and main gates'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}