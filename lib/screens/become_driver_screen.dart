import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'become_passenger_screen.dart';

class BecomeDriverScreen extends StatelessWidget {
  const BecomeDriverScreen({Key? key}) : super(key: key);

  Widget _buildIndicator(bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: active ? 10 : 8,
      height: active ? 10 : 8,
      decoration: BoxDecoration(
        color: active ? Colors.black87 : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = const Color.fromARGB(255, 124, 169, 201);
    final Color arrowColor = Colors.grey.shade600;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            'assets/images/onboarding2.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Become a driver...',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take your friends to go university and go out. Set a route, days and time for your travels and hit the road. No more wasting space in the car.',
                        style: GoogleFonts.poppins(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0),
                        child: Row(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.chevron_left, size: 28, color: arrowColor),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildIndicator(false),
                                _buildIndicator(true),
                                _buildIndicator(false),
                              ],
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BecomePassengerScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.chevron_right, size: 28, color: arrowColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}