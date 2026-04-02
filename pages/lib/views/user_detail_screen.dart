import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/qr_service.dart';

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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newQr = QRService.buildUserQrPayload(
      userId: '',
      userName: '',
      email: '',
      lastDate: now,
      createdAt: now,
    );
    final newBarcode = QRService.generateUniqueBarcode();

    _user = UserModel(
      id: newId,
      userName: '',
      userId: '',
      email: '',
      authUid: '',
      lastPayment: now,
      status: 'active',
      remainingDays: 0, // Will be calculated based on lastDate
      lastDate: now,
      qrCode: newQr,
      barcode: newBarcode,
      createdAt: now,
    );

    _userNameController.text = '';
    _userIdController.text = '';
    _emailController.text = '';
    _passwordController.text = '';
    _statusController.text = 'active';
    _lastPaymentController.text = DateFormat('yyyy-MM-dd').format(now);
    _remainingDaysController.text =
        '0'; // Start with 0, will update when lastDate changes
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
          _emailController.text = user.email;
          _passwordController.text = '';
          _statusController.text = user.status;
          _lastPaymentController.text = DateFormat(
            'yyyy-MM-dd',
          ).format(user.lastPayment);
          _lastDateController.text = DateFormat(
            'yyyy-MM-dd',
          ).format(user.lastDate);

          // Calculate remaining days based on current date vs last date
          final now = DateTime.now();
          final difference = user.lastDate.difference(now).inDays;
          _remainingDaysController.text = difference > 0
              ? difference.toString()
              : '0';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUser() async {
    if (_user == null) return;

    if (_isNewUser) {
      if (_emailController.text.trim().isEmpty ||
          _passwordController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Email and password are required for new users',
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }
      print(
        '🔐 DEBUG: Creating new user with email: ${_emailController.text.trim()}',
      );
    }

    // Check if lastDate has changed
    final newLastDate =
        DateTime.tryParse(_lastDateController.text) ?? _user!.lastDate;
    final lastDateChanged = newLastDate != _user!.lastDate;

    final identityChanged =
        _userNameController.text != _user!.userName ||
        _userIdController.text != _user!.userId ||
        _emailController.text.trim() != _user!.email;

    // Generate deterministic QR payload (will change if lastDate/identity changes)
    String newQrCode = _user!.qrCode;
    if (lastDateChanged || identityChanged || _isNewUser) {
      newQrCode = QRService.buildUserQrPayload(
        userId: _userIdController.text,
        userName: _userNameController.text,
        email: _emailController.text.trim(),
        lastDate: newLastDate,
        createdAt: _user!.createdAt,
      );
    }

    // Calculate remaining days based on current date vs last date
    final now = DateTime.now();
    final calculatedRemainingDays = newLastDate.difference(now).inDays > 0
        ? newLastDate.difference(now).inDays
        : 0;

    UserModel updatedUser = _user!.copyWith(
      userName: _userNameController.text,
      userId: _userIdController.text,
      email: _emailController.text.trim(),
      status: _statusController.text,
      lastPayment:
          DateTime.tryParse(_lastPaymentController.text) ?? _user!.lastPayment,
      remainingDays: calculatedRemainingDays,
      lastDate: newLastDate,
      qrCode: newQrCode,
    );

    try {
      if (_isNewUser) {
        print('🔐 DEBUG: Creating auth user for email: ${updatedUser.email}');
        print('🔐 DEBUG: Password length: ${_passwordController.text.length}');

        try {
          final credential =
              await FirebaseService.createAuthUserWithoutAffectingCurrentSession(
                email: updatedUser.email,
                password: _passwordController.text,
              );

          print(
            '🔐 DEBUG: Auth result - UID: ${credential.user?.uid}, Error: ${credential.user?.uid == null ? "Failed" : "Success"}',
          );

          if (credential.user?.uid != null) {
            updatedUser = updatedUser.copyWith(authUid: credential.user!.uid);
            await FirebaseService.createUser(updatedUser);
            print('✅ DEBUG: User saved to Firestore successfully');
          } else {
            throw Exception('Firebase Auth returned null user');
          }
        } catch (authError) {
          print('❌ DEBUG: Auth creation failed: $authError');
          // Still save to Firestore even if auth fails
          await FirebaseService.createUser(updatedUser);
          print('⚠️ DEBUG: User saved to Firestore without auth');
        }
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
        context.go('/dashboard');
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
          context.go('/dashboard');
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
    _emailController.dispose();
    _passwordController.dispose();
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
              _CodeCard(
                title: 'QR Code',
                qrCode: _user!.qrCode,
                barcode: null,
                showCodeText: false,
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
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
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
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(
                                    Icons.email_rounded,
                                    color: Color(0xFF6C63FF),
                                  ),
                                ),
                              ),
                              if (_isNewUser) ...[
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icon(
                                      Icons.lock_rounded,
                                      color: Color(0xFF6C63FF),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _statusController.text,
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
                                onChanged: (value) {
                                  // When last date changes, calculate remaining days automatically
                                  final selectedDate = DateTime.tryParse(value);
                                  if (selectedDate != null) {
                                    final now = DateTime.now();
                                    final difference = selectedDate
                                        .difference(now)
                                        .inDays;
                                    _remainingDaysController.text =
                                        difference > 0
                                        ? difference.toString()
                                        : '0';
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _remainingDaysController,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                                style: const TextStyle(color: Colors.white70),
                                decoration: const InputDecoration(
                                  labelText: 'Remaining Days (Auto-calculated)',
                                  prefixIcon: Icon(
                                    Icons.schedule_rounded,
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
                                      onPressed: () => context.go('/dashboard'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.1),
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
  final bool showCodeText;

  const _CodeCard({
    required this.title,
    required this.qrCode,
    required this.barcode,
    required this.showCodeText,
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
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
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
              if (showCodeText) ...[
                const SizedBox(height: 16),
                SelectableText(
                  qrCode ?? barcode ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
