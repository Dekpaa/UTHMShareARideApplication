import 'package:flutter/material.dart';
import 'package:uthmshareride/modules/Passenger/mybooking.dart';
import 'package:uthmshareride/modules/Payment/passenger_paymentscreen.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class PaymentPage extends StatelessWidget {
  final Ride ride;
  final Booking booking;

  const PaymentPage({
    super.key,
    required this.ride,
    required this.booking,
  });

  void _goToPaymentScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(ride: ride, booking: booking),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexStringToColor("365770");

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          'Make Payment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MyBookingsPage(initialTabIndex: 0),
              ),
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Your ride has arrived!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const Icon(Icons.payment, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'Fare:',
                style: TextStyle(fontSize: 22, color: Colors.white70,fontWeight: FontWeight.bold),
              ),
              Text(
                'RM ${ride.fare}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildLocationRow(
                        icon: Icons.location_on,
                        label: 'From:',
                        location: ride.start,
                        iconColor: Colors.blueAccent,
                      ),
                      const SizedBox(height: 10),
                      Divider(color: Colors.white.withOpacity(0.3)),
                      const SizedBox(height: 10),
                      _buildLocationRow(
                        icon: Icons.place,
                        label: 'To:',
                        location: ride.end,
                        iconColor: Colors.redAccent,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _goToPaymentScreen(context),
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Proceed to Payment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: bgColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
                          const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String location,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
