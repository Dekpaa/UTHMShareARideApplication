import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'become_driver_screen.dart';

class SaveTimeMoneyScreen extends StatelessWidget {
  const SaveTimeMoneyScreen({Key? key}) : super(key: key);

  Widget _buildIndicator(bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: active ? 10 : 8,
      height: active ? 10 : 8,
      decoration: BoxDecoration(
        color: active ? Colors.black87 : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color.fromARGB(255, 124, 169, 201);
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
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 26),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            'assets/images/onboarding1.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Save time and money',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Move between home and UTHM with friends. Save time and money, take care of the planet.',
                        style: GoogleFonts.poppins(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/login');
                              },
                              child: Text(
                                'Skip',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                _buildIndicator(true),
                                _buildIndicator(false),
                                _buildIndicator(false),
                              ],
                            ),
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BecomeDriverScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  Icons.chevron_right,
                                  size: 26,
                                  color: Colors.grey.shade600,
                                ),
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
          ],
        ),
      ),
    );
  }
}
