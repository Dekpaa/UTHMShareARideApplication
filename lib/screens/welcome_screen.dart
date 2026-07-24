import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'save_time_money_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color bg = const Color.fromARGB(255, 124, 169, 201);
    final Color primary = Color.fromARGB(255, 54, 87, 118);

    final double screenW = MediaQuery.of(context).size.width;
    final double logoSize = (screenW * 0.36).clamp(100.0, 170.0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: logoSize,
                      height: logoSize,
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/welcomelogo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome to\nUTHM Share A Ride',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'Ride Anytime',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey[900],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '- Share the journey, save the planet',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.blueGrey[900]),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 36.0,
                vertical: 28,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SaveTimeMoneyScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    shadowColor: primary.withOpacity(0.35),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Let's Go!",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
