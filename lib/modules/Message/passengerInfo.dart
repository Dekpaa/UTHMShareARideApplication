import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class PassengerInfoDialog extends StatelessWidget {
  final String rideId;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final String? passengerPhotoUrl;

  const PassengerInfoDialog({
    super.key,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhotoUrl,
  });

  // ================= EMERGENCY OPTIONS =================
  Future<void> _showEmergencyOptions(BuildContext context) async {
    const uthmAdmin = '074537000';
    const police = '999';

    // ===== LOG EMERGENCY =====
    await FirebaseFirestore.instance.collection('emergency_logs').add({
      'rideId': rideId,
      'driverId': driverId,
      'passengerId': passengerId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'triggered',
    });

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Emergency Call',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _emergencyTile(
                icon: Icons.support_agent,
                title: 'UTHM Admin',
                number: uthmAdmin,
              ),
              _emergencyTile(
                icon: Icons.local_police,
                title: 'Police (999)',
                number: police,
                danger: true,
              ),

              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _emergencyTile({
    required IconData icon,
    required String title,
    required String number,
    bool danger = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.red : Colors.blue),
      title: Text(title),
      subtitle: Text(number),
      trailing: const Icon(Icons.call),
      onTap: () async {
        final uri = Uri.parse('tel:$number');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // ================= PASSENGER PHOTO =================
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  passengerPhotoUrl != null && passengerPhotoUrl!.isNotEmpty
                      ? NetworkImage(passengerPhotoUrl!)
                      : null,
              child: passengerPhotoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 10),

            // ================= PASSENGER NAME =================
            Text(
              passengerName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Divider(height: 28),
            const SizedBox(height: 24),

            // ================= EMERGENCY BUTTON =================
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text(
                  'Emergency',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _showEmergencyOptions(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= INFO ROW =================
  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
