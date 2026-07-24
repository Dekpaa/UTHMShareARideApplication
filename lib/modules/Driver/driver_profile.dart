import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class DriverService {
  final CollectionReference<Map<String, dynamic>> _db =
      FirebaseFirestore.instance.collection('drivers');
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No authenticated user.',
      );
    }
    return u.uid;
  }

  Future<void> createDefaultProfile() async {
    final uid = _uid;
    final docRef = _db.doc(uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'fullName': _auth.currentUser!.displayName ?? '',
        'email': _auth.currentUser!.email ?? '',
        'phone': '',
        'matricNo': '',
        'gender': '',
        'address': '',
        'status': 'pending',
        'matricCardUrl': '',
        'licenseUrl': '',
        'icUrl': '',
        'photoUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfileStream() {
    final uid = _uid;
    return _db.doc(uid).snapshots();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = _uid;
    await _db.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<String> uploadFile(
    File file,
    String pathInStorage,
    void Function(double)? onProgress,
  ) async {
    final ref = _storage.ref().child(pathInStorage);
    final uploadTask = ref.putFile(file);

    final sub = uploadTask.snapshotEvents.listen((event) {
      if (onProgress != null && event.totalBytes > 0) {
        final p = event.bytesTransferred / event.totalBytes;
        onProgress(p.clamp(0.0, 1.0));
      }
    });

    try {
      final snap = await uploadTask.whenComplete(() {});
      final url = await snap.ref.getDownloadURL();
      return url;
    } finally {
      await sub.cancel();
    }
  }

  Future<void> deleteFileByUrl(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // ignore
    }
  }
}

class DriverProfilePage extends StatefulWidget {
  const DriverProfilePage({super.key});

  @override
  State<DriverProfilePage> createState() => _DriverProfilePageState();
}

class _DriverProfilePageState extends State<DriverProfilePage> {
  final DriverService _service = DriverService();
  final ImagePicker _picker = ImagePicker();

  // profile fields
  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _matricNo = '';
  String _gender = '';
  String _address = '';
  String _status = 'pending';

  // photo
  String? _photoUrl;
  File? _profileLocalFile;

  // documents
  String? _matricCardUrl;
  String? _licenseUrl;
  String? _roadtaxUrl;
  String? _icUrl;
  File? _matricLocal;
  File? _licenseLocal;
  File? _icLocal;
  File? _roadtaxLocal;

  // controllers
  late TextEditingController _fullNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _matricCtrl;
  late TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _matricCtrl = TextEditingController();
    _addressCtrl = TextEditingController();

    try {
      _service.createDefaultProfile();
    } catch (_) {}

