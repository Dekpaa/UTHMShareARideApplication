import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  AuthService._private();
  static final AuthService instance = AuthService._private();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterSecureStorage _secure = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _kEmailKey = 'psm_saved_email';
  static const String _kPasswordKey = 'psm_saved_password';
  static const String _kBiometricEnabled = 'psm_biometric_enabled';

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }


  Future<UserCredential> signInWithEmailAndSync(String email, String password) async {
    final uc = await signInWithEmail(email, password);
    final uid = uc.user?.uid;
    if (uid != null) {
      await _syncEmailVerifiedFromAuth(uid);
    }
    return uc;
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) async {
    return _db.collection('users').doc(uid).get();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getUserByEmail(String email) async {
    final q = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
    if (q.docs.isEmpty) return null;
    return q.docs.first as DocumentSnapshot<Map<String, dynamic>>;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? matricNo,
    String? phone,
    bool sendEmailVerification = false,
  }) async {
    UserCredential? uc;
    try {
      DocumentSnapshot<Map<String, dynamic>>? oldUserDoc;
      try {
        final query = await _db.collection('users').where('email', isEqualTo: email).limit(1).get();
        if (query.docs.isNotEmpty) {
          oldUserDoc = query.docs.first;
          print('✅ Profil Firestore lama ditemukan untuk email: $email');
        }
      } catch (e) {
        print('ℹ️ Tiada profil lama ditemukan atau ralat carian: $e');
      }

      uc = await registerWithEmail(email, password);
      final uid = uc.user!.uid;
      final Map<String, dynamic> profile = <String, dynamic>{
        'uid': uid,
        'email': email,
        'fullName': fullName,
        'roles': [role],
        'activeRole': role,
        'createdAt': FieldValue.serverTimestamp(),
        'emailVerified': uc.user?.emailVerified ?? false,
        'updatedAt': FieldValue.serverTimestamp(),
        'matricNo': matricNo ?? oldUserDoc?.data()?['matricNo'],
        'phone': phone ?? oldUserDoc?.data()?['phone'],
        
        if (role == 'driver') ...{
          'isDriverApproved': false,
          'isDriverSubmitted': oldUserDoc?.data()?['isDriverSubmitted'] ?? false,
        },
        'photoUrl': null,
      };

      // 4) write profile to firestore (dengan UID BARU)
      await _db.collection('users').doc(uid).set(profile);

      // 5) OPTIONAL: Hapus dokumen Firestore lama jika ada
      if (oldUserDoc != null && oldUserDoc.exists) {
        try {
          await _db.collection('users').doc(oldUserDoc.id).delete();
          print('🗑️ Profil Firestore lama dengan ID: ${oldUserDoc.id} telah dihapus.');
        } catch (e) {
          print('⚠️ Ralat ketika menghapus dokumen lama (boleh diabaikan): $e');
        }
      }

      if (sendEmailVerification) {
        try {
          await uc.user?.sendEmailVerification();
        } catch (_) {
          // non-fatal, but we don't stop signup
        }
      }

      print('✅ Pendaftaran berhasil! UID baru: $uid');
      return uc;
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      
      // Jika error "email-already-in-use", boleh suggest user sign in
      if (e.code == 'email-already-in-use') {
        print('ℹ️ Email sudah digunakan. User mungkin perlu sign in atau reset password.');
      }
      
      rethrow;
    } catch (e) {
      print('❌ Error lain: $e');
      
      // Firestore or other error AFTER auth creation -> try rollback
      if (uc != null && uc.user != null) {
        try {
          await uc.user?.delete();
          print('↩️ Rollback: Account auth baru telah dihapus akibat error.');
        } catch (delErr) {
          print('⚠️ Gagal rollback auth user: $delErr');
        }
      }
      rethrow;
    }
  }

  Future<void> addRoleToUser({
    required String uid,
    required String role,
    Map<String, dynamic>? extraFields,
  }) async {
    final Map<String, dynamic> updateData = <String, dynamic>{
      'roles': FieldValue.arrayUnion([role]),
      'activeRole': role,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (extraFields != null) updateData.addAll(extraFields);

    if (role == 'driver') {
      updateData['isDriverSubmitted'] = true;
      updateData['isDriverApproved'] = false;
    }

    await _db.collection('users').doc(uid).set(updateData, SetOptions(merge: true));
  }

  /// Optionally update the activeRole (e.g., switch between passenger/driver)
  Future<void> setActiveRole(String uid, String role) async {
    await _db.collection('users').doc(uid).set({
      'activeRole': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Send verification email if needed (for current signed-in user)
  Future<void> sendEmailVerificationIfNeeded() async {
    final u = _auth.currentUser;
    if (u != null && !u.emailVerified) {
      await u.sendEmailVerification();
    }
  }

  /// Reload current user to refresh emailVerified etc.
  Future<void> reloadCurrentUser() async {
    final u = _auth.currentUser;
    if (u != null) await u.reload();
  }

  /// Return whether current user is verified (reloads first)
  /// This will check Auth first, then Firestore profile as fallback (useful for manual admin flag).
  Future<bool> isUserVerified({String? uid}) async {
    // If there's a signed-in auth user, prefer that
    final authUser = _auth.currentUser;
    if (authUser != null) {
      await authUser.reload();
      if (authUser.emailVerified) return true;

      // fallback to firestore
      final doc = await _db.collection('users').doc(authUser.uid).get();
      final d = doc.data();
      if (d != null && d['emailVerified'] == true) return true;
      return false;
    }

    // If no current auth user, but uid provided, check firestore only
    if (uid != null) {
      final doc = await _db.collection('users').doc(uid).get();
      final d = doc.data();
      if (d != null && d['emailVerified'] == true) return true;
    }

    return false;
  }


  Future<void> setEmailVerifiedInProfile(String uid, bool verified) async {
    await _db.collection('users').doc(uid).set({
      'emailVerified': verified,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncEmailVerifiedFromAuth(String uid) async {
    try {
      // Reload auth user
      final current = _auth.currentUser;
      if (current != null && current.uid == uid) {
        await current.reload();
        final verified = current.emailVerified;
        // Update Firestore if differs
        final doc = await _db.collection('users').doc(uid).get();
        final data = doc.data();
        final fsVal = data != null && data['emailVerified'] == true;
        if (verified != fsVal) {
          await _db.collection('users').doc(uid).set({
            'emailVerified': verified,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else {
        // no signed-in auth user (rare) - try to safely fetch user and not throw
        final doc = await _db.collection('users').doc(uid).get();
        // nothing else we can do without auth user
      }
    } catch (_) {
      // ignore sync errors (non-fatal)
    }
  }

  Future<void> saveCredentials(String email, String password) async {
    await _secure.write(key: _kEmailKey, value: email);
    await _secure.write(key: _kPasswordKey, value: password);
    await _secure.write(key: _kBiometricEnabled, value: '1');
  }

  Future<void> clearCredentials() async {
    await _secure.delete(key: _kEmailKey);
    await _secure.delete(key: _kPasswordKey);
    await _secure.delete(key: _kBiometricEnabled);
  }

  Future<Map<String, String?>> readCredentials() async {
    final email = await _secure.read(key: _kEmailKey);
    final password = await _secure.read(key: _kPasswordKey);
    return {'email': email, 'password': password};
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _secure.read(key: _kBiometricEnabled);
    return v == '1';
  }

  // ===== BIOMETRIC AUTHENTICATION =====
  Future<bool> deviceSupportsBiometrics() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    return canCheck && supported;
  }

  Future<bool> authenticateBiometric({String reason = 'Authenticate to login'}) async {
    return _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }

  Future<UserCredential?> signInWithBiometrics() async {
    final enabled = await isBiometricEnabled();
    if (!enabled) return null;

    final supports = await deviceSupportsBiometrics();
    if (!supports) return null;

    final ok = await authenticateBiometric();
    if (!ok) return null;

    final creds = await readCredentials();
    final email = creds['email'];
    final password = creds['password'];

    if (email == null || password == null) return null;

    // perform sign-in + sync
    final uc = await signInWithEmailAndSync(email, password);
    return uc;
  }

  // ===== EXTRA HELPER FUNCTIONS =====
  
  /// Function untuk delete account lengkap (auth + firestore)
  Future<void> deleteAccountPermanently() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final email = user.email;
    
    try {
      // 1. Hapus dokumen Firestore
      await _db.collection('users').doc(uid).delete();
      print('🗑️ Profil Firestore untuk $email telah dihapus.');
      
      // 2. Hapus account authentication
      await user.delete();
      print('🗑️ Account authentication untuk $email telah dihapus.');
      
      // 3. Clear credentials storage
      await clearCredentials();
      
    } catch (e) {
      print('❌ Gagal menghapus account: $e');
      rethrow;
    }
  }
  
  Future<bool> isEmailPreviouslyUsed(String email) async {
    try {
      final oldDoc = await getUserByEmail(email);
      return oldDoc != null && oldDoc.exists;
    } catch (_) {
      return false;
    }
  }
  
  Future<void> migrateUserData({
    required String oldUid,
    required String newUid,
    required String email,
  }) async {
    try {
      // 1. Get old data
      final oldDoc = await _db.collection('users').doc(oldUid).get();
      if (!oldDoc.exists) {
        print('ℹ️ Tiada data lama untuk UID: $oldUid');
        return;
      }
      
      final oldData = oldDoc.data() ?? {};
      
      // 2. Update UID in the data
      final newData = Map<String, dynamic>.from(oldData);
      newData['uid'] = newUid;
      newData['email'] = email;
      newData['updatedAt'] = FieldValue.serverTimestamp();
      newData['migratedFrom'] = oldUid;
      
      // 3. Write to new document
      await _db.collection('users').doc(newUid).set(newData);
      
      // 4. Optional: Delete old document
      await _db.collection('users').doc(oldUid).delete();
      
      print('✅ Data migrated dari $oldUid ke $newUid');
    } catch (e) {
      print('❌ Gagal migrate data: $e');
      rethrow;
    }
  }
}