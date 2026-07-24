import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class AdminManageDriverPage extends StatefulWidget {
  const AdminManageDriverPage({super.key});

  @override
  State<AdminManageDriverPage> createState() => _AdminManageDriverPageState();
}

class _AdminManageDriverPageState extends State<AdminManageDriverPage> {
  String _statusFilter = 'all';
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    switch (s) {
      case 'verified':
        return Colors.green;
      case 'unverified':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _statusChip(String status) {
    final bg = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        (status.isEmpty ? 'PENDING' : status.toUpperCase()),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _updateDriverStatus(String driverId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .update({
            'status': newStatus,
            'lastUpdated': FieldValue.serverTimestamp()
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDriverDetails(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final fullName = (data['fullName'] ?? '') as String;
    final email = (data['email'] ?? '') as String;
    final phone = (data['phone'] ?? '') as String;
    final matricNo = (data['matricNo'] ?? '') as String;
    final gender = (data['gender'] ?? '') as String;
    final address = (data['address'] ?? '') as String;
    final status = (data['status'] ?? 'pending') as String;
    final matricCardUrl = (data['matricCardUrl'] ?? '') as String;
    final licenseUrl = (data['licenseUrl'] ?? '') as String;
    final roadtaxUrl = (data['roadtaxUrl'] ?? '') as String;
    final icUrl = (data['icUrl'] ?? '') as String;
    final photoUrl = (data['photoUrl'] ?? '') as String;
    final createdAt = data['createdAt'] as Timestamp?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.95,
          initialChildSize: 0.85,
          minChildSize: 0.6,
          builder: (context, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.grey[200],
                        child: ClipOval(
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: photoUrl.isNotEmpty
                                ? Image.network(
                                    photoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.person),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.grey[600],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.isEmpty ? '-' : fullName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _statusChip(status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  const SizedBox(height: 8),
                  Text(
                    'Driver Information',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoRow(Icons.phone, 'Phone Number', phone),
                  _infoRow(Icons.credit_card, 'Matric Number', matricNo),
                  _infoRow(Icons.transgender, 'Gender', gender),
                  _infoRow(Icons.home, 'Address', address),
                  
                  if (createdAt != null)
                    _infoRow(
                      Icons.calendar_today,
                      'Registered Date',
                      '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} ${createdAt.toDate().hour}:${createdAt.toDate().minute.toString().padLeft(2, '0')}',
                    ),

                  const SizedBox(height: 16),
                  Text(
                    'Driver Documents',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),

                  _docPreviewCard(
                    title: 'Student Matric Card (Portrait)',
                    url: matricCardUrl,
                    isPortrait: true,
                  ),
                  const SizedBox(height: 12),
                  _docPreviewCard(
                    title: "Driver's License (Landscape)",
                    url: licenseUrl,
                    isPortrait: false,
                  ),
                  const SizedBox(height: 12),
                  _docPreviewCard(
                    title: "Roadtax (Landscape)",
                    url: roadtaxUrl,
                    isPortrait: false,
                  ),
                  const SizedBox(height: 12),
                  _docPreviewCard(
                    title: 'IC/Passport (Optional)',
                    url: icUrl,
                    isPortrait: false,
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _updateDriverStatus(doc.id, 'pending'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Set Pending',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateDriverStatus(doc.id, 'verified'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _updateDriverStatus(doc.id, 'unverified'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Unverified',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docPreviewCard({
    required String title,
    required String url,
    required bool isPortrait,
  }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: isPortrait ? (3 / 4) : (16 / 9),
                child: Container(
                  color: Colors.grey[200],
                  child: url.isEmpty
                      ? Center(
                          child: Text(
                            'No image uploaded',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                insetPadding: const EdgeInsets.all(12),
                                backgroundColor: Colors.black,
                                child: InteractiveViewer(
                                  child: Center(
                                    child: Image.network(
                                      url,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.broken_image,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Center(child: Icon(Icons.broken_image)),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text(
          'Manage Drivers',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: bg,
            child: Column(
              children: [
              // Search Bar dengan background putih
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email or matric number...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[700]),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: hexStringToColor("365770")),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
                const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          size: 18,
                          color: hexStringToColor("365770"),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filter Status:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: _statusFilter,
                          underline: Container(),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: hexStringToColor("365770"),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Row(
                                children: [
                                  SizedBox(width: 6),
                                  Text('All'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'pending',
                              child: Row(
                                children: [
                                  Icon(Icons.pending, size: 16, color: Colors.orange),
                                  SizedBox(width: 6),
                                  Text('Pending'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'verified',
                              child: Row(
                                children: [
                                  Icon(Icons.verified, size: 16, color: Colors.green),
                                  SizedBox(width: 6),
                                  Text('Verified'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'unverified',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel, size: 16, color: Colors.red),
                                  SizedBox(width: 6),
                                  Text('Unverified'),
                                ],
                              ),
                            ),
                          ],
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _statusFilter = v;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
              ],
            ),
          ),

          // Drivers List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading drivers',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(bg),
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data();
                  
                  // Apply status filter
                  if (_statusFilter != 'all') {
                    final status = (data['status'] ?? 'pending')
                        .toString()
                        .toLowerCase();
                    if (status != _statusFilter) return false;
                  }
                  
                  // Apply search filter
                  if (_searchQuery.isNotEmpty) {
                    final fullName = (data['fullName'] ?? '')
                        .toString()
                        .toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    final matricNo = (data['matricNo'] ?? '').toString().toLowerCase();
                    final phone = (data['phone'] ?? '').toString().toLowerCase();
                    
                    if (!fullName.contains(_searchQuery) &&
                        !email.contains(_searchQuery) &&
                        !matricNo.contains(_searchQuery) &&
                        !phone.contains(_searchQuery)) {
                      return false;
                    }
                  }
                  
                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.drive_eta_outlined,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No drivers found for "$_searchQuery"'
                              : 'No drivers found for this filter',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data();
                    final fullName = (data['fullName'] ?? '') as String;
                    final email = (data['email'] ?? '') as String;
                    final phone = (data['phone'] ?? '') as String;
                    final matricNo = (data['matricNo'] ?? '') as String;
                    final status = (data['status'] ?? 'pending') as String;
                    final photoUrl = (data['photoUrl'] ?? '') as String;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _showDriverDetails(doc),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey[300],
                                child: photoUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          photoUrl,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Text(
                                            fullName.isEmpty
                                                ? '?'
                                                : fullName.trim()[0].toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Text(
                                        fullName.isEmpty
                                            ? '?'
                                            : fullName.trim()[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName.isEmpty ? '-' : fullName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (matricNo.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(Icons.badge, size: 12, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                matricNo,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (phone.isNotEmpty && matricNo.isNotEmpty)
                                          const SizedBox(width: 8),
                                        if (phone.isNotEmpty)
                                          Row(
                                            children: [
                                              Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                phone,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _statusChip(status),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}