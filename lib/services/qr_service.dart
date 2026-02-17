import 'package:uuid/uuid.dart';

class QRService {
  static String generateUniqueQRCode() {
    return 'QR_${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}';
  }

  static String generateUniqueBarcode() {
    return 'BC_${const Uuid().v4().substring(0, 12).toUpperCase()}';
  }
}
