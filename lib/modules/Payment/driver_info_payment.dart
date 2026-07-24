import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class DriverInfoPayment extends StatefulWidget {
  const DriverInfoPayment({super.key});

  @override
  State<DriverInfoPayment> createState() => _DriverInfoPaymentState();
}

class _DriverInfoPaymentState extends State<DriverInfoPayment> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _accountNumberController =TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  String? _qrUrl;
  File? _qrImageFile;
  bool _removeQr = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: no logged-in user')),
        );
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('driver_payment')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _bankNameController.text = data['bankName'] ?? '';
        _accountNameController.text = data['accountName'] ?? '';
        _accountNumberController.text = data['accountNumber'] ?? '';
        _qrUrl = data['qrUrl'];
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load payment info: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickQrImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1000,
        maxHeight: 1000,
      );

      if (picked != null) {
        setState(() {
          _qrImageFile = File(picked.path);
          _removeQr = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }


  Future<void> _removeQrImage() async {
    setState(() {
      _qrImageFile = null;
      _qrUrl = null;
      _removeQr = true;
    });
  }

  // Upload QR if needed (or remove if requested)
  Future<String?> _uploadQrImageIfNeeded(String uid) async {
    // If user wants to remove QR and didn't pick a new one
    if (_removeQr && _qrImageFile == null) {
      try {
        final ref =
            FirebaseStorage.instance.ref().child('driver_qr').child('$uid.png');
        await ref.delete();
      } catch (_) {
        // ignore if file doesn't exist
      }
      return null;
    }

    // No new image and not removing → keep old URL
    if (_qrImageFile == null) return _qrUrl;

    // New image selected → upload
    try {
      final ref =
          FirebaseStorage.instance.ref().child('driver_qr').child('$uid.png');

      await ref.putFile(_qrImageFile!);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      if (!mounted) return _qrUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload QR: $e')),
      );
      return _qrUrl;
    }
  }

  Future<void> _savePaymentInfo() async {
    if (_bankNameController.text.trim().isEmpty ||
        _accountNameController.text.trim().isEmpty ||
        _accountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all bank information.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: no logged-in user')),
        );
        return;
      }

      final uid = user.uid;
      final qrUrl = await _uploadQrImageIfNeeded(uid);

      await FirebaseFirestore.instance
          .collection('driver_payment')
          .doc(uid)
          .set(
        {
          'bankName': _bankNameController.text.trim(),
          'accountName': _accountNameController.text.trim(),
          'accountNumber': _accountNumberController.text.trim(),
          'qrUrl': qrUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() {
        _qrUrl = qrUrl;
        _removeQr = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment info saved successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save payment info: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        cursorColor: Colors.white,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white70),
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.25),
              width: 1,
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildQrPreview() {
    Widget content;

    if (_qrImageFile != null) {
      content = Image.file(
        _qrImageFile!,
        fit: BoxFit.contain, // avoid distortion
      );
    } else if (_qrUrl != null && _qrUrl!.isNotEmpty) {
      content = Image.network(
        _qrUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text(
            'Failed to load QR',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    } else {
      content = const Center(
        child: Text(
          'No QR uploaded yet',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return GestureDetector(
      // Tap to zoom in full size
      onTap: () {
        if (_qrImageFile == null && (_qrUrl == null || _qrUrl!.isEmpty)) {
          return;
        }

        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black87,
            insetPadding: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AspectRatio(
                aspectRatio: 1,
                child: _qrImageFile != null
                    ? Image.file(_qrImageFile!, fit: BoxFit.contain)
                    : Image.network(_qrUrl!, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // high contrast background for QR
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 1, // always square
          child: content,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseBg = hexStringToColor("365770");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: baseBg,
        title: const Text(
          "Payment Info",
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [baseBg, baseBg.withOpacity(0.95)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Bank & QR Payment",
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "This app only supports bank transfer / QR payment. Cash is NOT allowed.",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Bank Information",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  "Bank Name",
                                  _bankNameController,
                                  Icons.account_balance,
                                ),
                                _buildTextField(
                                  "Account Holder Name",
                                  _accountNameController,
                                  Icons.person,
                                ),
                                _buildTextField(
                                  "Account Number",
                                  _accountNumberController,
                                  Icons.confirmation_number,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  "QR Code (DuitNow / Bank QR)",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildQrPreview(),
                                const SizedBox(height: 10),

                                // QR tips in English
                                Container(
                                  margin:
                                      const EdgeInsets.only(bottom: 10, top: 4),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.15),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "QR tips:\n"
                                          "• Upload the full QR code (not cropped).\n"
                                          "• Make sure the image is clear, not blurry.\n"
                                          "• Avoid strong reflections or very dark lighting.\n"
                                          "• If possible, use the original QR from your bank app or a clean screenshot.",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.7),
                                          ),
                                        ),
                                        onPressed: _pickQrImage,
                                        icon: const Icon(
                                          Icons.photo_library,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'Select / Change QR',
                                          style:
                                              TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                            color: Colors.red.withOpacity(0.8),
                                          ),
                                        ),
                                        onPressed: (_qrUrl == null &&
                                                _qrImageFile == null)
                                            ? null
                                            : _removeQrImage,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
                                        label: const Text(
                                          'Remove QR',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: baseBg,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 6,
                              ),
                              onPressed: _isSaving ? null : _savePaymentInfo,
                              child: _isSaving
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : const Text(
                                      "Save",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
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
