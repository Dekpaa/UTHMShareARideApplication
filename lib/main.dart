import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uthmshareride/auth/user_login_page.dart';
import 'package:uthmshareride/modules/Admin/admin_homepage.dart';
import 'package:uthmshareride/modules/Passenger/passangerhomepage.dart';
import 'package:uthmshareride/screens/welcome_screen.dart';
import 'firebase_options.dart';
import 'auth/register.dart';
import 'modules/Driver/driver_homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTHM Share A Ride',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WelcomeScreen(),
      routes: {
        '/login': (_) => const UserLoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home_driver': (_) => const DriverHomepage(),
        '/home_passenger': (_) => const PassengerHomepage(),
        '/admin_dashboard': (_) => const AdminHomePage(),
      },
    );
  }
}