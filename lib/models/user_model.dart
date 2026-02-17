class UserModel {
  final String id;
  final String userName;
  final String userId;
  final DateTime lastPayment;
  final String status;
  final int remainingDays;
  final DateTime lastDate;
  final String qrCode;
  final String barcode;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.userName,
    required this.userId,
    required this.lastPayment,
    required this.status,
    required this.remainingDays,
    required this.lastDate,
    required this.qrCode,
    required this.barcode,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      userName: map['userName'] ?? '',
      userId: map['userId'] ?? '',
      lastPayment: DateTime.parse(map['lastPayment'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'inactive',
      remainingDays: map['remainingDays'] ?? 0,
      lastDate: DateTime.parse(map['lastDate'] ?? DateTime.now().toIso8601String()),
      qrCode: map['qrCode'] ?? '',
      barcode: map['barcode'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userName': userName,
      'userId': userId,
      'lastPayment': lastPayment.toIso8601String(),
      'status': status,
      'remainingDays': remainingDays,
      'lastDate': lastDate.toIso8601String(),
      'qrCode': qrCode,
      'barcode': barcode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? userName,
    String? userId,
    DateTime? lastPayment,
    String? status,
    int? remainingDays,
    DateTime? lastDate,
    String? qrCode,
    String? barcode,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userId: userId ?? this.userId,
      lastPayment: lastPayment ?? this.lastPayment,
      status: status ?? this.status,
      remainingDays: remainingDays ?? this.remainingDays,
      lastDate: lastDate ?? this.lastDate,
      qrCode: qrCode ?? this.qrCode,
      barcode: barcode ?? this.barcode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
