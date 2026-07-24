import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uthmshareride/auth/user_login_page.dart';
import 'package:uthmshareride/modules/Passenger/passangerhomepage.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class PassengerSettingsPage extends StatefulWidget {
  const PassengerSettingsPage({super.key});

  @override
  State<PassengerSettingsPage> createState() => _PassengerSettingsPageState();
}

class _PassengerSettingsPageState extends State<PassengerSettingsPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // ====================== URL LAUNCH ======================
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open link')),
      );
    }
  }

  // ====================== HELP CENTER ======================
  void _showHelpCenter() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Passenger Help Center'),
        content: const SingleChildScrollView(
          child: Text(
            '• How to book a ride\n'
            '• How to track driver location\n'
            '• How to use in-app chat\n'
            '• How to make payment\n'
            '• How to cancel a booking\n'
            '• Safety guidelines for passengers\n\n'
            'If you still need help, please contact support.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ====================== DELETE ACCOUNT ======================
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'This action is permanent. All your data will be deleted and cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _deleteAccount,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      final uid = _currentUser!.uid;

      // delete passenger data
      await FirebaseFirestore.instance
          .collection('passengers')
          .doc(uid)
          .delete();

      // delete auth account
      await _currentUser!.delete();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UserLoginPage()),
        (route) => false,
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Re-authentication required to delete account'),
        ),
      );
    }
  }

  // ====================== UI HELPERS ======================
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _settingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.white70,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }

  // ====================== BUILD ======================
  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    return Scaffold(
      backgroundColor: bg, // Full background color
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Help & Support Section
              Card(
                color: Colors.transparent,
                elevation: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Help & Support'),
                    _settingItem(
                      icon: Icons.help_center,
                      title: 'Help Center',
                      onTap: _showHelpCenter,
                    ),
                    _settingItem(
                      icon: Icons.share,
                      title: 'Share App',
                      onTap: () => Share.share(
                        'Try UTHM ShareRide – a secure carpooling app for UTHM.',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Legal Section
              Card(
                color: Colors.transparent,
                elevation: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Legal'),
                    _settingItem(
                      icon: Icons.privacy_tip,
                      title: 'Privacy Policy',
                      onTap: () => _launchUrl('https://uthm.edu.my'),
                    ),
                    _settingItem(
                      icon: Icons.description,
                      title: 'Terms of Service',
                      onTap: () => _launchUrl('https://uthm.edu.my'),
                    ),
                    _settingItem(
                      icon: Icons.security,
                      title: 'Safety Guidelines',
                      onTap: _showHelpCenter,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Account Section
              Card(
                color: Colors.transparent,
                elevation: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Account'),
                    _settingItem(
                      icon: Icons.delete_forever,
                      title: 'Delete Account',
                      iconColor: Colors.redAccent,
                      onTap: _showDeleteAccountDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Footer
              Center(
                child: Column(
                  children: [
                    Text(
                      'UTHM ShareRide v1.0.0',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '© 2024 Universiti Tun Hussein Onn Malaysia',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}