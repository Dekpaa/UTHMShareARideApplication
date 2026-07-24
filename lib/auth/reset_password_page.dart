import 'package:flutter/material.dart';
import 'package:uthmshareride/auth/auth_service.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:uthmshareride/utils/theme.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() => _loading = true);

    try {
      await AuthService.instance.sendPasswordReset(email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset link sent.')));
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send reset email: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          title: const Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 22 ,fontWeight: FontWeight.w600)),
        ),
        body: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [bg, bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Reset your password', style: TextStyle(color: Colors.white, fontSize: 26)),
                    const SizedBox(height: 10),
                    const Text('Enter your email and we will send you a link to reset your password.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                    const SizedBox(height: 25),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: AppTheme.accentBlue,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined, color: Colors.white), labelText: 'Email'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Please enter your email';
                        if (!value.contains('@')) return 'Invalid email format';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _sendReset,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reset Password', style: TextStyle(fontSize: 16)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(child: TextButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('Back to Login', style: TextStyle(color: Colors.white, fontSize: 15)))),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
