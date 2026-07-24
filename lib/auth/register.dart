import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/auth/auth_service.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:uthmshareride/utils/theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _matricCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  String _role = 'passenger';
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _matricCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _forceClearAll() {
    _fullNameCtrl.clear();
    _emailCtrl.clear();
    _matricCtrl.clear();
    _phoneCtrl.clear();
    _passwordCtrl.clear();
    _confirmCtrl.clear();

    _formKey.currentState?.reset();

    FocusScope.of(context).unfocus();

    setState(() => _agreeToTerms = false);
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please agree to the Terms & Privacy Policy')));
      return;
    }

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final fullName = _fullNameCtrl.text.trim();
    final matric = _matricCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    setState(() => _loading = true);

    try {
      final existingDoc = await AuthService.instance.getUserByEmail(email);
      if (existingDoc != null && mounted) {
        // Boleh beri pilihan kepada user (optional)
        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Email Previously Used'),
            content: Text(
              'The email "$email" was previously registered.\n\n'
              'If you are re-registering after deleting your account, '
              'your previous data will be used where possible.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue Registration'),
              ),
            ],
          ),
        );
        
        if (continueAnyway != true) {
          setState(() => _loading = false);
          return;
        }
      }

      final uc = await AuthService.instance.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: _role,
        matricNo: matric.isEmpty ? null : matric,
        phone: phone.isEmpty ? null : phone,
        sendEmailVerification: true,
      );

      try {
        if (_role == 'driver') {
          final uid = uc?.user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            // Check if driver profile already exists for this email
            final existingDriverQuery = await FirebaseFirestore.instance
                .collection('drivers')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();

            if (existingDriverQuery.docs.isNotEmpty) {
              // Update existing driver profile with new UID
              final existingDriverDoc = existingDriverQuery.docs.first;
              await FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(uid)
                  .set({
                ...existingDriverDoc.data(),
                'uid': uid,
                'fullName': fullName,
                'email': email,
                'phone': phone.isEmpty ? '' : phone,
                'matricNo': matric.isEmpty ? '' : matric,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              // Delete old driver document if different UID
              if (existingDriverDoc.id != uid) {
                await FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(existingDriverDoc.id)
                    .delete();
              }
            } else {
              await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
                'fullName': fullName,
                'email': email,
                'phone': phone.isEmpty ? '' : phone,
                'matricNo': matric.isEmpty ? '' : matric,
                'gender': '',
                'address': '',
                'status': 'pending',
                'matricCardUrl': '',
                'photoUrl': '',
                'licenseUrl': '',
                'icUrl': '',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Warning: failed to create/update driver profile: $e')));
        }
      }

      await AuthService.instance.signOut();

      if (!mounted) return;
      _forceClearAll();
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Verify your email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A verification link has been sent to your email. '
                'Please verify your email before logging in.\n',
              ),
              if (existingDoc != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ℹ️ Your previous account data has been restored where possible.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Try resend verification email
                try {
                  // Sign in temporarily to send verification
                  final uc2 = await AuthService.instance.signInWithEmail(email, password);
                  await AuthService.instance.sendEmailVerificationIfNeeded();
                  await AuthService.instance.signOut();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Verification email resent.')));
                  }
                } on FirebaseAuthException catch (e) {
                  String msg = 'Resend failed';
                  if (e.code == 'user-not-found') msg = 'Account not found (resend failed)';
                  else if (e.code == 'wrong-password') msg = 'Invalid credentials (resend failed)';
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Resend failed: $e')));
                  }
                }
              },
              child: const Text('Resend'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  // Attempt sign in with provided credentials
                  final uc2 = await AuthService.instance.signInWithEmail(email, password);
                  // Reload to ensure latest emailVerified
                  await AuthService.instance.reloadCurrentUser();
                  final verified = AuthService.instance.currentUser?.emailVerified ?? false;
                  
                  if (verified) {
                    // Sign out (we'll ask user to login normally)
                    await AuthService.instance.signOut();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Email is verified. You can now login.')));
                      Navigator.of(context).pop(); // Back to login
                    }
                  } else {
                    await AuthService.instance.signOut();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Email not verified yet. Please check your inbox.')));
                    }
                  }
                } on FirebaseAuthException catch (e) {
                  String msg = 'Check failed';
                  if (e.code == 'user-not-found') msg = 'Account not found';
                  else if (e.code == 'wrong-password') msg = 'Invalid credentials';
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Check failed: $e')));
                  }
                }
              },
              child: const Text('I verified — Check now'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Register failed';
      if (e.code == 'email-already-in-use') {
        msg = 'Email already in use by another active account. '
            'If you deleted your account, please restart the app and try again.';
      } else if (e.code == 'weak-password') {
        msg = 'Weak password. Use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        msg = 'Invalid email format.';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'Email/password accounts are not enabled. Contact support.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildCommonFields() {
    return Column(
      children: [
        TextFormField(
          controller: _fullNameCtrl,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.accentBlue,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person, color: Colors.white),
              labelText: 'Full name'),
          validator: (v) =>
          v == null || v.trim().isEmpty ? 'Please enter your full name' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.accentBlue,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email, color: Colors.white),
              labelText: 'Email'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter email';
            if (!v.contains('@')) return 'Invalid email';
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _matricCtrl,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.accentBlue,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.school, color: Colors.white),
              labelText: 'No Matric'),
          validator: (v) =>
          v == null || v.trim().isEmpty ? 'Please enter matric number' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.accentBlue,
          decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone, color: Colors.white),
              labelText: 'Phone number'),
          validator: (v) =>
          v == null || v.trim().isEmpty ? 'Please enter phone number' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.accentBlue,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock, color: Colors.white),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(_obscurePassword
                  ? Icons.visibility_off
                  : Icons.visibility, color: Colors.white),
            ),
            labelText: 'Password',
          ),
          validator: (v) =>
          v == null || v.length < 6 ? 'Password must be 6+ characters' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.accentBlue,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_off
                  : Icons.visibility, color: Colors.white),
            ),
            labelText: 'Confirm password',
          ),
          validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
        ),
      ],
    );
  }

  Future<void> _showTerms() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Terms & Conditions',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: const Text(
                      '1. Introduction\n\n'
                      'Welcome to UTHM Share A Ride. By using our service, you agree to these Terms & Conditions. '
                      'Please read them carefully. These Terms govern your access to and use of our application, services, and any content provided.\n\n'
                      '2. Use of Service\n\n'
                      'You must be a registered user to use certain features. You agree not to use the service for unlawful activities. '
                      'You are responsible for maintaining the confidentiality of your account credentials.\n\n'
                      '3. User Obligations\n\n'
                      'You agree to provide accurate information during registration and to update it as needed. You must comply with all applicable laws, and you acknowledge that UTHM Share A Ride may suspend or terminate accounts that violate these terms.\n\n'
                      '4. Account Deletion and Re-registration\n\n'
                      'Users may delete their accounts. Re-registration with the same email is allowed. Previous data may be restored where appropriate.\n\n'
                      '5. Payments and Fees\n\n'
                      'Where applicable, users are responsible for payment of fees. All fees are subject to change and will be communicated in-app.\n\n'
                      '6. Limitation of Liability\n\n'
                      'To the maximum extent permitted by law, UTHM Share A Ride is not liable for indirect, incidental, or consequential damages arising from the use of the service.\n\n'
                      '7. Changes to Terms\n\n'
                      'We may modify these Terms from time to time. Continued use of the service following changes means you accept the updated Terms.\n\n'
                      '8. Contact\n\n'
                      'If you have questions about these Terms, contact  Admin UTHM Share A Ride \n\n'
                      '--- End of Terms & Conditions ---\n\n',
                      style: TextStyle(height: 1.5, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPrivacy() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Privacy Policy',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: const Text(
                      'Privacy Policy\n\n'
                      'This Privacy Policy explains how UTHM Share A Ride collects, uses, discloses, and protects your personal data. '
                      'By registering and using the service, you consent to the practices described herein.\n\n'
                      '1. Information We Collect\n\n'
                      'We may collect information you provide directly such as name, email, matric number, phone number and profile data. We also collect usage information automatically.\n\n'
                      '2. How We Use Your Data\n\n'
                      'We use your data to operate and improve the service, to communicate with you, verify identity, and provide features requested. We may also use aggregated data for analytics.\n\n'
                      '3. Account Deletion and Data Retention\n\n'
                      'When you delete your account, authentication data is removed immediately. Firestore data may persist for re-registration purposes.\n\n'
                      '4. Data Sharing and Disclosure\n\n'
                      'We will not sell your personal data. We may share data with service providers who perform functions on our behalf, as required by law, or to protect rights and safety.\n\n'
                      '5. Data Security\n\n'
                      'We take reasonable measures to protect your data. However, no method of transmission over the internet is 100% secure.\n\n'
                      '6. Retention\n\n'
                      'We retain personal data for as long as necessary to provide services and to comply with legal obligations.\n\n'
                      '7. Your Rights\n\n'
                      'You may request access, correction or deletion of your personal data in accordance with applicable law.\n\n'
                      '8. Contact\n\n'
                      'For privacy concerns, contact Admin UTHM Share A Ride Admin.\n\n'
                      '--- End of Privacy Policy ---\n\n',
                      style: TextStyle(height: 1.5, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor('365770');
    return Theme(
      data: AppTheme.theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: bg,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Register',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
        ),
        body: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [bg, bg],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Create account',
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
                      const Text('Sign up as', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'passenger',
                              groupValue: _role,
                              activeColor: AppTheme.accentBlue,
                              onChanged: (v) {
                                _forceClearAll();
                                setState(() => _role = v!);
                              },
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: const [
                                  Icon(Icons.person_outline, color: Colors.white, size: 20),
                                  SizedBox(width: 6),
                                  Text('Passenger', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              value: 'driver',
                              groupValue: _role,
                              activeColor: AppTheme.accentBlue,
                              onChanged: (v) {
                                _forceClearAll();
                                setState(() => _role = v!);
                              },
                              contentPadding: EdgeInsets.zero,
                              title: Row(
                                children: const [
                                  Icon(Icons.directions_car_filled_outlined,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Driver',
                                      style: TextStyle(color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildCommonFields(),
                      const SizedBox(height: 12),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreeToTerms,
                            onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                            activeColor: AppTheme.accentBlue,
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                                children: [
                                  const TextSpan(text: "By proceeding, I agree that my data may be collected, used, and disclosed in accordance with the "),
                                  TextSpan(
                                      text: "Privacy Notice",
                                      style: const TextStyle(color: Colors.lightBlueAccent),
                                      recognizer: TapGestureRecognizer()..onTap = _showPrivacy),
                                  const TextSpan(text: ", and I fully comply with the "),
                                  TextSpan(
                                      text: "Terms & Conditions",
                                      style: const TextStyle(color: Colors.lightBlueAccent),
                                      recognizer: TapGestureRecognizer()..onTap = _showTerms),
                                  const TextSpan(text: " which I have read and understood."),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: (_loading || !_agreeToTerms) ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading
                              ? const SizedBox(height: 24, width: 24,
                              child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Register', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                          child: TextButton(
                              onPressed: _loading ? null : () => Navigator.pop(context),
                              child: const Text('Back to Login',
                                  style: TextStyle(color: Colors.white70)))),
                      const SizedBox(height: 20),
                    ],
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