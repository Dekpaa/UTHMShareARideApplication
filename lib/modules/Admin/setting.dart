import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  String uthmAdminNo = '074537000';
  String policeNo = '999';

  @override
  void initState() {
    super.initState();
    _loadEmergencyNumbers();
  }

  // ================= LOAD NUMBERS =================
  Future<void> _loadEmergencyNumbers() async {
    final doc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('emergency')
        .get();

    if (doc.exists) {
      setState(() {
        uthmAdminNo = doc['uthmAdmin'] ?? uthmAdminNo;
        policeNo = doc['police'] ?? policeNo;
      });
    }
  }

  // ================= SAVE NUMBERS =================
  Future<void> _saveEmergencyNumbers() async {
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('emergency')
        .set({
      'uthmAdmin': uthmAdminNo,
      'police': policeNo,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency numbers updated')),
    );
  }

  // ================= TRIGGER EMERGENCY =================
  Future<void> _triggerEmergency(String type, String number) async {
    await FirebaseFirestore.instance.collection('emergency_call').add({
      'type': type,
      'number': number,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'triggered',
      'triggeredBy': 'admin',
    });

    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ================= EDIT DIALOG =================
  void _editNumberDialog(
    String title,
    String current,
    Function(String) onSave,
  ) {
    final controller = TextEditingController(text: current);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone Number',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onSave(controller.text);
              _saveEmergencyNumbers();
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ================= TILE =================
  Widget _settingTile({
    required IconData icon,
    required String title,
    Color iconColor = Colors.white,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white70),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ================= BASIC =================
          const Text(
            'General',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),

          _settingTile(
            icon: Icons.info_outline,
            title: 'App Information',
            onTap: () {},
          ),

          _settingTile(
            icon: Icons.policy,
            title: 'Privacy Policy',
            onTap: () {},
          ),

          // ================= EMERGENCY =================
          const SizedBox(height: 24),
          const Text(
            'Emergency',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),

          _settingTile(
            icon: Icons.phone,
            title: 'Call UTHM Admin ($uthmAdminNo)',
            iconColor: Colors.greenAccent,
            onTap: () => _triggerEmergency('uthm_admin', uthmAdminNo),
          ),

          _settingTile(
            icon: Icons.local_police,
            title: 'Call Police ($policeNo)',
            iconColor: Colors.redAccent,
            onTap: () => _triggerEmergency('police', policeNo),
          ),

          _settingTile(
            icon: Icons.edit,
            title: 'Edit Emergency Numbers',
            onTap: () {
              _editNumberDialog(
                'UTHM Admin Number',
                uthmAdminNo,
                (val) => uthmAdminNo = val,
              );
            },
          ),

          // ================= FOOTER =================
          const SizedBox(height: 30),
          const Center(
            child: Text(
              'UTHM Share A Ride\nAdmin Panel',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