    _service.getProfileStream().listen((snap) {
      if (!snap.exists) return;
      final d = snap.data()!;
      setState(() {
        _fullName = (d['fullName'] ?? '') as String;
        _email = (d['email'] ?? '') as String;
        _phone = (d['phone'] ?? '') as String;
        _matricNo = (d['matricNo'] ?? '') as String;
        _gender = (d['gender'] ?? '') as String;
        _address = (d['address'] ?? '') as String;
        _status = (d['status'] ?? 'pending') as String;
        _photoUrl = (d['photoUrl'] ?? '') as String;
        _matricCardUrl = (d['matricCardUrl'] ?? '') as String;
        _licenseUrl = (d['licenseUrl'] ?? '') as String;
        _icUrl = (d['icUrl'] ?? '') as String;
        _fullNameCtrl.text = _fullName;
        _phoneCtrl.text = _phone;
        _matricCtrl.text = _matricNo;
        _addressCtrl.text = _address;
      });
    });
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _matricCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ---------------- Profile image pickers ----------------
  Future<void> _pickProfileFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _profileLocalFile = File(picked.path));
      }
      if (_profileLocalFile != null) await _uploadProfileImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pick failed: $e')),
        );
      }
    }
  }

  Future<void> _pickProfileFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _profileLocalFile = File(picked.path));
      }
      if (_profileLocalFile != null) await _uploadProfileImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera failed: $e')),
        );
      }
    }
  }

  void _showProfileImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _pickProfileFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _pickProfileFromCamera();
              },
            ),
            if (_photoUrl != null && _photoUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _removeProfilePhoto();
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Upload / remove profile photo ----------------
  Future<void> _uploadProfileImage() async {
    if (_profileLocalFile == null) return;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final path =
          'driver_documents/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final oldUrl = _photoUrl;
      if (oldUrl != null && oldUrl.isNotEmpty) {
        try {
          await _service.deleteFileByUrl(oldUrl);
        } catch (_) {}
      }

      final url = await _service.uploadFile(
        _profileLocalFile!,
        path,
        (p) {}, // no progress UI
      );

      await _service.updateProfile({'photoUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo uploaded')),
        );
      }

      setState(() {
        _profileLocalFile = null;
        _photoUrl = url;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    final url = _photoUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No profile photo to remove')),
        );
      }
      return;
    }

    try {
      await _service.deleteFileByUrl(url);
    } catch (_) {}

    try {
      await _service.updateProfile({'photoUrl': ''});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo removed')),
        );
      }
      setState(() {
        _photoUrl = '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove photo: $e')),
        );
      }
    }
  }

  // ---------------- Generic doc picker (gallery or camera) ----------------
  Future<void> _pickDoc({
    required Future<void> Function(File) onPicked,
  }) async {
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  final picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    await onPicked(File(picked.path));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Pick failed: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.of(context).pop();
                try {
                  final picked = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  if (picked != null) {
                    await onPicked(File(picked.path));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Camera failed: $e')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFileAndSave(
    File file,
    String firestoreField,
    String filenamePrefix,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final path =
          'driver_documents/$uid/$filenamePrefix${DateTime.now().millisecondsSinceEpoch}.jpg';

      final url = await _service.uploadFile(
        file,
        path,
        (p) {}, // no progress UI
      );

      await _service.updateProfile({firestoreField: url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload successful')),
        );
      }

      setState(() {
        if (firestoreField == 'matricCardUrl') {
          _matricCardUrl = url;
        } else if (firestoreField == 'licenseUrl') {
          _licenseUrl = url;
        } else if (firestoreField == 'icUrl') {
          _icUrl = url;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _uploadMatric() async {
    if (_matricLocal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matric card selected')),
        );
      }
      return;
    }
    await _uploadFileAndSave(_matricLocal!, 'matricCardUrl', 'matric_');
    setState(() => _matricLocal = null);
  }

  Future<void> _uploadLicense() async {
    if (_licenseLocal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No license selected')),
        );
      }
      return;
    }
    await _uploadFileAndSave(_licenseLocal!, 'licenseUrl', 'license_');
    setState(() => _licenseLocal = null);
  }

  Future<void> _uploadRoadtax() async {
    if (_roadtaxLocal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No roadtax selected')),
        );
      }
      return;
    }
    await _uploadFileAndSave(_roadtaxLocal!, 'roadtaxUrl', 'roadtax_');
    setState(() => _roadtaxLocal = null);
  }

  Future<void> _uploadIC() async {
    if (_icLocal == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No IC selected')),
        );
      }
      return;
    }
    await _uploadFileAndSave(_icLocal!, 'icUrl', 'ic_');
    setState(() => _icLocal = null);
  }

  // ---------------- Remove documents ----------------
  Future<void> _removeDocument(String? url, String firestoreField) async {
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No document to remove')),
        );
      }
      return;
    }

    try {
      await _service.deleteFileByUrl(url);
    } catch (_) {}

    try {
      await _service.updateProfile({firestoreField: ''});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document removed')),
        );
      }
      setState(() {
        if (firestoreField == 'matricCardUrl') {
          _matricCardUrl = '';
          _matricLocal = null;
        } else if (firestoreField == 'licenseUrl') {
          _licenseUrl = '';
          _licenseLocal = null;
        } else if (firestoreField == 'roadtaxUrl') {
          _licenseUrl = '';
          _licenseLocal = null;
        } else if (firestoreField == 'icUrl') {
          _icUrl = '';
          _icLocal = null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove document: $e')),
        );
      }
    }
  }

  Future<void> _removeMatric() async {
    await _removeDocument(_matricCardUrl, 'matricCardUrl');
  }

  Future<void> _removeLicense() async {
    await _removeDocument(_licenseUrl, 'licenseUrl');
  }
  
  Future<void> _removeRoadtax() async {
    await _removeDocument(_roadtaxUrl, 'roadtaxUrl');
  }

  Future<void> _removeIC() async {
    await _removeDocument(_icUrl, 'icUrl');
  }

  // ---------------- Edit profile dialog ----------------
  void _showEditDialog() {
    _fullNameCtrl.text = _fullName;
    _phoneCtrl.text = _phone;
    _matricCtrl.text = _matricNo;
    _addressCtrl.text = _address;

    String selectedGender = _gender;
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxHeight = MediaQuery.of(context).size.height * 0.85;
            final maxWidth = MediaQuery.of(context).size.width * 0.92;
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxHeight,
                  maxWidth: maxWidth,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: hexStringToColor('365770'),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[600],
                            ),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Form(
                          key: dialogFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Colors.grey[200],
                                    child: ClipOval(
                                      child: SizedBox(
                                        width: 68,
                                        height: 68,
                                        child: _photoUrl != null &&
                                                _photoUrl!.isNotEmpty
                                            ? Image.network(
                                                _photoUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                  Icons.person,
                                                  size: 40,
                                                ),
                                              )
                                            : _profileLocalFile != null
                                                ? Image.file(
                                                    _profileLocalFile!,
                                                    fit: BoxFit.cover,
                                                  )
                                                : const Icon(
                                                    Icons.person,
                                                    size: 40,
                                                  ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Profile photo',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.of(context).pop();
                                                _showProfileImageOptions();
                                              },
                                              icon: const Icon(
                                                Icons.photo,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Change',
                                                style: TextStyle(fontSize: 13),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    hexStringToColor('365770'),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton(
                                              onPressed: () async {
                                                if ((_photoUrl ?? '').isEmpty) {
                                                  return;
                                                }
                                                await _removeProfilePhoto();
                                                setDialogState(() {});
                                              },
                                              child: const Text(
                                                'Remove',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Full name
                              TextFormField(
                                controller: _fullNameCtrl,
                                textCapitalization:
                                    TextCapitalization.words,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.person),
                                  labelText: 'Full name',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 12,
                                  ),
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Please enter full name'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              LayoutBuilder(
                                builder: (ctx, constr) {
                                  if (constr.maxWidth > 420) {
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _phoneCtrl,
                                            keyboardType: TextInputType.phone,
                                            decoration: InputDecoration(
                                              prefixIcon:
                                                  const Icon(Icons.phone),
                                              labelText: 'Phone',
                                              filled: true,
                                              fillColor: Colors.grey[100],
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                                horizontal: 12,
                                              ),
                                            ),
                                            validator: (v) =>
                                                v == null || v.trim().isEmpty
                                                    ? 'Enter phone'
                                                    : null,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _matricCtrl,
                                            decoration: InputDecoration(
                                              prefixIcon:
                                                  const Icon(Icons.school),
                                              labelText: 'Matric No',
                                              filled: true,
                                              fillColor: Colors.grey[100],
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide.none,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 14,
                                                horizontal: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      children: [
                                        TextFormField(
                                          controller: _phoneCtrl,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                            prefixIcon:
                                                const Icon(Icons.phone),
                                            labelText: 'Phone',
                                            filled: true,
                                            fillColor: Colors.grey[100],
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              vertical: 14,
                                              horizontal: 12,
                                            ),
                                          ),
                                          validator: (v) =>
                                              v == null || v.trim().isEmpty
                                                  ? 'Enter phone'
                                                  : null,
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          controller: _matricCtrl,
                                          decoration: InputDecoration(
                                            prefixIcon:
                                                const Icon(Icons.school),
                                            labelText: 'Matric No',
                                            filled: true,
                                            fillColor: Colors.grey[100],
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              vertical: 14,
                                              horizontal: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),

                              const SizedBox(height: 12),

                              DropdownButtonFormField<String>(
                                value: selectedGender.isEmpty
                                    ? null
                                    : selectedGender,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.transgender),
                                  labelText: 'Gender',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Male',
                                    child: Text('Male'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Female',
                                    child: Text('Female'),
                                  ),
                                ],
                                onChanged: (v) {
                                  setDialogState(() {
                                    selectedGender = v ?? '';
                                  });
                                },
                              ),

                              const SizedBox(height: 12),

                              TextFormField(
                                controller: _addressCtrl,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.home),
                                  labelText: 'Address',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                maxLines: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // action bar
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                side: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.black87),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (!dialogFormKey.currentState!.validate()) {
                                  return;
                                }

                                final payload = {
                                  'fullName': _fullNameCtrl.text.trim(),
                                  'phone': _phoneCtrl.text.trim(),
                                  'matricNo': _matricCtrl.text.trim(),
                                  'gender': selectedGender,
                                  'address': _addressCtrl.text.trim(),
                                };

                                try {
                                  await _service.updateProfile(payload);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Profile updated'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Save failed: $e'),
                                      ),
                                    );
                                  }
                                }

                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: hexStringToColor('365770'),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- Small UI helpers ----------------
  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color bg;
    switch (s) {
      case 'verified':
        bg = Colors.green;
        break;
      case 'unverified':
        bg = Colors.red;
        break;
      default:
        bg = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.isEmpty ? 'PENDING' : status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _profileInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: hexStringToColor('365770')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTipsDialog(String title, List<String> tips) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tips.map((tip) => Text('• $tip')).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _imageCard({
    required String title,
    required String? imageUrl,
    required File? localFile,
    required VoidCallback onPick,
    VoidCallback? onRemove,
    bool isPortrait = false,
    required VoidCallback onShowTips,
  }) {
    Widget imageBody;
    if (localFile != null) {
      imageBody = Image.file(
        localFile,
        fit: BoxFit.contain,
      );
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      imageBody = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image)),
      );
    } else {
      imageBody = const Center(child: Text('No image'));
    }

    final hasImage =
        localFile != null || (imageUrl != null && imageUrl.isNotEmpty);

    return Card(
      color: Colors.white.withOpacity(0.95),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Tips button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: onShowTips,
                  icon: const Icon(
                    Icons.info_outline,
                    size: 18,
                  ),
                  label: const Text('Tips'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: isPortrait ? (3 / 4) : (16 / 9),
                child: Container(
                  color: Colors.grey[200],
                  child: GestureDetector(
                    onTap: hasImage
                        ? () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                child: InteractiveViewer(
                                  child: localFile != null
                                      ? Image.file(localFile)
                                      : Image.network(imageUrl!),
                                ),
                              ),
                            );
                          }
                        : null,
                    child: imageBody,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Change + Upload (combined)
                TextButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Change & Upload'),
                ),
                const SizedBox(width: 8),

                // Remove button with bin + text
                if (onRemove != null && hasImage)
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                    ),
                    label: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor('365770');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Driver Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_status.toLowerCase() == 'pending' || _status.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Your driver account is pending approval. Please upload required documents.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 12),
            Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: _showProfileImageOptions,
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        child: _photoUrl != null && _photoUrl!.isNotEmpty
                            ? Image.network(
                                _photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) {
                                  return const Icon(
                                    Icons.person,
                                    size: 72,
                                  );
                                },
                              )
                            : _profileLocalFile != null
                                ? Image.file(
                                    _profileLocalFile!,
                                    fit: BoxFit.cover,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 72,
                                  ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: MediaQuery.of(context).size.width * 0.35,
                  bottom: 0,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _showProfileImageOptions,
                      child: const Padding(
                        padding: EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: Text(
                    _fullName.isEmpty ? '-' : _fullName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _email.isEmpty ? '-' : _email,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _statusChip(_status),
            const SizedBox(height: 20),
            Card(
              color: Colors.white.withOpacity(0.95),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _profileInfoRow(Icons.phone, 'Phone', _phone),
                    _profileInfoRow(
                      Icons.credit_card,
                      'Matric No',
                      _matricNo,
                    ),
                    _profileInfoRow(Icons.home, 'Address', _address),
                    _profileInfoRow(
                      Icons.transgender,
                      'Gender',
                      _gender,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            Align(
              alignment: Alignment.centerRight, 
              child: SizedBox(
                width: 150,
                child: ElevatedButton.icon(
                  onPressed: _showEditDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _imageCard(
              title: 'Matric Card',
              imageUrl: _matricCardUrl,
              localFile: _matricLocal,
              onPick: () async {
                await _pickDoc(
                  onPicked: (f) async {
                    setState(() => _matricLocal = f);
                    await _uploadMatric(); 
                  },
                );
              },
              onRemove: _removeMatric,
              isPortrait: true,
              onShowTips: () {
                _showTipsDialog('Matric Card Tips', [
                  'Make sure the entire card is visible.',
                  'Avoid blurry or dark photos.',
                  'Ensure all text is readable.',
                  'Avoid shadows or reflections.',
                ]);
              },
            ),

            const SizedBox(height: 14),

            _imageCard(
              title: "Driver's License",
              imageUrl: _licenseUrl,
              localFile: _licenseLocal,
              onPick: () async {
                await _pickDoc(
                  onPicked: (f) async {
                    setState(() => _licenseLocal = f);
                    await _uploadLicense();
                  },
                );
              },
              onRemove: _removeLicense,
              isPortrait: false,
              onShowTips: () {
                _showTipsDialog("Driver's License Tips", [
                  'Upload the full front of your license.',
                  'Ensure license number and expiry date are readable.',
                  'Avoid glare from lights.',
                  'Do not crop important details.',
                ]);
              },
            ),

            const SizedBox(height: 14),
            _imageCard(
              title: "Roadtax",
              imageUrl: _roadtaxUrl,
              localFile: _roadtaxLocal,
              onPick: () async {
                await _pickDoc(
                  onPicked: (f) async {
                    setState(() => _roadtaxLocal = f);
                    await _uploadLicense();
                  },
                );
              },
              onRemove: _removeRoadtax,
              isPortrait: false,
              onShowTips: () {
                _showTipsDialog("Driver's Roadtax Tips", [
                  'Upload the full front of your roadtax.',
                  'Ensure roadtax and expiry date are readable.',
                  'Avoid glare from lights.',
                  'Do not crop important details.',
                ]);
              },
            ),
            const SizedBox(height: 14),
            // IC / Passport (landscape)
            _imageCard(
              title: 'IC / Passport (Optional)',
              imageUrl: _icUrl,
              localFile: _icLocal,
              onPick: () async {
                await _pickDoc(
                  onPicked: (f) async {
                    setState(() => _icLocal = f);
                    await _uploadIC();
                  },
                );
              },
              onRemove: _removeIC,
              isPortrait: false,
              onShowTips: () {
                _showTipsDialog('IC / Passport Tips', [
                  'Upload the full IC or passport page.',
                  'Ensure the text and photo are clear.',
                  'Avoid strong reflections.',
                  'Make sure nothing is cut off.',
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
