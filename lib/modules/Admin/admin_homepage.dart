import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uthmshareride/modules/Admin/drawer.dart';
import 'package:uthmshareride/modules/Admin/manage_driver.dart';
import 'package:uthmshareride/modules/Admin/manage_passenger.dart';
import 'package:uthmshareride/modules/Admin/rides_analytics.dart';
import 'package:uthmshareride/modules/Admin/user_analytics.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:intl/intl.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  bool _loading = true;
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalDrivers': 0,
    'totalPassengers': 0,
    'pendingDrivers': 0,
    'pendingPassengers': 0,
    'activeRides': 0,
    'completedRides': 0,
    'cancelledRides': 0,
    'totalEarnings': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _loading = true);
    try {
      // Fetch semua data secara parallel
      final futures = await Future.wait([
        _getTotalUsers(),
        _getTotalDrivers(),
        _getTotalPassengers(),
        _getPendingDrivers(),
        _getPendingPassengers(),
        _getActiveRides(),
        _getCompletedRides(),
        _getCancelledRides(),
        _getTotalEarnings(),
      ]);

      setState(() {
        _stats = {
          'totalUsers': futures[0],
          'totalDrivers': futures[1],
          'totalPassengers': futures[2],
          'pendingDrivers': futures[3],
          'pendingPassengers': futures[4],
          'activeRides': futures[5],
          'completedRides': futures[6],
          'cancelledRides': futures[7],
          'totalEarnings': futures[8],
        };
        _loading = false;
      });
    } catch (e) {
      print('Error loading dashboard stats: $e');
      setState(() => _loading = false);
    }
  }

  // ========== STATISTICS METHODS ==========

  Future<int> _getTotalUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting users: $e');
      return 0;
    }
  }

  Future<int> _getTotalDrivers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting drivers: $e');
      return 0;
    }
  }

  Future<int> _getTotalPassengers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('passengers')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting passengers: $e');
      return 0;
    }
  }

  Future<int> _getPendingDrivers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('drivers')
          .where('status', isEqualTo: 'pending')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting pending drivers: $e');
      return 0;
    }
  }

  Future<int> _getPendingPassengers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('passengers')
          .where('status', whereIn: ['pending', 'submitted'])
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting pending passengers: $e');
      return 0;
    }
  }

  Future<int> _getActiveRides() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'ongoing')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting active rides: $e');
      return 0;
    }
  }

  Future<int> _getCompletedRides() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'completed')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting completed rides: $e');
      return 0;
    }
  }

  Future<int> _getCancelledRides() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'cancelled')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error counting cancelled rides: $e');
      return 0;
    }
  }

  Future<double> _getTotalEarnings() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('paymentStatus', isEqualTo: 'approved')
          .get();
      
      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final fare = data['fare'] ?? 0;
        if (fare is num) {
          total += fare.toDouble();
        }
      }
      return total;
    } catch (e) {
      print('Error calculating earnings: $e');
      return 0.0;
    }
  }

  // ========== WIDGET COMPONENTS ==========

  Widget _statCard({
    required String title,
    required dynamic value,
    required IconData icon,
    required Color color,
    String? subtitle,
    String? prefix,
    String? suffix,
  }) {
    final displayValue = value?.toString() ?? '0';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.20),
            color.withOpacity(0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: color,
                  ),
                ),
                if (subtitle != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${prefix ?? ''}$displayValue${suffix ?? ''}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool hasNotification = false,
    int notificationCount = 0,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withOpacity(0.2),
                      color.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey[400],
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = '🌅 Good Morning';
    } else if (hour < 17) {
      greeting = '☀️ Good Afternoon';
    } else {
      greeting = '🌙 Good Evening';
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            hexStringToColor("365770"),
            hexStringToColor("2A4459"),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'UTHM Share A Ride',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Admin Dashboard',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formattedDate,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user,
                  color: Colors.white.withOpacity(0.8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Status: Active',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildStatsGrid() {
  final currencyFormat = NumberFormat.currency(
    symbol: 'RM',
    decimalDigits: 2,
  );

  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header dengan judul dan tombol refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 System Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _loadDashboardStats,
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: hexStringToColor("365770"),
                    size: 22,
                  ),
                  splashRadius: 20,
                  tooltip: 'Refresh Dashboard',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Grid statistik
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _statCard(
                title: 'Total Users',
                value: _stats['totalUsers'] ?? 0,
                icon: Icons.people,
                color: Colors.purple,
                subtitle: 'Registered',
              ),
              _statCard(
                title: 'Active Drivers',
                value: _stats['totalDrivers'] ?? 0,
                icon: Icons.directions_car_filled,
                color: Colors.blue,
                subtitle: 'Verified',
              ),
              _statCard(
                title: 'Active Passengers',
                value: _stats['totalPassengers'] ?? 0,
                icon: Icons.people_alt,
                color: Colors.green,
                subtitle: 'Registered',
              ),
              _statCard(
                title: 'Total Earnings',
                value: _stats['totalEarnings'] != null 
                    ? currencyFormat.format(_stats['totalEarnings'])
                    : 'RM 0.00',
                icon: Icons.attach_money,
                color: const Color.fromARGB(255, 204, 155, 11),
                subtitle: 'All Time',
              ),
              _statCard(
                title: 'Pending Verification',
                value: (_stats['pendingDrivers'] ?? 0) + (_stats['pendingPassengers'] ?? 0),
                icon: Icons.pending_actions,
                color: const Color.fromARGB(255, 225, 154, 48),
                subtitle: 'Awaiting',
              ),
              _statCard(
                title: 'Active Rides',
                value: _stats['activeRides'] ?? 0,
                icon: Icons.directions_car,
                color: Colors.teal,
                subtitle: 'On Going',
              ),
            ],
          ),
        ],
      ),
    ),
  );
}


  Widget _buildQuickActions() {
    final pendingDrivers = _stats['pendingDrivers'] ?? 0;
    final pendingPassengers = _stats['pendingPassengers'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          '🚀 Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _quickActionCard(
          title: 'Manage Drivers',
          description: 'Review driver information and manage driver accounts',
          icon: Icons.directions_car,
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminManageDriverPage(),
              ),
            );
          },
          hasNotification: pendingDrivers > 0,
          notificationCount: pendingDrivers,
        ),
        const SizedBox(height: 12),
        _quickActionCard(
          title: 'Manage Passengers',
          description: 'Manage passenger accounts',
          icon: Icons.people,
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminManagePassengerPage(),
              ),
            );
          },
          hasNotification: pendingPassengers > 0,
          notificationCount: pendingPassengers,
        ),
        const SizedBox(height: 12),
        _quickActionCard(
          title: 'Rides Analytics',
          description: 'Monitor ongoing, completed, and cancelled rides',
          icon: Icons.directions_car_filled,
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminRidesAnalyticsPage(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _quickActionCard(
          title: 'User Analytics',
          description: 'View detailed statistics and user insights',
          icon: Icons.analytics,
          color: Colors.amber,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AdminUserAnalyticsPage(),
              ),
            );
          },
        ),
      ],
    );
  }



  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hexStringToColor("365770").withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                hexStringToColor("365770"),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading Dashboard...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching system statistics',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexStringToColor("365770");
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 205, 220, 240),
      appBar: AppBar(
        backgroundColor: hexStringToColor("365770"),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white
          ),
        ),
      ),
      drawer: const AdminAppDrawer(),
      body: _loading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadDashboardStats,
              color: hexStringToColor("365770"),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatsGrid(),
                    _buildQuickActions(),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: hexStringToColor("365770"),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Dashboard updated: ${DateFormat('hh:mm a').format(DateTime.now())}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadDashboardStats,
                            child: Text(
                              'Refresh Now',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: hexStringToColor("365770"),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}