import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class QRService {
  static String buildUserQrPayload({
    required String userId,
    required String userName,
    required String email,
    required DateTime lastDate,
    required DateTime createdAt,
  }) {
    final normalized = <String, String>{
      'userId': userId.trim().toLowerCase(),
      'userName': userName.trim().toLowerCase(),
      'email': email.trim().toLowerCase(),
      'lastDate': lastDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };

    final material = jsonEncode(normalized);
    final digest = sha256.convert(utf8.encode(material)).toString();
    return 'QR1:$digest';
  }

  static String generateUniqueBarcode() {
    return 'BC_${const Uuid().v4().substring(0, 12).toUpperCase()}';
  }
}
