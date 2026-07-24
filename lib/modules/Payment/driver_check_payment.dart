import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<bool> hasPaymentInfo() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final doc = await FirebaseFirestore.instance
      .collection('driver_payment')
      .doc(user.uid)
      .get();

  if (!doc.exists) return false;
  final data = doc.data()!;
  return (data['bankName'] ?? '').toString().isNotEmpty &&
      (data['accountName'] ?? '').toString().isNotEmpty &&
      (data['accountNumber'] ?? '').toString().isNotEmpty &&
      (data['qrUrl'] ?? '').toString().isNotEmpty;
}
