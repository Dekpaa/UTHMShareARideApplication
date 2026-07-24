import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class AdminUserAnalyticsPage extends StatefulWidget {
  const AdminUserAnalyticsPage({super.key});

  @override
  State<AdminUserAnalyticsPage> createState() => _AdminUserAnalyticsPageState();
}

class _AdminUserAnalyticsPageState extends State<AdminUserAnalyticsPage> {
  List<QueryDocumentSnapshot> _users = [];
  List<QueryDocumentSnapshot> _filteredUsers = [];
  bool _loading = false;
  String _selectedRole = 'all';
  
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'RM',
    decimalDigits: 2,
  );
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();
          
      setState(() {
        _users = snapshot.docs;
        _applyRoleFilter();
      });
    } catch (e) {
      _showError('Failed to load users: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyRoleFilter() {
    setState(() {
      _filteredUsers = _users.where((user) {
        final data = user.data() as Map<String, dynamic>;
        final role = (data['roles'] as List?)?.first?.toString() ?? 'passenger';
        
        if (_selectedRole == 'all') return true;
        if (_selectedRole == 'passenger') return role == 'passenger';
        if (_selectedRole == 'driver') return role == 'driver';
        return true;
      }).toList();
    });
  }

  // ========== DRIVER STATISTICS ==========
  Future<Map<String, dynamic>> _getDriverStats(String driverId) async {
    try {
      // Get completed rides from 'rides' collection
      final ridesQuery = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['completed', 'finished'])
          .get();
      
      // Get bookings for earnings
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('driverId', isEqualTo: driverId)
          .where('paymentStatus', isEqualTo: 'approved')
          .get();
      
      final totalRides = ridesQuery.docs.length;
      double totalEarnings = 0;
      
      // Calculate earnings from bookings
      final earningsByMonth = <String, double>{};
      
      // Process bookings for earnings
      for (final doc in bookingsQuery.docs) {
        final data = doc.data();
        final fare = (data['fare'] ?? 0).toDouble();
        totalEarnings += fare;
        
        final approvedAt = data['paymentApprovedAt'] as Timestamp?;
        if (approvedAt != null) {
          final date = approvedAt.toDate();
          final monthYear = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          earningsByMonth.update(
            monthYear, 
            (value) => value + fare, 
            ifAbsent: () => fare
          );
        }
      }
      
      // Get recent rides (last 5)
      final recentRides = ridesQuery.docs.take(5).map((doc) {
        final data = doc.data();
        return {
          'pickup': data['pickupLocation']?['name'] ?? 
                   data['start'] ?? 'Unknown',
          'dropoff': data['dropoffLocation']?['name'] ?? 
                    data['end'] ?? 'Unknown',
          'fare': (data['fare'] as num?)?.toDouble() ?? 0.0,
          'date': (data['completedAt'] as Timestamp?)?.toDate() ?? 
                  (data['createdAt'] as Timestamp?)?.toDate(),
          'status': data['status'] ?? 'completed',
        };
      }).toList();
      
      // Get cancelled rides
      final cancelledRides = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: ['cancelled', 'cancelled_by_driver', 'cancelled_by_passenger'])
          .get();
      
      final cancelledCount = cancelledRides.docs.length;
      
      return {
        'totalRides': totalRides,
        'totalEarnings': totalEarnings,
        'earningsByMonth': earningsByMonth,
        'recentRides': recentRides,
        'cancelledCount': cancelledCount,
        'bookingsCount': bookingsQuery.docs.length,
      };
    } catch (e) {
      return {
        'totalRides': 0,
        'totalEarnings': 0.0,
        'earningsByMonth': {},
        'recentRides': [],
        'cancelledCount': 0,
        'bookingsCount': 0,
      };
    }
  }

  // ========== PASSENGER STATISTICS ==========
  Future<Map<String, dynamic>> _getPassengerStats(String passengerId) async {
    try {
      print('🔄 Getting passenger stats for: $passengerId');
      
      // Check bookings collection (utama)
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: passengerId)
          .get();
      
      print('📊 Total bookings found: ${bookingsQuery.docs.length}');
      
      // Kelompokkan bookings berdasarkan status
      int totalBookings = 0;
      int completedBookings = 0;
      int cancelledBookings = 0;
      int pendingBookings = 0;
      
      // Recent bookings (last 5)
      final recentBookings = <Map<String, dynamic>>[];
      
      for (final doc in bookingsQuery.docs) {
        final data = doc.data();
        final bookingId = doc.id;
        totalBookings++;
        
        final status = data['status']?.toString() ?? '';
        final paymentStatus = data['paymentStatus']?.toString() ?? 'none';
        
        if (paymentStatus == 'approved') {
          completedBookings++;
        } else if (status == 'cancelled' || status == 'rejected') {
          cancelledBookings++;
        } else {
          pendingBookings++;
        }
        
        // Add to recent bookings
        if (recentBookings.length < 5) {
          // Get ride info
          final rideId = data['rideId'];
          if (rideId != null) {
            try {
              final rideDoc = await FirebaseFirestore.instance
                  .collection('rides')
                  .doc(rideId)
                  .get();
              
              if (rideDoc.exists) {
                final rideData = rideDoc.data()!;
                recentBookings.add({
                  'id': bookingId,
                  'pickup': rideData['pickupLocation']?['name'] ?? 
                           rideData['start'] ?? 'Unknown',
                  'dropoff': rideData['dropoffLocation']?['name'] ?? 
                            rideData['end'] ?? 'Unknown',
                  'fare': (data['fare'] ?? 0).toDouble(),
                  'date': (data['createdAt'] as Timestamp?)?.toDate() ?? 
                          (rideData['createdAt'] as Timestamp?)?.toDate(),
                  'status': status,
                  'paymentStatus': paymentStatus,
                  'driverId': rideData['driverId'],
                });
              }
            } catch (e) {
              print('⚠️ Error getting ride info: $e');
            }
          }
        }
      }
      
      print('✅ Completed bookings: $completedBookings');
      print('✅ Cancelled bookings: $cancelledBookings');
      print('✅ Pending bookings: $pendingBookings');
      
      return {
        'totalBookings': totalBookings,
        'completedBookings': completedBookings,
        'cancelledBookings': cancelledBookings,
        'pendingBookings': pendingBookings,
        'recentBookings': recentBookings,
      };
    } catch (e) {
      print('❌ Error getting passenger stats: $e');
      return {
        'totalBookings': 0,
        'completedBookings': 0,
        'cancelledBookings': 0,
        'pendingBookings': 0,
        'recentBookings': [],
      };
    }
  }

  // ========== VIEW USER DETAILS ==========
  Future<void> _viewUserDetails(QueryDocumentSnapshot userDoc) async {
    final data = userDoc.data() as Map<String, dynamic>;
    final role = (data['roles'] as List?)?.first?.toString() ?? 'passenger';
    final userId = userDoc.id;
    
    setState(() => _loading = true);
    
    try {
      Map<String, dynamic> stats = {};
      
      if (role == 'driver') {
        stats = await _getDriverStats(userId);
      } else if (role == 'passenger') {
        stats = await _getPassengerStats(userId);
      }
      
      setState(() => _loading = false);
      
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 5),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getRoleColor(role).withOpacity(0.1),
                            Colors.white,
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: _getRoleColor(role),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: _getRoleColor(role).withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                role == 'driver' ? Icons.directions_car : 
                                role == 'passenger' ? Icons.person : Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['fullName'] ?? 'No Name',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['email'] ?? 'No Email',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(role).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _getRoleColor(role).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    role.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getRoleColor(role),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Statistics Section
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Statistics Title
                            Text(
                              role == 'driver' ? 'DRIVER STATISTICS' : 'PASSENGER STATISTICS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getRoleColor(role),
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 40,
                              height: 3,
                              color: _getRoleColor(role),
                            ),
                            const SizedBox(height: 25),
                            
                            if (role == 'driver') ...[
                              // DRIVER STATS
                              Row(
                                children: [
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.directions_car,
                                      iconColor: Colors.blue,
                                      title: 'Total Rides',
                                      value: '${stats['totalRides']}',
                                      subtitle: 'Completed trips',
                                      bgColor: Colors.blue.withOpacity(0.05),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.attach_money,
                                      iconColor: Colors.green,
                                      title: 'Total Earnings',
                                      value: _currencyFormat.format(stats['totalEarnings']),
                                      subtitle: 'All time',
                                      bgColor: Colors.green.withOpacity(0.05),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 15),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.book,
                                      iconColor: Colors.purple,
                                      title: 'Bookings',
                                      value: '${stats['bookingsCount']}',
                                      subtitle: 'Approved bookings',
                                      bgColor: Colors.purple.withOpacity(0.05),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.cancel,
                                      iconColor: Colors.red,
                                      title: 'Cancelled',
                                      value: '${stats['cancelledCount']}',
                                      subtitle: 'Cancelled rides',
                                      bgColor: Colors.red.withOpacity(0.05),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Earnings by Month
                              if ((stats['earningsByMonth'] as Map).isNotEmpty) ...[
                                const SizedBox(height: 25),
                                _sectionTitle('Earnings by Month'),
                                ...(stats['earningsByMonth'] as Map<String, double>)
                                  .entries
                                  .toList()
                                  .reversed
                                  .take(6)
                                  .map((entry) => _monthlyEarningItem(entry))
                                  .toList(),
                              ],
                              
                              // Recent Rides
                              if ((stats['recentRides'] as List).isNotEmpty) ...[
                                const SizedBox(height: 25),
                                _sectionTitle('Recent Rides'),
                                ...(stats['recentRides'] as List<dynamic>)
                                  .map((ride) => _rideItem(ride, true))
                                  .toList(),
                              ],
                            ] 
                            
                            else if (role == 'passenger') ...[
                              // PASSENGER STATS
                              Row(
                                children: [
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.book,
                                      iconColor: Colors.green,
                                      title: 'Total Bookings',
                                      value: '${stats['totalBookings']}',
                                      subtitle: 'All bookings',
                                      bgColor: Colors.green.withOpacity(0.05),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.check_circle,
                                      iconColor: Colors.green,
                                      title: 'Completed',
                                      value: '${stats['completedBookings']}',
                                      subtitle: 'Approved bookings',
                                      bgColor: Colors.green.withOpacity(0.05),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 15),
                              
                              Row(
                                children: [
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.pending,
                                      iconColor: Colors.orange,
                                      title: 'Pending',
                                      value: '${stats['pendingBookings']}',
                                      subtitle: 'Awaiting approval',
                                      bgColor: Colors.orange.withOpacity(0.05),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: _statCardMini(
                                      icon: Icons.cancel,
                                      iconColor: Colors.red,
                                      title: 'Cancelled',
                                      value: '${stats['cancelledBookings']}',
                                      subtitle: 'Cancelled bookings',
                                      bgColor: Colors.red.withOpacity(0.05),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // Recent Bookings
                              if ((stats['recentBookings'] as List).isNotEmpty) ...[
                                const SizedBox(height: 25),
                                _sectionTitle('Recent Bookings'),
                                ...(stats['recentBookings'] as List<dynamic>)
                                  .map((booking) => _bookingItem(booking))
                                  .toList(),
                              ],
                            ]
                            
                            else ...[
                              // ADMIN OR OTHER ROLES
                              Container(
                                height: 150,
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bar_chart,
                                      size: 50,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No statistics available',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      setState(() => _loading = false);
      _showError('Failed to load statistics: $e');
    }
  }

  // ========== HELPER WIDGETS ==========
  Widget _statCardMini({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _monthlyEarningItem(MapEntry<String, double> entry) {
    final month = entry.key.split('-');
    final monthName = DateFormat('MMM yyyy').format(
      DateTime(int.parse(month[0]), int.parse(month[1]))
    );
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calendar_today, size: 16, color: Colors.green),
              ),
              const SizedBox(width: 10),
              Text(
                monthName,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            _currencyFormat.format(entry.value),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideItem(Map<String, dynamic> ride, bool isDriver) {
    final date = ride['date'] as DateTime?;
    final fare = (ride['fare'] as num?)?.toDouble() ?? 0.0;
    final status = ride['status'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.red[300]),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            ride['pickup'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.green[300]),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            ride['dropoff'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currencyFormat.format(fare),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          
          if (status != null && status.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status == 'completed' ? Colors.green.withOpacity(0.1) : 
                       status.contains('cancelled') ? Colors.red.withOpacity(0.1) : 
                       Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: status == 'completed' ? Colors.green : 
                         status.contains('cancelled') ? Colors.red : 
                         Colors.orange,
                ),
              ),
            ),
          ],
          
          if (date != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 5),
                Text(
                  _dateFormat.format(date),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bookingItem(Map<String, dynamic> booking) {
    final date = booking['date'] as DateTime?;
    final fare = (booking['fare'] as num?)?.toDouble() ?? 0.0;
    final status = booking['status'] as String?;
    final paymentStatus = booking['paymentStatus'] as String?;
    
    Color statusColor = Colors.grey;
    String statusText = 'Unknown';
    
    if (paymentStatus == 'approved') {
      statusColor = Colors.green;
      statusText = 'Completed';
    } else if (status == 'cancelled' || status == 'rejected') {
      statusColor = Colors.red;
      statusText = 'Cancelled';
    } else if (paymentStatus == 'submitted' || paymentStatus == 'pending') {
      statusColor = Colors.orange;
      statusText = 'Pending Payment';
    } else {
      statusColor = Colors.blue;
      statusText = 'Active';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.red[300]),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            booking['pickup'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.green[300]),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            booking['dropoff'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currencyFormat.format(fare),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              
              if (paymentStatus != null && paymentStatus != 'none') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: paymentStatus == 'approved' ? Colors.green.withOpacity(0.1) :
                           paymentStatus == 'rejected' ? Colors.red.withOpacity(0.1) :
                           Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: paymentStatus == 'approved' ? Colors.green.withOpacity(0.3) :
                             paymentStatus == 'rejected' ? Colors.red.withOpacity(0.3) :
                             Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    paymentStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: paymentStatus == 'approved' ? Colors.green :
                             paymentStatus == 'rejected' ? Colors.red :
                             Colors.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          if (date != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 5),
                Text(
                  _dateFormat.format(date),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return Colors.red;
      case 'driver': return Colors.blue;
      default: return Colors.green;
    }
  }

  Widget _buildRoleFilter() {
    final bgColor = hexStringToColor("365770");
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _filterChip('All', 'all', Colors.grey),
          const SizedBox(width: 10),
          _filterChip('Passenger', 'passenger', Colors.green),
          const SizedBox(width: 10),
          _filterChip('Driver', 'driver', Colors.blue),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, Color bgColor) {
    final isSelected = _selectedRole == value;
    final roleColor = _getRoleColor(value == 'all' ? 'passenger' : value);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = value;
          _applyRoleFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected ? [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ] : null,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 1 : 0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot userDoc) {
    final data = userDoc.data() as Map<String, dynamic>;
    final name = data['fullName'] ?? 'No Name';
    final role = (data['roles'] as List?)?.first?.toString() ?? 'passenger';
    final email = data['email'] ?? 'No Email';
    final phone = data['phone']?.toString() ?? '';
    final matric = data['matricNo']?.toString() ?? '';
    final createdAt = data['createdAt'] as Timestamp?;
    
    final roleColor = _getRoleColor(role);
    final bgColor = hexStringToColor("365770");
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _viewUserDetails(userDoc),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                // Role Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: roleColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: roleColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      role == 'driver' ? Icons.directions_car : 
                      role == 'passenger' ? Icons.person : Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: roleColor),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (matric.isNotEmpty) ...[
                            Icon(Icons.badge, size: 12, color: bgColor),
                            const SizedBox(width: 4),
                            Text(
                              matric,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 15),
                          ],
                          if (phone.isNotEmpty) ...[
                            Icon(Icons.phone, size: 12, color: bgColor),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: bgColor),
                            const SizedBox(width: 4),
                            Text(
                              'Joined ${DateFormat('dd/MM/yyyy').format(createdAt.toDate())}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Arrow
                Icon(Icons.chevron_right, color: bgColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    final bgColor = hexStringToColor("365770");
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexStringToColor("365770");
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: bgColor,
        title: const Text(
          "User Analytics",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, size: 22, color: Colors.white),
            ),
            onPressed: _loadUsers,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Role Filter
          _buildRoleFilter(),
          
          // User Count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${_filteredUsers.length} users',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Tap to view statistics',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 5),
          
          // Users List
          Expanded(
            child: _loading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(bgColor),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading users...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _selectedRole == 'all' 
                                ? 'No users found'
                                : 'No ${_selectedRole}s found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Users will appear here once registered',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: bgColor,
                        backgroundColor: Colors.white,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            return _buildUserCard(_filteredUsers[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}