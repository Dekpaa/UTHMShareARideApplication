import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/auth/user_login_page.dart';
import 'package:uthmshareride/modules/Driver/car.dart';
import 'package:uthmshareride/modules/Driver/driver_earnings.dart';
import 'package:uthmshareride/modules/Driver/driver_profile.dart';
import 'package:uthmshareride/modules/Driver/rideshistory.dart';
import 'package:uthmshareride/modules/Driver/setting.dart';
import 'package:uthmshareride/modules/Payment/driver_info_payment.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class DriverAppDrawer extends StatefulWidget {
  const DriverAppDrawer({super.key});

  @override
  State<DriverAppDrawer> createState() => _DriverAppDrawerState();
}

class _DriverAppDrawerState extends State<DriverAppDrawer> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _handleLogout() async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const UserLoginPage(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.75, 
      child: Align(
        alignment: Alignment.topLeft,
        child: FractionallySizedBox(
          heightFactor: 0.90,
          alignment: Alignment.topLeft,
          child: Drawer(
            backgroundColor: hexStringToColor("365770"),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildProfileHeader(user),

                  Divider(
                    color: Colors.grey[300],
                    height: 1,
                    thickness: 1,
                    indent: 20,
                    endIndent: 20,
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildMenuItem(
                            icon: Icons.person,
                            title: "Profile",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverProfilePage(),
                                ),
                              );
                            },
                          ),

                          _buildMenuItem(
                            icon: Icons.directions_car,
                            title: "My Car",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyCarsPage(),
                                ),
                              );
                            },
                          ),

                          _buildMenuItem(
                            icon: Icons.qr_code,
                            title: "Payment Info",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverInfoPayment(),
                                ),
                              );
                            },
                          ),
                    _buildMenuItem(
                            icon: Icons.history,
                            title: "Rides History",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverRideHistoryPage(),
                                ),
                              );
                            },
                          ),
                      _buildMenuItem(
                            icon: Icons.money,
                            title: "Earnings",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverEarningsPage(),
                                ),
                              );
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.settings,
                            title: "Settings",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const DriverSettingsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(
                    color: Colors.white54,
                    height: 20,
                    thickness: 0.5,
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildMenuItem(
                      icon: Icons.logout,
                      title: "Logout",
                      color: Colors.redAccent,
                      onTap: _handleLogout,
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          "UTHM Share A Ride",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Driver",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= PROFILE HEADER =================

  Widget _buildProfileHeader(User? user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: user?.uid != null
          ? _firestore.collection('drivers').doc(user!.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        String displayName = "Driver Profile";
        String? photoUrl;
        String status = "pending";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['fullName'] ?? data['name'] ?? displayName;
          photoUrl = data['photoUrl'];
          status = data['status'] ?? "pending";
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverProfilePage(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  backgroundImage:
                      photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                  child: photoUrl == null || photoUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 48,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return Colors.green;
      case 'unverified':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }


  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: color ?? Colors.white,
          size: 22,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: color ?? Colors.white70,
      ),
      onTap: onTap,
    );
  }
}
