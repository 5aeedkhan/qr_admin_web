import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/qr_service.dart';
import '../theme/app_theme.dart';

class UserDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends ConsumerState<UserDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _formScrollController = ScrollController();

  UserModel? _user;
  bool _isLoading = true;

  final _userNameController = TextEditingController();
  final _userIdController = TextEditingController();
  final _statusController = TextEditingController();
  final _lastPaymentController = TextEditingController();
  final _remainingDaysController = TextEditingController();
  final _lastDateController = TextEditingController();

  bool get _isNewUser => widget.userId == 'new';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    if (_isNewUser) {
      _initializeNewUser();
    } else {
      _loadUser();
    }
  }

  void _initializeNewUser() {
    final now = DateTime.now();
    final newId = QRService.generateUniqueQRCode();
    final newQr = newId;
    final newBarcode = QRService.generateUniqueBarcode();

    _user = UserModel(
      id: newId,
      userName: '',
      userId: '',
      lastPayment: now,
      status: 'active',
      remainingDays: 30,
      lastDate: now,
      qrCode: newQr,
      barcode: newBarcode,
      createdAt: now,
    );

    _userNameController.text = '';
    _userIdController.text = '';
    _statusController.text = 'active';
    _lastPaymentController.text = DateFormat('yyyy-MM-dd').format(now);
    _remainingDaysController.text = '30';
    _lastDateController.text = DateFormat('yyyy-MM-dd').format(now);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadUser() async {
    final user = await FirebaseService.getUserById(widget.userId);

    if (mounted) {
      setState(() {
        _user = user;
        if (user != null) {
          _userNameController.text = user.userName;
          _userIdController.text = user.userId;
          _statusController.text = user.status;
          _lastPaymentController.text = DateFormat(
            'yyyy-MM-dd',
          ).format(user.lastPayment);
          _remainingDaysController.text = user.remainingDays.toString();
          _lastDateController.text = DateFormat(
            'yyyy-MM-dd',
          ).format(user.lastDate);
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUser() async {
    if (_user == null) return;

    final updatedUser = _user!.copyWith(
      userName: _userNameController.text,
      userId: _userIdController.text,
      status: _statusController.text,
      lastPayment:
          DateTime.tryParse(_lastPaymentController.text) ?? _user!.lastPayment,
      remainingDays:
          int.tryParse(_remainingDaysController.text) ?? _user!.remainingDays,
      lastDate: DateTime.tryParse(_lastDateController.text) ?? _user!.lastDate,
    );

    try {
      if (_isNewUser) {
        await FirebaseService.createUser(updatedUser);
      } else {
        await FirebaseService.updateUser(updatedUser);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isNewUser
                  ? 'User created successfully'
                  : 'User updated successfully',
            ),
            backgroundColor: const Color(0xFF00FF88),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        if (_isNewUser) {
          context.go('/user/${updatedUser.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser() async {
    if (_user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete User',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this user? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6C63FF)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B9D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseService.deleteUser(_user!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User deleted successfully'),
              backgroundColor: const Color(0xFF00FF88),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _userIdController.dispose();
    _statusController.dispose();
    _lastPaymentController.dispose();
    _remainingDaysController.dispose();
    _lastDateController.dispose();
    _formScrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Details')),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6C63FF),
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('User Details')),
        body: const Center(
          child: Text(
            'User not found',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNewUser ? 'Add New User' : 'User Details',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        actions: [
          if (!_isNewUser)
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: _deleteUser,
              tooltip: 'Delete User',
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F1E), Color(0xFF1A1A2E), Color(0xFF2A2A3E)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _CodeCard(
                      title: 'QR Code',
                      qrCode: _user!.qrCode,
                      barcode: null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CodeCard(
                      title: 'Barcode',
                      qrCode: null,
                      barcode: _user!.barcode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Scrollbar(
                  controller: _formScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _formScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'User Information',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _userNameController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'User Name',
                                  prefixIcon: Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _userIdController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'User ID',
                                  prefixIcon: Icon(
                                    Icons.badge_rounded,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _statusController.text,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  prefixIcon: Icon(
                                    Icons.verified_user_rounded,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                                dropdownColor: const Color(0xFF1A1A2E),
                                style: const TextStyle(color: Colors.white),
                                items: ['active', 'inactive'].map((status) {
                                  return DropdownMenuItem(
                                    value: status,
                                    child: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _statusController.text = value!;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _lastPaymentController,
                                keyboardType: TextInputType.datetime,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Last Payment (YYYY-MM-DD)',
                                  prefixIcon: Icon(
                                    Icons.payments_rounded,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _remainingDaysController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Remaining Days',
                                  prefixIcon: Icon(
                                    Icons.schedule_rounded,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _lastDateController,
                                keyboardType: TextInputType.datetime,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Last Date (YYYY-MM-DD)',
                                  prefixIcon: Icon(
                                    Icons.calendar_today_rounded,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _saveUser,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF6C63FF,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: const Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => context.pop(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withOpacity(0.1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: const Text(
                                        'Back',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String title;
  final String? qrCode;
  final String? barcode;

  const _CodeCard({
    required this.title,
    required this.qrCode,
    required this.barcode,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              if (qrCode != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: qrCode!,
                    version: QrVersions.auto,
                    size: 150,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.line_weight_rounded,
                    size: 80,
                    color: Colors.black54,
                  ),
                ),
              const SizedBox(height: 16),
              SelectableText(
                qrCode ?? barcode ?? '',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
