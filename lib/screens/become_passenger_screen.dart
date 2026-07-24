import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

class BecomePassengerScreen extends StatelessWidget {
  const BecomePassengerScreen({Key? key}) : super(key: key);

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
    final accent = Color.fromARGB(255, 54, 87, 118);
    
    // Pre-cache image untuk keluar lebih cepat
    SchedulerBinding.instance!.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/images/onboarding3.png'), context);
    });

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22.0,
                    vertical: 26,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Image.asset(
                            'assets/images/onboarding3.png',
                            fit: BoxFit.contain,
                            // Ini yang penting untuk performance - gambar tidak akan kecil
                            gaplessPlayback: true,
                            // Cache untuk performance yang lebih baik
                            cacheHeight: 600, // Atau tinggi yang sesuai dengan gambar anda
                            cacheWidth: 600,  // Atau lebar yang sesuai dengan gambar anda
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '... or passenger',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save time and money, travel fast and with no stress. Make contacts. Change the regular way to learn for an interesting experience.',
                        style: GoogleFonts.poppins(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 6,
                              shadowColor: accent.withOpacity(0.3),
                            ),
                            child: Text(
                              'Get Started',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.chevron_left,
                                size: 26,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildIndicator(false),
                              _buildIndicator(false),
                              _buildIndicator(true),
                            ],
                          ),
                          const Spacer(),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 4),
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