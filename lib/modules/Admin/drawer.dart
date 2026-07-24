import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/auth/user_login_page.dart';
import 'package:uthmshareride/modules/Admin/rides_analytics.dart';
import 'package:uthmshareride/modules/Admin/setting.dart';
import 'package:uthmshareride/modules/Admin/user_analytics.dart';
import 'package:uthmshareride/modules/Admin/manage_driver.dart';
import 'package:uthmshareride/modules/Admin/manage_passenger.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class AdminAppDrawer extends StatefulWidget {
  const AdminAppDrawer({super.key});

  @override
  State<AdminAppDrawer> createState() => _AdminAppDrawerState();
}

class _AdminAppDrawerState extends State<AdminAppDrawer> {
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
                  const Divider(
                    color: Colors.white54,
                    height: 1,
                    thickness: 0.5,
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
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                            child: Text(
                              "USER MANAGEMENT",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          _buildMenuItem(
                            icon: Icons.person,
                            title: "Manage driver",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminManageDriverPage(),
                                ),
                              );
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.people_alt,
                            title: "Manage passenger",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminManagePassengerPage(),
                                ),
                              );
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                            child: Text(
                              "VIEW ANALYTICS REPORT",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          _buildMenuItem(
                            icon: Icons.account_balance,
                            title: "User Analytics",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminUserAnalyticsPage(),
                                ),
                              );
                            },
                          ),
                      _buildMenuItem(
                            icon: Icons.directions_car,
                            title: "Rides Analytics",
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminRidesAnalyticsPage(),
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
                                  builder: (_) => const AdminSettingsPage(),
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
                    height: 1,
                    thickness: 0.5,
                    indent: 20,
                    endIndent: 20,
                  ),

                  // Logout button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: _buildMenuItem(
                      icon: Icons.logout,
                      title: "Logout",
                      color: Colors.redAccent,
                      onTap: _handleLogout,
                    ),
                  ),

                  // Footer
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          "UTHM Share A Ride",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Admin Panel",
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

  // Build Profile Header
  Widget _buildProfileHeader(User? user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: user?.uid != null
          ? _firestore.collection('admins').doc(user!.uid).snapshots()
          : null,
      builder: (context, snapshot) {
        String displayName = "Admin";

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          displayName = data['fullName'] ?? data['name'] ?? displayName;
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          child: Column(
            children: [

              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Admin name
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

              const SizedBox(height: 12),

              // Admin badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green,
                    width: 1,
                  ),
                ),
                child: const Text(
                  "ADMINISTRATOR",
                  style: TextStyle(
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

  // Build Menu Item
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    Color? color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
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
          size: 18,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        tileColor: Colors.transparent,
        hoverColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}