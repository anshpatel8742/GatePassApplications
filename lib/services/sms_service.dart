// import 'dart:math';
// import 'package:http/http.dart' as http;

// class SmsService {
//   static const String _accountSid = 'YOUR_TWILIO_SID';
//   static const String _authToken = 'YOUR_TWILIO_TOKEN';
//   static const String _fromNumber = '+1234567890';

//   static Future<bool> sendVerificationRequest({
//     required String parentPhone,
//     required String studentName,
//     required String verificationCode,
//   }) async {
//     final message = 
//       'Verify $studentName\'s hostel leave. Code: $verificationCode\n'
//       'Do not share this code.';

//     try {
//       final response = await http.post(
//         Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json'),
//         headers: {
//           'Authorization': 'Basic ' + 
//             base64Encode(utf8.encode('$_accountSid:$_authToken')),
//         },
//         body: {
//           'From': _fromNumber,
//           'To': parentPhone,
//           'Body': message,
//         },
//       );
//       return response.statusCode == 201;
//     } catch (e) {
//       return false;
//     }
//   }
// }