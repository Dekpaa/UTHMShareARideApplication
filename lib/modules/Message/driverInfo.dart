import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';

class DriverInfoDialog extends StatelessWidget {
  final Ride ride;
  final String driverName;
  final String? driverPhotoUrl;
  final String passengerId;

  const DriverInfoDialog({
    super.key,
    required this.ride,
    required this.driverName,
    required this.driverPhotoUrl,
    required this.passengerId,
  });

  Future<void> _showEmergencyOptions(BuildContext context) async {
    const uthmAdmin = '074537000';
    const police = '999';

    await FirebaseFirestore.instance.collection('emergency_call').add({
      'rideId': ride.id,
      'driverId': ride.driverId,
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
    final car = ride.carDetails;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ================= HEADER =================
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // driver photo
            CircleAvatar(
              radius: 40,
              backgroundImage:
                  driverPhotoUrl != null && driverPhotoUrl!.isNotEmpty
                      ? NetworkImage(driverPhotoUrl!)
                      : null,
              child: driverPhotoUrl == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(height: 10),

            // driver name
            Text(
              driverName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Divider(height: 28),

            // ================= CAR DETAILS =================
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Car Details',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            _infoRow(Icons.directions_car, 'Model', car.model),
            _infoRow(Icons.confirmation_number, 'Plate No', car.plateNumber),
            _infoRow(Icons.color_lens, 'Color', car.color),
            _infoRow(Icons.event_seat, 'Capacity', car.seatingDisplay),

            // car image
            if (car.imageUrl != null && car.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    car.imageUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image, size: 40),
                  ),
                ),
              ),

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
            width: 90,
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
