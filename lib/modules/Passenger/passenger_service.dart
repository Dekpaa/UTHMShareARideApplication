import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PassengerService {
  final CollectionReference<Map<String, dynamic>> _db = FirebaseFirestore
      .instance
      .collection('passengers');
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
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Stream passenger profile
  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfileStream() {
    final uid = _uid;
    return _db.doc(uid).snapshots();
  }

  /// Update any profile field(s)
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    await _db.doc(uid).set(data, SetOptions(merge: true));
  }

  /// Get passenger profile once
  Future<Map<String, dynamic>?> getProfile() async {
    final uid = _uid;
    final doc = await _db.doc(uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  /// Upload file to Firebase Storage, returns download URL
  /// Untuk passenger, hanya butuh upload matric card
  Future<String> uploadMatricCard(
    File file,
    void Function(double progress)? onProgress,
  ) async {
    final uid = _uid;
    final pathInStorage =
        'passengers/$uid/matric_card_${DateTime.now().millisecondsSinceEpoch}';
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

      // Update profile dengan URL matric card
      await updateProfile({'matricCardUrl': url});

      return url;
    } finally {
      await sub.cancel();
    }
  }

  /// Delete passenger account
  Future<void> deleteAccount() async {
    final uid = _uid;
    await _db.doc(uid).delete();

    // Optional: Hapus juga file dari storage jika ada
    try {
      final matricCardRef = _storage.ref().child('passengers/$uid');
      await matricCardRef.listAll().then((result) {
        for (var item in result.items) {
          item.delete();
        }
      });
    } catch (e) {
      print('Error deleting storage files: $e');
    }
  }

  /// Check if passenger exists
  Future<bool> passengerExists() async {
    final uid = _uid;
    final doc = await _db.doc(uid).get();
    return doc.exists;
  }

  /// Update specific fields
  Future<void> updateProfileFields({
    String? name,
    String? phone,
    String? matricNo,
    String? gender,
    String? matricCardUrl,
  }) async {
    final Map<String, dynamic> updates = {};

    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (matricNo != null) updates['matricNo'] = matricNo;
    if (gender != null) updates['gender'] = gender;
    if (matricCardUrl != null) updates['matricCardUrl'] = matricCardUrl;

    if (updates.isNotEmpty) {
      await updateProfile(updates);
    }
  }
}
