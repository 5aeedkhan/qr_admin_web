import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Authentication
  static Future<UserCredential?> signInAdmin(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      print('Error signing in admin: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential?> signInUser(
    String email,
    String password,
  ) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Error signing in user: $e');
      return null;
    }
  }

  // User Management
  static Future<List<UserModel>> getAllUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('users').get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  static Future<UserModel?> getUserById(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  static Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toMap());
      print('✅ Created user in Firestore: ${user.userName} (${user.email})');
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  static Future<UserCredential> createAuthUserWithoutAffectingCurrentSession({
    required String email,
    required String password,
  }) async {
    print('🔐 DEBUG: Starting auth creation for: $email');
    
    final secondaryAppName = 'secondary-auth';
    FirebaseApp? secondaryApp;
    try {
      try {
        secondaryApp = Firebase.app(secondaryAppName);
        print('🔐 DEBUG: Using existing secondary app');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: secondaryAppName,
          options: Firebase.app().options,
        );
        print('🔐 DEBUG: Created new secondary app');
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final result = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('🔐 DEBUG: Auth user created with UID: ${result.user?.uid}');
      return result;
    } catch (e) {
      print('❌ DEBUG: Auth creation error: $e');
      print('❌ DEBUG: Error type: ${e.runtimeType}');
      rethrow;
    } finally {
      try {
        if (secondaryApp != null) {
          await secondaryApp.delete();
          print('🔐 DEBUG: Secondary app deleted');
        }
      } catch (e) {
        print('⚠️ DEBUG: Error deleting secondary app: $e');
      }
    }
  }

  static Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
    } catch (e) {
      print('Error deleting user: $e');
      rethrow;
    }
  }

  static Future<UserModel?> getUserByQRCode(String qrCode) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(
          snapshot.docs.first.data() as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      print('Error getting user by QR code: $e');
      return null;
    }
  }

  static Future<UserModel?> getUserByAuthUid(String authUid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('authUid', isEqualTo: authUid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user by auth uid: $e');
      return null;
    }
  }

  static Future<UserModel?> getUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting user by email: $e');
      return null;
    }
  }

  // Check if admin user exists
  static Future<bool> isAdminUser(String email) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('admins')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking admin user: $e');
      return false;
    }
  }
}
