import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class AdminRidesAnalyticsPage extends StatefulWidget {
  const AdminRidesAnalyticsPage({super.key});

  @override
  State<AdminRidesAnalyticsPage> createState() => _AdminRidesAnalyticsPageState();
}

class _AdminRidesAnalyticsPageState extends State<AdminRidesAnalyticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<QuerySnapshot>? _ridesSub;

  final List<Ride> _allRides = [];
  final Map<String, String> _driverNames = {};
  final Map<String, String> _passengerNames = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _listenAllRides();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ridesSub?.cancel();
    super.dispose();
  }

  // ================= LISTEN ALL RIDES =================
  void _listenAllRides() {
    _ridesSub = FirebaseFirestore.instance
        .collection('rides')
        .snapshots()
        .listen((snapshot) {
      final rides = snapshot.docs
          .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
          .toList();

      setState(() {
        _allRides
          ..clear()
          ..addAll(rides);
      });

      for (final ride in rides) {
        _fetchDriverName(ride.driverId);
        for (final booking in ride.bookings) {
          _fetchPassengerName(booking.passengerId);
        }
      }
    });
  }

  // ================= FETCH DRIVER =================
  Future<void> _fetchDriverName(String driverId) async {
    if (_driverNames.containsKey(driverId)) return;

    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .get();

    setState(() {
      _driverNames[driverId] = doc.data()?['fullName'] ?? 'Driver';
    });
  }

  // ================= FETCH PASSENGER =================
  Future<void> _fetchPassengerName(String passengerId) async {
    if (_passengerNames.containsKey(passengerId)) return;

    final doc = await FirebaseFirestore.instance
        .collection('passengers')
        .doc(passengerId)
        .get();

    setState(() {
      _passengerNames[passengerId] =
          doc.data()?['fullName'] ?? 'Passenger';
    });
  }

  // ================= FILTER =================
  List<Ride> _filterRides(String type) {
    return _allRides.where((ride) {
      if (type == 'ongoing') return ride.status == 'ongoing';
      if (type == 'pending') {
        return ride.bookings.any(
          (b) => b.status == BookingStatus.pending,
        );
      }
      if (type == 'completed') return ride.status == 'completed';
      if (type == 'cancelled') return ride.status.startsWith('cancelled');
      return false;
    }).toList();
  }

  // ================= UI CARD =================
  Widget _buildRideList(List<Ride> rides) {
    if (rides.isEmpty) {
      return const Center(
        child: Text(
          'No rides found',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rides.length,
      itemBuilder: (context, index) {
        final ride = rides[index];
        final driverName = _driverNames[ride.driverId] ?? 'Driver';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= HEADER =================
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.car_rental,
                          size: 20,
                          color: _getStatusColor(ride.status),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ride ID: ${ride.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(ride.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ride.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(ride.status),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ================= ROUTE (FROM ATAS → TO BAWAH) =================
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FROM',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                              Text(ride.start,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TO',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600)),
                              Text(ride.end,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ================= DETAILS =================
                Row(
                  children: [
                    _infoItem(Icons.calendar_today, 'Date', ride.date,
                        Colors.black),
                    _infoItem(Icons.access_time, 'Time', ride.time,
                        Colors.black),
                    _infoItem(Icons.attach_money, 'Fare',
                        'RM ${ride.fare.toStringAsFixed(2)}', Colors.green),
                  ],
                ),

                const SizedBox(height: 12),

                // ================= DRIVER =================
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.black),
                    const SizedBox(width: 6),
                    Text('Driver: ',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600)),
                    Text(driverName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),

                // ================= PASSENGERS =================
                if (ride.bookings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.people,
                          size: 16, color: Colors.black),
                      const SizedBox(width: 6),
                      Text(
                        'Passengers (${ride.bookings.length})',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  ...ride.bookings.map((b) {
                    final name =
                        _passengerNames[b.passengerId] ?? 'Passenger';
                    return Padding(
                      padding:
                          const EdgeInsets.only(left: 22, top: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text('• $name')),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getBookingStatusColor(b.status)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              b.status.name.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _getBookingStatusColor(b.status)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoItem(
      IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'ongoing':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Color _getBookingStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text(
          'Rides Analytics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(
              fontSize: 13, // Perkecil font
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 13, // Perkecil font
              fontWeight: FontWeight.w500,
            ),
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: Container(
        color: bg,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildRideList(_filterRides('ongoing')),
            _buildRideList(_filterRides('pending')),
            _buildRideList(_filterRides('completed')),
            _buildRideList(_filterRides('cancelled')),
          ],
        ),
      ),
    );
  }
}
