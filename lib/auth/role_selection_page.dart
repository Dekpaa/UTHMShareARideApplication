// lib/auth/role_selection_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RoleSelectionPage extends StatelessWidget {
  final String uid;
  final List<String> roles;

  const RoleSelectionPage({Key? key, required this.uid, required this.roles}) : super(key: key);

  Future<void> _setActiveRoleAndNavigate(BuildContext context, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'activeRole': role});

    if (!context.mounted) return;
    if (role == 'driver') {
      Navigator.pushReplacementNamed(context, '/home_driver');
    } else if (role == 'admin') {
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/home_passenger');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Role'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text('Choose which role you want to use this session:'),
            const SizedBox(height: 20),
            ...roles.map((r) {
              final label = r[0].toUpperCase() + r.substring(1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _setActiveRoleAndNavigate(context, r),
                    child: Text('Continue as $label'),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
