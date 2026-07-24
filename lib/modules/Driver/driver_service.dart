import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DriverService {
  final CollectionReference<Map<String, dynamic>> _db =
  FirebaseFirestore.instance.collection('drivers');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user found.',
      );
    }
    return u.uid;
  }

  Future<void> createDefaultProfile() async {
    final uid = _uid;
    final docRef = _db.doc(uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'name': _auth.currentUser!.displayName ?? '',
        'email': _auth.currentUser!.email ?? '',
        'phone': '',
        'matricNo': '',
        'gender': '',
        'status': 'pending',        
        'matricCardUrl': '',        
        'licenseUrl': '',
        'icUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Stream driver profile
  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfileStream() {
    final uid = _uid;
    return _db.doc(uid).snapshots();
  }

  /// Update any profile field(s)
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    await _db.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Upload file to Firebase Storage, returns download URL
  Future<String> uploadFile(
    File file,
    String pathInStorage,
    void Function(double progress)? onProgress,
  ) async {
    final ref = _storage.ref().child(pathInStorage);
    final uploadTask = ref.putFile(file);

    final sub = uploadTask.snapshotEvents.listen((event) {
      if (onProgress != null && event.totalBytes > 0) {
        final progress = event.bytesTransferred / event.totalBytes;
        onProgress(progress.clamp(0.0, 1.0));
      }
    });

    try {
      final snap = await uploadTask.whenComplete(() {});
      final url = await snap.ref.getDownloadURL();
      return url;
    } finally {
      await sub.cancel();
    }
  }
}
