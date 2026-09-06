import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/di/providers.dart';
import '../../../core/utils/permission.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, locked }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? username;
  final String? email;
  final UserRole? role;
  final String? token;
  final DateTime? subscriptionExpiry;
  final String? error;
  final int graceDaysLeft;
  final bool biometricAvailable;
  final bool offline;
  const AuthState({this.status = AuthStatus.uninitialized, this.userId, this.username, this.email, this.role, this.token, this.subscriptionExpiry, this.error, this.graceDaysLeft = 7, this.biometricAvailable = false, this.offline = false});

  AuthState copyWith({AuthStatus? status, String? userId, String? username, String? email, UserRole? role, String? token, DateTime? subscriptionExpiry, String? error, int? graceDaysLeft, bool? biometricAvailable, bool? offline}) => AuthState(
    status: status ?? this.status, userId: userId ?? this.userId, username: username ?? this.username,
    email: email ?? this.email, role: role ?? this.role, token: token ?? this.token,
    subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
    error: error, graceDaysLeft: graceDaysLeft ?? this.graceDaysLeft,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    offline: offline ?? this.offline);
}

class AuthController extends StateNotifier<AuthState> {
  final FlutterSecureStorage _secureStorage;

  AuthController(this._secureStorage) : super(const AuthState()) {
    _init();
  }

  fb.FirebaseAuth get _auth => fb.FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  Future<void> _init() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _restoreUser(user);
    } else {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token != null) {
        state = AuthState(status: AuthStatus.authenticated, token: token, offline: true);
        return;
      }
      state = const AuthState(status: AuthStatus.unauthenticated);
    }

    _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _restoreUser(user);
      } else {
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    });
  }

  Future<void> _restoreUser(fb.User user) async {
    final shopData = await _getShop(user.uid);

    await _secureStorage.write(key: 'jwt_token', value: user.uid);

    state = AuthState(
      status: AuthStatus.authenticated,
      userId: shopData?['shopId']?.toString() ?? user.uid,
      username: shopData?['ownerName'] as String? ?? user.displayName ?? user.email ?? '',
      email: user.email,
      role: shopData?['role'] == 'super_admin' ? UserRole.superAdmin : UserRole.owner,
      token: user.uid,
      biometricAvailable: await _secureStorage.read(key: 'biometric_enabled') == 'true',
    );
  }

  Future<Map<String, dynamic>?> _getShop(String ownerId) async {
    try {
      final snap = await _firestore
          .collection('shops')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final d = snap.docs.first.data();
      return {...d, 'shopId': snap.docs.first.id};
    } catch (_) {
      return null;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (cred.user == null) return 'Invalid credentials';
      await _restoreUser(cred.user!);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      final msg = _friendlyError(e);
      state = state.copyWith(error: msg);
      return msg;
    } catch (e) {
      state = state.copyWith(error: 'Connection failed: $e');
      return 'Connection failed';
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String shopName,
    required String ownerName,
    String? phone,
    String? address,
    String? gstin,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user == null) return 'Registration failed';

      await user.updateDisplayName(ownerName);

      final shopRef = await _firestore.collection('shops').add({
        'ownerId': user.uid,
        'shopName': shopName,
        'ownerName': ownerName,
        'phone': phone ?? '',
        'address': address ?? '',
        'gstin': gstin ?? '',
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('subscriptions').add({
        'shopId': shopRef.id,
        'plan': 'trial',
        'status': 'active',
        'expiryDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        'gracePeriodEnd': Timestamp.fromDate(DateTime.now().add(const Duration(days: 37))),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _restoreUser(user);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await _secureStorage.deleteAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on fb.FirebaseAuthException catch (e) {
      return _friendlyError(e);
    } catch (_) {
      return 'Failed to send reset email';
    }
  }

  Future<void> validateSubscription() async {
    try {
      if (state.userId == null) return;
      final snap = await _firestore
          .collection('subscriptions')
          .where('shopId', isEqualTo: state.userId)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return;
      final sub = snap.docs.first.data();
      final expiry = (sub['expiryDate'] as Timestamp?)?.toDate();
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        final grace = (sub['gracePeriodEnd'] as Timestamp?)?.toDate();
        if (grace != null && DateTime.now().isAfter(grace)) {
          state = state.copyWith(status: AuthStatus.locked, error: 'Subscription expired. Please renew.');
        }
      }
    } catch (_) {}
  }

  Future<bool> enableBiometric() async {
    try {
      final localAuth = LocalAuthentication();
      final available = await localAuth.canCheckBiometrics;
      if (!available) return false;
      final ok = await localAuth.authenticate(localizedReason: 'Unlock JayPOS');
      if (!ok) return false;
      await _secureStorage.write(key: 'biometric_enabled', value: 'true');
      state = state.copyWith(biometricAvailable: true);
      return true;
    } catch (_) { return false; }
  }

  Future<bool> biometricLogin() async {
    try {
      final localAuth = LocalAuthentication();
      final available = await localAuth.canCheckBiometrics;
      if (!available) return false;
      final ok = await localAuth.authenticate(localizedReason: 'Unlock JayPOS');
      if (!ok) return false;
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return false;
      state = AuthState(status: AuthStatus.authenticated, token: token, biometricAvailable: true, offline: true);
      return true;
    } catch (_) { return false; }
  }

  void clearError() => state = state.copyWith(error: null);

  String _friendlyError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection';
      default:
        return e.message ?? 'Authentication failed';
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(secureStorageProvider));
});
