// lib/services/auth_service.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// บทบาทผู้ใช้
enum UserRole { user, admin }

/// โมเดลผู้ใช้ที่ล็อกอินอยู่
class AuthUser {
  final String id;
  final String email;
  final String name;
  final String phone;
  final UserRole role;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
  });

  AuthUser copyWith({
    String? email,
    String? name,
    String? phone,
    UserRole? role,
  }) {
    return AuthUser(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
    );
  }

  factory AuthUser.fromFirebase(
    User u, {
    UserRole role = UserRole.user,
    String phone = '',
  }) {
    return AuthUser(
      id: u.uid,
      email: u.email ?? '',
      name: u.displayName ?? (u.email?.split('@').first ?? 'ผู้ใช้'),
      phone: phone.isNotEmpty ? phone : (u.phoneNumber ?? ''),
      role: role,
    );
  }
}

/// บริการยืนยันตัวตน (Firebase) แบบ Singleton
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _fa = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isSignedIn => _fa.currentUser != null;

  /// stream เปลี่ยนแปลงสถานะการล็อกอิน (emit AuthUser ที่ resolve role/phone แล้ว)
  Stream<AuthUser?> get onAuthStateChanged async* {
    await for (final u in _fa.authStateChanges()) {
      if (u == null) {
        _currentUser = null;
        yield null;
      } else {
        final role = await _fetchRole(u.uid) ?? UserRole.user;
        final phone = await _fetchPhone(u.uid) ?? (u.phoneNumber ?? '');
        _currentUser = AuthUser.fromFirebase(u, role: role, phone: phone);
        yield _currentUser;
      }
    }
  }

  /* ---------------------------- LOGIN ---------------------------- */
  Future<void> login(
    String email,
    String password, {
    UserRole? forceRole,
  }) async {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('กรุณากรอกอีเมลและรหัสผ่าน');
    }
    try {
      final cred = await _fa.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final u = cred.user!;
      final role = await _fetchRole(u.uid) ?? UserRole.user;

      // ถ้ามี forceRole ให้ตรวจสอบ
      if (forceRole != null && role != forceRole) {
        await _fa.signOut();
        throw Exception(forceRole == UserRole.user
            ? 'บัญชีนี้ไม่ใช่ผู้ใช้ทั่วไป'
            : 'บัญชีนี้ไม่ใช่ผู้ดูแลระบบ');
      }

      final phone = await _fetchPhone(u.uid) ?? (u.phoneNumber ?? '');
      _currentUser = AuthUser.fromFirebase(u, role: role, phone: phone);
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  /* ---------------------------- SIGN UP ---------------------------- */
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    if (email.isEmpty || password.isEmpty || fullName.isEmpty) {
      throw Exception('กรุณากรอกข้อมูลให้ครบ');
    }
    try {
      final cred = await _fa.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final u = cred.user!;
      await u.updateDisplayName(fullName);

      // สร้างเอกสาร users/{uid}
      await _db.collection('users').doc(u.uid).set({
        'profile': {
          'name': fullName,
          'email': email,
          'phone': phone ?? '',
          'role': 'user', // สมัครใหม่เป็น user
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));

      _currentUser =
          AuthUser.fromFirebase(u, role: UserRole.user, phone: phone ?? '');
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  /* ---------------------------- UPDATE PROFILE ---------------------------- */
  /// อัปเดตชื่อ/อีเมล/โทรศัพท์
  /// - อีเมลใช้ verifyBeforeUpdateEmail (ผู้ใช้ต้องกดลิงก์ยืนยันก่อนถึงจะมีผลที่ Firebase Auth)
  /// - Firestore จะถูกอัปเดตทันทีเพื่อสะท้อน UI
  Future<AuthUser> updateProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    final u = _fa.currentUser;
    if (u == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');

    // FirebaseAuth (displayName / verify email)
    if (name != null && name.trim().isNotEmpty && name != u.displayName) {
      await u.updateDisplayName(name.trim());
    }
    if (email != null && email.trim().isNotEmpty && email != u.email) {
      await u.verifyBeforeUpdateEmail(email.trim());
    }

    // Firestore profile
    final profileUpdate = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (email != null) 'email': email.trim(),
      if (phone != null) 'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profileUpdate.isNotEmpty) {
      await _db.collection('users').doc(u.uid).set(
        {'profile': profileUpdate},
        SetOptions(merge: true),
      );
    }

    await u.reload(); // refresh ข้อมูล FirebaseAuth (displayName)
    final reloaded = _fa.currentUser!;

    final role = await _fetchRole(reloaded.uid) ?? UserRole.user;
    // แก้ลำดับการประเมิน ?? กับ await ให้ชัดเจน
    final phoneValue = phone ??
        (await _fetchPhone(reloaded.uid)) ??
        (reloaded.phoneNumber ?? '');
    _currentUser =
        AuthUser.fromFirebase(reloaded, role: role, phone: phoneValue)
            .copyWith(name: name, email: email, phone: phoneValue);
    return _currentUser!;
  }

  /* ---------------------------- CHANGE PASSWORD ---------------------------- */
  /// เปลี่ยนรหัสผ่านแบบปลอดภัย:
  /// - บังคับ re-authenticate ด้วยรหัสเดิมก่อน (required โดย Firebase ในหลายเคส)
  /// - newPassword ต้องยาว >= 6
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final u = _fa.currentUser;
    if (u == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    if ((u.email ?? '').isEmpty) {
      throw Exception('บัญชีนี้ไม่มีอีเมล จึงไม่สามารถเปลี่ยนรหัสผ่านได้');
    }
    if (newPassword.length < 6) {
      throw Exception('รหัสผ่านควรยาวอย่างน้อย 6 ตัวอักษร');
    }
    if (newPassword == oldPassword) {
      throw Exception('รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสเดิม');
    }

    try {
      // ✅ Reauthenticate ก่อน
      final cred = EmailAuthProvider.credential(
        email: u.email!,
        password: oldPassword,
      );
      await u.reauthenticateWithCredential(cred);

      // ✅ แล้วค่อยอัปเดตรหัสผ่าน
      await u.updatePassword(newPassword);

      // (ทางเลือก) บังคับ reload เพื่อความชัวร์
      await u.reload();
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  /* --------------------- SET INITIAL PASSWORD (link) --------------------- */
  /// ใช้กับบัญชีที่ยังไม่มีวิธีเข้าสู่ระบบแบบอีเมล/รหัสผ่าน (เช่น สมัครด้วย Google/Apple)
  Future<void> setInitialPassword({
    required String email,
    required String newPassword,
  }) async {
    final u = _fa.currentUser;
    if (u == null) throw Exception('ยังไม่ได้เข้าสู่ระบบ');
    if (newPassword.length < 6) {
      throw Exception('รหัสผ่านควรยาวอย่างน้อย 6 ตัวอักษร');
    }

    try {
      final methods = await _fa.fetchSignInMethodsForEmail(email);
      if (methods.contains('password')) {
        throw Exception('บัญชีนี้มีรหัสผ่านอยู่แล้ว');
      }
      final cred =
          EmailAuthProvider.credential(email: email, password: newPassword);
      await u
          .linkWithCredential(cred); // ผูก email+password เข้ากับผู้ใช้ปัจจุบัน
      await u.reload();
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e));
    }
  }

  /* ---------------------------- LOGOUT ---------------------------- */
  Future<void> logout() async {
    await _fa.signOut();
    _currentUser = null;
  }

  /* ---------------------------- UTILITIES ---------------------------- */
  Future<UserRole?> _fetchRole(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final profile = (snap.data()?['profile'] as Map<String, dynamic>?) ?? {};
    final r = (profile['role'] as String?) ?? 'user';
    return r == 'admin' ? UserRole.admin : UserRole.user;
  }

  Future<String?> _fetchPhone(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final profile = (snap.data()?['profile'] as Map<String, dynamic>?) ?? {};
    return profile['phone'] as String?;
  }

  /// ดึง sign-in methods ของอีเมล (ช่วยเช็คว่าบัญชีนี้เป็น password-account ไหม)
  Future<List<String>> getSignInMethods(String email) {
    return _fa.fetchSignInMethodsForEmail(email);
  }

  /// reload ผู้ใช้ และ sync `_currentUser`
  Future<AuthUser?> reloadCurrentUser() async {
    final u = _fa.currentUser;
    if (u == null) {
      _currentUser = null;
      return null;
    }
    await u.reload();
    final role = await _fetchRole(u.uid) ?? UserRole.user;
    final phone = await _fetchPhone(u.uid) ?? (u.phoneNumber ?? '');
    _currentUser =
        AuthUser.fromFirebase(_fa.currentUser!, role: role, phone: phone);
    return _currentUser;
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'รูปแบบอีเมลไม่ถูกต้อง';
      case 'user-disabled':
        return 'บัญชีนี้ถูกระงับการใช้งาน';
      case 'user-not-found':
      case 'wrong-password':
        return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      case 'email-already-in-use':
        return 'อีเมลนี้ถูกใช้ไปแล้ว';
      case 'weak-password':
        return 'รหัสผ่านอ่อนเกินไป';
      case 'requires-recent-login':
        return 'กรุณาล็อกอินใหม่ก่อนทำรายการนี้';
      case 'too-many-requests':
        return 'พยายามมากเกินไป โปรดลองใหม่ภายหลัง';
      default:
        return e.message ?? 'เกิดข้อผิดพลาดจาก FirebaseAuth (${e.code})';
    }
  }
}
