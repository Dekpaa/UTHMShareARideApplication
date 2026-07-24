import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/auth/auth_service.dart';
import 'package:uthmshareride/auth/reset_password_page.dart';
import 'package:uthmshareride/auth/role_selection_page.dart';
import 'package:uthmshareride/modules/Admin/admin_homepage.dart';
import 'package:uthmshareride/modules/Admin/admin_homepage.dart';
import 'package:uthmshareride/modules/Driver/driver_homepage.dart';
import 'package:uthmshareride/modules/Passenger/passangerhomepage.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:uthmshareride/utils/theme.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final uc = await AuthService.instance.signInWithEmail(
        _email.text.trim(),
        _password.text,
      );
      final verified = await AuthService.instance.isUserVerified(uid: uc.user?.uid);
      if (!verified) {
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Email not verified'),
              content: const Text(
                'Your email is not verified. Please check your inbox and click the verification link. '
                'You can resend the verification email now.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      await AuthService.instance.sendEmailVerificationIfNeeded();
                      await AuthService.instance.signOut();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Verification email resent. Check your inbox.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Resend failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Resend'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Sign out to make sure no half-signed-in session remains
                    try {
                      await AuthService.instance.signOut();
                    } catch (_) {}
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        return;
      }

      // If verified -> save credentials if biometric available, then proceed
      if (_biometricAvailable) {
        try {
          await AuthService.instance.saveCredentials(
            _email.text.trim(),
            _password.text,
          );
        } catch (_) {
          // non-fatal
        }
      }

      // proceed to post sign in (role handling, navigation)
      await _handlePostSignIn(uc.user!.uid);
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed';
      if (e.code == 'user-not-found') msg = 'Account does not exist';
      else if (e.code == 'wrong-password') msg = 'Wrong password';
      else if (e.code == 'invalid-email') msg = 'Invalid email format';
      else if (e.code == 'too-many-requests') msg = 'Too many attempts. Try again later.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tryBiometricSignIn() async {
    setState(() => _loading = true);
    try {
      if (!_biometricAvailable) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication is not supported on this device.')),
        );
        return;
      }

      final uc = await AuthService.instance.signInWithBiometrics();
      if (uc == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric sign-in failed or cancelled.')),
        );
        return;
      }

      // verify (Auth + Firestore)
      final verified = await AuthService.instance.isUserVerified(uid: uc.user?.uid);
      if (!verified) {
        // sign out and notify
        await AuthService.instance.signOut();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email not verified. Please verify before login.')),
        );
        return;
      }

      await _handlePostSignIn(uc.user!.uid);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Biometrics failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handlePostSignIn(String uid) async {
    final doc = await AuthService.instance.getUserDoc(uid);
    final Map<String, dynamic>? data = doc.data();

    List<String> roles = [];
    if (data != null) {
      if (data['roles'] is List) {
        roles = List<String>.from(data['roles'].map((e) => e.toString().toLowerCase()));
      } else if (data['role'] != null) {
        roles = [data['role'].toString().toLowerCase()];
      }
    }
    if (roles.isEmpty) roles = ['passenger'];

    if (roles.length == 1) {
      _navigateByRole(roles.first);
      return;
    }

    final activeRole = (data?['activeRole'] as String?)?.toLowerCase();
    if (activeRole != null && roles.contains(activeRole)) {
      _navigateByRole(activeRole);
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RoleSelectionPage(uid: uid, roles: roles)));
  }

  void _navigateByRole(String role) {
    if (!mounted) return;
    Widget home;
    switch (role.toLowerCase()) {
      case 'admin':
        home = const AdminHomePage();
        break;
      case 'driver':
        home = const DriverHomepage();
        break;
      default:
        home = const PassengerHomepage();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => home));
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor('365770');

return Theme(
  data: AppTheme.theme,
  child: Scaffold(
    appBar: AppBar(
      backgroundColor: bg,
      automaticallyImplyLeading: false,
      title: const Text('UTHM Share A Ride',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          )),
      centerTitle: true,
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [bg, bg.withOpacity(0.9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 120,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 30),
                    const Text('LOGIN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppTheme.accentBlue,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline, color: Colors.white),
                            labelText: 'Email',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter email';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: AppTheme.accentBlue,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white),
                            ),
                            labelText: 'Password',
                          ),
                          validator: (v) {
                            if (v == null || v.length < 6) return 'Min 6 characters';
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResetPasswordPage())),
                            child: const Text('Forgot Password', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _loading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Login', style: TextStyle(fontSize: 16 , fontWeight: FontWeight.bold))
                          ),
                        ),
                        const SizedBox(height: 12),
                      
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?", style: TextStyle(color: Colors.white70)),
                            TextButton(
                              onPressed: _loading ? null : () => Navigator.pushNamed(context, '/register'),
                              child: const Text('Register Now', style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
