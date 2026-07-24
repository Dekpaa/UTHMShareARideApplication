import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uthmshareride/Component/Universal_nav_bar.dart';
import 'package:uthmshareride/auth/user_login_page.dart';
import 'package:uthmshareride/modules/Message/listchatdriver.dart';
import 'package:uthmshareride/modules/Passenger/drawer.dart';
import 'package:uthmshareride/modules/Passenger/passangerhomepage.dart';
import 'package:uthmshareride/modules/Payment/passenger_paymentpage.dart';
import 'package:uthmshareride/modules/Payment/passenger_paymentscreen.dart';
import 'package:uthmshareride/modules/Rating/passenger_rating_page.dart';
import 'package:uthmshareride/modules/ShareRide/myrides.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/modules/Trackride/passenger_trackride.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class MyBookingsPage extends StatefulWidget {
  final int initialTabIndex;
  const MyBookingsPage({super.key, this.initialTabIndex = 0});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 1;
  String? _currentPassengerId;
  String _currentPassengerName = "Passenger";

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridesSub;
  final List<Ride> _rides = [];
  final Map<String, String> _driverNames = {};
  final Set<String> _requestedDriverIds = {};

  StreamSubscription<QuerySnapshot>? _bookingsSub;
  final Map<String, Map<String, dynamic>> _bookingDetails = {};
  final Set<String> _ratingDialogsShown = {};

  @override
  void initState() {
    super.initState();
    print('🚀 MyBookingsPage initialized');
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_handleTabChange);
    _initUserAndListenRides();
    _initUserAndListenBookings();
    
    // Debug: Check rejected payments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugCheckRejectedPayments();
    });
  }

  Future<void> _debugCheckRejectedPayments() async {
    if (_currentPassengerId == null) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: _currentPassengerId)
          .where('paymentStatus', isEqualTo: 'rejected')
          .get();
      
      print('🔍 Debug - Rejected payments found: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        print('   - Booking ID: ${doc.id}');
        print('   - Reason: ${doc.data()['rejectionReason']}');
        print('   - Rejected At: ${doc.data()['paymentRejectedAt']}');
      }
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  void _handleTabChange() {
    if (_tabController.index == 1) {
      _refreshPaymentData();
    }
    if (_tabController.index == 2) {
      _buildCompletedBookingsContent();
    }
  }

  void _refreshPaymentData() {
    setState(() {});
  }

  Widget _buildDateTimeFare(Ride ride, {Color? fareColor}) {
    final fareClr = fareColor ?? Colors.green[700];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Date: ${ride.date}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.access_time, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Time: ${ride.time}',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.attach_money, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              'Fare: RM ${ride.fare.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                color: fareClr,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return PassengerHomepage();
      case 1:
        return const MyRidesPage();
      case 2:
        return const ListChatDriverPage();
      default:
        return PassengerHomepage();
    }
  }

  DateTime? _parseRideDateTime(Ride ride) {
    try {
      final dateParts = ride.date.split('/');
      if (dateParts.length != 3) return null;
      
      final timeParts = ride.time.split(':');
      if (timeParts.length < 2) return null;
      
      final day = int.tryParse(dateParts[0]);
      final month = int.tryParse(dateParts[1]);
      final year = int.tryParse(dateParts[2]);
      final hour = int.tryParse(timeParts[0]);
      final minute = int.tryParse(timeParts[1]);
      
      if (day == null || month == null || year == null || 
          hour == null || minute == null) {
        return null;
      }
      
      return DateTime(year, month, day, hour, minute);
    } catch (e) {
      print('Error parsing date/time: $e');
      return null;
    }
  }

  List<Ride> _sortRidesByDateTime(List<Ride> rides, {bool ascending = false}) {
    return List.from(rides)
      ..sort((a, b) {
        final dateTimeA = _parseRideDateTime(a);
        final dateTimeB = _parseRideDateTime(b);
        
        if (dateTimeA != null && dateTimeB != null) {
          return ascending 
              ? dateTimeA.compareTo(dateTimeB)
              : dateTimeB.compareTo(dateTimeA);
        }
        
        if (dateTimeA == null && dateTimeB != null) {
          return ascending ? 1 : -1;
        }
        if (dateTimeA != null && dateTimeB == null) {
          return ascending ? -1 : 1;
        }
        
        return a.id.compareTo(b.id);
      });
  }

  Future<void> _initUserAndListenRides() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserLoginPage()),
        );
      }
      return;
    }

    _currentPassengerId = user.uid;
    print('👤 Current passenger ID: $_currentPassengerId');
    
    FirebaseFirestore.instance
        .collection('passengers')
        .doc(_currentPassengerId)
        .get()
        .then((doc) {
          if (!mounted) return;
          if (doc.exists) {
            setState(() {
              _currentPassengerName =
                  (doc.data()?['fullName'] ?? 'Passenger').toString();
            });
          }
        })
        .catchError((_) {});

    _ridesSub = FirebaseFirestore.instance
        .collection('rides')
        .snapshots()
        .listen((snapshot) {
          final List<Ride> newRides =
              snapshot.docs
                  .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
                  .toList();

          if (!mounted) return;

          setState(() {
            _rides
              ..clear()
              ..addAll(newRides);
          });

          for (final ride in newRides) {
            _fetchDriverName(ride.driverId);
          }
        });
  }

  Future<void> _initUserAndListenBookings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('passengerId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
          print('📊 Bookings update received: ${snapshot.docs.length} documents');
          
          for (var doc in snapshot.docs) {
            final data = doc.data();
            print('🔍 Booking ID: ${doc.id}');
            print('   Payment Status: ${data['paymentStatus']}');
            print('   Rejection Reason: ${data['rejectionReason']}');
            print('   Rejected At: ${data['paymentRejectedAt']}');
          }
          
          if (!mounted) return;
          setState(() {
            _bookingDetails.clear();
            for (var doc in snapshot.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final bookingId = doc.id;

              _bookingDetails[bookingId] = {...data, 'id': bookingId};

              final rideId = data['rideId'];
              final passengerId = data['passengerId'];
              if (rideId != null && passengerId != null) {
                final combinedId = '${rideId}_$passengerId';
                _bookingDetails[combinedId] = {...data, 'id': bookingId};
              }
            }
          });
        });
  }

  void _handleAutoRating(String bookingId, Map<String, dynamic> bookingData) {
  }

  Future<void> _fetchDriverName(String driverId) async {
    if (driverId.isEmpty) return;

    if (_driverNames.containsKey(driverId) ||
        _requestedDriverIds.contains(driverId)) {
      return;
    }

    _requestedDriverIds.add(driverId);

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(driverId)
              .get();

      String name = 'Driver';
      if (doc.exists) {
        name = (doc.data()?['fullName'] ?? 'Driver').toString();
      }

      if (!mounted) return;
      setState(() {
        _driverNames[driverId] = name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _driverNames[driverId] = 'Driver';
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _ridesSub?.cancel();
    _bookingsSub?.cancel();
    super.dispose();
  }

  void _cancelBooking(String rideId, String bookingId) {
    final bg = hexStringToColor("365770");
    
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Cancel Booking',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Are you sure you want to cancel this booking?',
              style: TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'No',
                  style: TextStyle(color: bg),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseFirestore.instance
                        .collection('bookings')
                        .doc(bookingId)
                        .update({
                          'status': 'cancelled',
                          'cancelledAt': FieldValue.serverTimestamp(),
                        });

                    await RideStorage().updateBookingStatus(
                      rideId,
                      bookingId,
                      BookingStatus.cancelled,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Booking Cancelled!'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error cancelling booking: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Yes, Cancel'),
              ),
            ],
          ),
    );
  }

  String _getPaymentStatus(String bookingId) {
    var bookingData = _bookingDetails[bookingId];
    
    if (bookingData == null) {
      for (final ride in _rides) {
        for (final booking in ride.bookings) {
          if (booking.id == bookingId) {
            final combinedId = '${ride.id}_${booking.passengerId}';
            bookingData = _bookingDetails[combinedId];
            if (bookingData != null) break;
          }
        }
        if (bookingData != null) break;
      }
    }
    
    if (bookingData == null && _currentPassengerId != null) {
      for (final entry in _bookingDetails.entries) {
        if (entry.value['passengerId'] == _currentPassengerId) {
          bookingData = entry.value;
          break;
        }
      }
    }

    if (bookingData == null) {
      return 'none';
    }

    final paymentStatus = bookingData['paymentStatus']?.toString() ?? 'none';
    return paymentStatus;
  }

  String? _getReceiptUrl(String bookingId) {
    final bookingData = _bookingDetails[bookingId];
    if (bookingData == null) return null;
    return bookingData['receiptUrl'];
  }

  List<Ride> _getSortedActiveBookings() {
    if (_currentPassengerId == null) return [];
    
    final activeRides = _rides.where((ride) {
      return ride.bookings.any((booking) {
        if (booking.passengerId != _currentPassengerId) {
          return false;
        }
        
        if (booking.status != BookingStatus.accepted) {
          return false;
        }
        
        final paymentStatus = _getPaymentStatus(booking.id);
        final bool hasNotPaid = paymentStatus == 'none' || 
                               paymentStatus == null || 
                               paymentStatus.isEmpty;
        final bool hasSubmittedPayment = paymentStatus == 'submitted' || 
                                        paymentStatus == 'approved' || 
                                        paymentStatus == 'rejected';
        
        return hasNotPaid && !hasSubmittedPayment;
      });
    }).toList();
    
    return _sortRidesByDateTime(activeRides);
  }

  // ==================== ACTIVE TAB ====================
  Widget _buildActiveBookingsContent() {
    if (_currentPassengerId == null) {
      return _buildLoginPrompt();
    }
    
    final sortedActiveRides = _getSortedActiveBookings();

    if (sortedActiveRides.isEmpty) {
      return _buildEmptyState('No active bookings', Icons.schedule);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedActiveRides.length,
      itemBuilder: (context, index) {
        final ride = sortedActiveRides[index];
        final booking = ride.bookings.firstWhere(
          (b) => b.passengerId == _currentPassengerId && 
                 b.status == BookingStatus.accepted,
        );

        final driverName = _driverNames[ride.driverId] ?? 'Driver';
        final paymentStatus = _getPaymentStatus(booking.id);
        
        final showPaymentNotification = ride.hasArrived && 
                                       (paymentStatus == 'none' || 
                                        paymentStatus == null || 
                                        paymentStatus.isEmpty);

        return Card(
          color: Colors.white.withOpacity(0.95),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRideInfoSection(ride, driverName),
                const SizedBox(height: 10),
                _buildCarDetailsSection(ride),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Status: ${_getStatusText(booking.status)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(booking.status),
                      ),
                    ),

                    if (ride.hasArrived)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green),
                            SizedBox(width: 4),
                            Text(
                              'ARRIVED',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getPaymentStatusColor(paymentStatus).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getPaymentStatusColor(paymentStatus).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getPaymentStatusIcon(paymentStatus),
                        color: _getPaymentStatusColor(paymentStatus),
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getPaymentStatusText(paymentStatus),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getPaymentStatusColor(paymentStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    if (ride.isTracking)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PassengerTrackRidePage(
                                  rideId: ride.id,
                                  bookingId: booking.id,
                                  driverName: driverName,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hexStringToColor("365770"),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.location_on, size: 18, color: Colors.white),
                          label: const Text('Track Ride', style: TextStyle(color: Colors.white)),
                        ),
                      ),

                    if (showPaymentNotification)
                      Expanded(
                        child: Container(
                          margin: ride.isTracking ? EdgeInsets.only(left: 8) : EdgeInsets.zero,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PaymentPage(
                                    ride: ride,
                                    booking: booking,
                                  ),
                                ),
                              ).then((_) {
                                setState(() {});
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            icon: const Icon(Icons.payment, size: 18, color: Colors.white),
                            label: const Text('Make Payment', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ),
                  ],
                ),

                if (!ride.isTracking && !ride.hasArrived)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Waiting for driver to start...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Booking? _findBookingForPayment(Map<String, dynamic> bookingData) {
    final rideId = bookingData['rideId'];
    final passengerId = bookingData['passengerId'];
    
    if (rideId == null || passengerId == null) return null;
    
    for (final ride in _rides) {
      if (ride.id == rideId) {
        for (final booking in ride.bookings) {
          if (booking.passengerId == passengerId) {
            return booking;
          }
        }
      }
    }
    return null;
  }

  // ==================== UPDATED: PAYMENT TAB FUNCTIONS ====================
  List<Map<String, dynamic>> _getSortedPaymentBookings() {
    if (_currentPassengerId == null) return [];
    
    final paymentBookings = _bookingDetails.values.where((booking) {
      if (booking['passengerId'] != _currentPassengerId) return false;

      final status = booking['paymentStatus']?.toString() ?? 'none';
      final hasRated = booking['rating'] != null && booking['rating'] > 0;

      // **PENTING: Include 'rejected' status juga**
      return (status == 'submitted' || status == 'rejected') || 
             (status == 'approved' && !hasRated);
    }).toList();
    
    // Sort berdasarkan paymentSubmittedAt (terbaru dulu)
    paymentBookings.sort((a, b) {
      final dateA = a['paymentSubmittedAt'] as Timestamp?;
      final dateB = b['paymentSubmittedAt'] as Timestamp?;
      
      if (dateA != null && dateB != null) {
        return dateB.compareTo(dateA); // Terbaru dulu
      }
      
      if (dateA == null && dateB != null) return 1;
      if (dateA != null && dateB != null) return -1;
      
      return 0;
    });
    
    return paymentBookings;
  }

  Widget _buildPaymentBookingsContent() {
    print('🔄 Building payment content...');
    print('📋 Current passenger ID: $_currentPassengerId');
    
    if (_currentPassengerId == null) {
      print('⚠️ No passenger ID, showing login prompt');
      return _buildLoginPrompt();
    }

    final sortedPaymentBookings = _getSortedPaymentBookings();
    print('📊 Total payment bookings: ${sortedPaymentBookings.length}');
    
    // Debug: Check what bookings we have
    for (var i = 0; i < sortedPaymentBookings.length; i++) {
      final booking = sortedPaymentBookings[i];
      print('   [$i] Status: ${booking['paymentStatus']}, ID: ${booking['id']}');
      if (booking['paymentStatus'] == 'rejected') {
        print('       🚨 REJECTED - Reason: ${booking['rejectionReason']}');
      }
    }

    if (sortedPaymentBookings.isEmpty) {
      print('📭 No payment records found');
      return _buildEmptyState(
        'No payment records',
        Icons.payment,
        subtitle: 'Payment records will appear here after making payment',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedPaymentBookings.length,
      itemBuilder: (context, index) {
        final booking = sortedPaymentBookings[index];
        final status = booking['paymentStatus']?.toString() ?? 'none';
        final rideId = booking['rideId'];
        print('🎯 Building item $index - Status: $status');
        
        Ride? ride;
        for (final r in _rides) {
          if (r.id == rideId) {
            ride = r;
            break;
          }
        }
        
        if (ride == null) return Container();
        
        final driverName = _driverNames[ride.driverId] ?? 'Driver';

        // Card utama
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FROM: ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ride.start,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TO:     ',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ride.end,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Text(
                      'Driver: $driverName',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Date: ${ride.date}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Time: ${ride.time}',
                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(Icons.attach_money, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Fare: RM ${ride.fare.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // BAGIAN 2: STATUS PAYMENT
                if (status == 'approved') 
                  _buildApprovedPaymentUI(ride, booking, driverName, status)
                else if (status == 'rejected') 
                  _buildRejectedPaymentUI(ride, booking, driverName, status)
                else if (status == 'submitted') 
                  _buildSubmittedPaymentUI(ride, booking, driverName, status)
                else 
                  Container(),
              ],
            ),
          ),
        );
      },
    );
  }

  // FUNGSI UNTUK BUILD REJECTED UI - UPDATED
  Widget _buildRejectedPaymentUI(
    Ride ride, 
    Map<String, dynamic> booking, 
    String driverName,
    String status
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // REJECTION CARD - Diperbaiki
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error,
                    size: 20,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PAYMENT REJECTED',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                ],
              ),
              
              // TAMPILKAN REASON DARI DRIVER
              if (booking['rejectionReason'] != null && 
                  booking['rejectionReason'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.message, size: 14, color: Colors.red[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Driver\'s feedback:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Text(
                          booking['rejectionReason'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // TAMPILKAN REJECTION DATE
              if (booking['paymentRejectedAt'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 30.0),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Rejected on ${_formatDate(booking['paymentRejectedAt'])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // MAKE NEW PAYMENT BUTTON - Diperbaiki
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Cari booking yang sesuai dari rides
              Booking? matchingBooking;
              for (final r in _rides) {
                if (r.id == ride.id) {
                  for (final b in r.bookings) {
                    if (b.passengerId == _currentPassengerId) {
                      matchingBooking = b;
                      break;
                    }
                  }
                }
                if (matchingBooking != null) break;
              }
              
              if (matchingBooking != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(
                      ride: ride,
                      booking: matchingBooking!,
                    ),
                  ),
                ).then((_) {
                  // Refresh data setelah kembali
                  setState(() {});
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            icon: Icon(Icons.payment, size: 22, color: Colors.white),
            label: Text(
              'UPLOAD NEW RECEIPT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // HELPER TEXT
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info, size: 16, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please upload a new receipt based on the driver\'s feedback above.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // FUNGSI UNTUK BUILD APPROVED UI
  Widget _buildApprovedPaymentUI(
    Ride ride, 
    Map<String, dynamic> booking, 
    String driverName,
    String status
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Approved',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    if (booking['paymentApprovedAt'] != null)
                      Text(
                        'Approved on ${_formatDate(booking['paymentApprovedAt'])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('bookings')
              .doc(booking['id'])
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            
            if (snapshot.hasError) {
              return const Text('Error loading rating');
            }
            
            final bookingData = snapshot.data?.data() as Map<String, dynamic>?;
            final hasRated = bookingData?['rating'] != null && bookingData?['rating'] > 0;
            
            if (hasRated) {
              return Container(); // Sudah rate, tidak perlu button
            } else {
              return Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () {
                    PassengerRatingDialog.show(
                      context: context,
                      rideId: booking['rideId'],
                      bookingId: booking['id'],
                      onRatingSubmitted: () {
                        setState(() {});
                        _tabController.animateTo(2);
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hexStringToColor("365770"),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: Icon(
                    Icons.star,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Rate Driver',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  // FUNGSI UNTUK BUILD SUBMITTED UI
  Widget _buildSubmittedPaymentUI(
    Ride ride, 
    Map<String, dynamic> booking, 
    String driverName,
    String status
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Submitted',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Waiting for driver approval',
                  style: TextStyle(
                    color: Colors.orange[700],
                    fontSize: 12,
                  ),
                ),
                if (booking['paymentSubmittedAt'] != null)
                  Text(
                    'Submitted on ${_formatDate(booking['paymentSubmittedAt'])}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FUNGSI FORMAT DATE
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  // TAMBAH: Fungsi untuk mendapatkan sorted completed bookings
  List<Map<String, dynamic>> _getSortedCompletedBookings() {
    if (_currentPassengerId == null) return [];
    
    final completedBookings = _bookingDetails.values.where((booking) {
      if (booking['passengerId'] != _currentPassengerId) return false;
      
      final paymentStatus = booking['paymentStatus']?.toString() ?? 'none';
      final hasRated = booking['rating'] != null && booking['rating'] > 0;
      
      return paymentStatus == 'approved' && hasRated;
    }).toList();
    
    // Sort berdasarkan ratedAt atau paymentApprovedAt (terbaru dulu)
    completedBookings.sort((a, b) {
      final dateA = a['ratedAt'] as Timestamp? ?? a['paymentApprovedAt'] as Timestamp?;
      final dateB = b['ratedAt'] as Timestamp? ?? b['paymentApprovedAt'] as Timestamp?;
      
      if (dateA != null && dateB != null) {
        return dateB.compareTo(dateA); // Terbaru dulu
      }
      
      if (dateA == null && dateB != null) return 1;
      if (dateA != null && dateB != null) return -1;
      
      return 0;
    });
    
    return completedBookings;
  }

  Widget _buildCompletedBookingsContent() {
    if (_currentPassengerId == null) {
      return _buildLoginPrompt();
    }

    final sortedCompletedBookings = _getSortedCompletedBookings();

    if (sortedCompletedBookings.isEmpty) {
      return _buildEmptyState(
        'No completed rides yet',
        Icons.done_all,
        subtitle: 'Completed rides will appear here after payment is approved',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedCompletedBookings.length,
      itemBuilder: (context, index) {
        final booking = sortedCompletedBookings[index];
        final rideId = booking['rideId'];
        
        Ride? ride;
        for (final r in _rides) {
          if (r.id == rideId) {
            ride = r;
            break;
          }
        }
        
        if (ride == null) return Container();
        
        final driverName = _driverNames[ride.driverId] ?? 'Driver';
        final rating = booking['rating'] as int?;
        final review = booking['review'] as String?;
        final hasRated = rating != null && rating > 0;

        return Card(
          color: Colors.white.withOpacity(0.95),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRideInfoSection(ride, driverName),
                const SizedBox(height: 10),
                _buildCarDetailsSection(ride),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Payment Approved • ${_formatDate(booking['paymentApprovedAt'])}',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (hasRated)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Your Rating:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(width: 8),
                            ...List.generate(
                              rating!,
                              (i) => Icon(Icons.star, color: Colors.amber, size: 18),
                            ),
                            Text(
                              ' ($rating.0)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                        if (review != null && review.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Review:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '"$review"',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (booking['ratedAt'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'Rated on: ${_formatDate(booking['ratedAt'])}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hexStringToColor("365770").withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: hexStringToColor("365770").withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How was your ride with $driverName?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              PassengerRatingDialog.show(
                                context: context,
                                rideId: booking['rideId'],
                                bookingId: booking['id'],
                                onRatingSubmitted: () {
                                  setState(() {});
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hexStringToColor("365770"),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: Icon(Icons.star, size: 16, color: Colors.white),
                            label: Text('Rate Driver', style: TextStyle(color: Colors.white)),
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
  }

  Future<void> _refreshBookingData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      print('🔄 Refreshing booking data...');
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('passengerId', isEqualTo: user.uid)
          .get();
      
      if (!mounted) return;
      
      setState(() {
        _bookingDetails.clear();
        
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final bookingId = doc.id;
          
          _bookingDetails[bookingId] = {...data, 'id': bookingId};
          
          final rideId = data['rideId'];
          final passengerId = data['passengerId'];
          if (rideId != null && passengerId != null) {
            final combinedId = '${rideId}_$passengerId';
            _bookingDetails[combinedId] = {...data, 'id': bookingId};
          }
        }
      });
      
      print('✅ Booking data refreshed: ${_bookingDetails.length} bookings');
      
    } catch (e) {
      print('❌ Error refreshing booking data: $e');
    }
  }

  Future<void> _refreshRidesData() async {
    try {
      print('🔄 Refreshing rides data...');
      final snapshot = await FirebaseFirestore.instance
          .collection('rides')
          .get();
      
      if (!mounted) return;
      
      setState(() {
        _rides.clear();
        _rides.addAll(
          snapshot.docs
              .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
              .toList()
        );
      });
      print('✅ Rides data refreshed: ${_rides.length} rides');
    } catch (e) {
      print('❌ Error refreshing rides data: $e');
    }
  }

  // TAMBAH: Fungsi untuk mendapatkan sorted cancelled bookings
  List<Ride> _getSortedCancelledBookings() {
    if (_currentPassengerId == null) return [];
    
    final cancelledRides = _rides.where((ride) {
      return ride.bookings.any(
        (booking) =>
            booking.passengerId == _currentPassengerId &&
            (booking.status == BookingStatus.rejected ||
                booking.status == BookingStatus.cancelled),
      );
    }).toList();
    
    return _sortRidesByDateTime(cancelledRides);
  }

  // ==================== CANCELLED TAB ====================
  Widget _buildCancelledBookingsContent() {
    if (_currentPassengerId == null) {
      return _buildLoginPrompt();
    }

    final sortedCancelledRides = _getSortedCancelledBookings();

    if (sortedCancelledRides.isEmpty) {
      return _buildEmptyState('No cancelled bookings', Icons.cancel);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedCancelledRides.length,
      itemBuilder: (context, index) {
        final ride = sortedCancelledRides[index];
        final booking = ride.bookings.firstWhere(
          (b) =>
              b.passengerId == _currentPassengerId &&
              (b.status == BookingStatus.rejected ||
                  b.status == BookingStatus.cancelled),
        );

        final driverName = _driverNames[ride.driverId] ?? 'Driver';

        String bookingStatusText;
        Color statusColor;
        if (booking.status == BookingStatus.rejected) {
          bookingStatusText = 'Rejected by Driver';
          statusColor = Colors.red;
        } else {
          bookingStatusText = 'Cancelled by You';
          statusColor = Colors.grey;
        }

        return Card(
          color: Colors.white.withOpacity(0.95),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRideInfoSection(ride, driverName),
                const SizedBox(height: 10),
                _buildCarDetailsSection(ride),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Status: $bookingStatusText',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== HELPER WIDGETS ====================
  Widget _buildRideInfoSection(Ride ride, String driverName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FROM: ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: Text(
                ride.start,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TO:     ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Expanded(
              child: Text(
                ride.end,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Driver: $driverName',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        _buildDateTimeFare(ride),
      ],
    );
  }

  Widget _buildCarDetailsSection(Ride ride) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Car Details:",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Model: ${ride.carDetails.model}",
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  Text(
                    "Plate No: ${ride.carDetails.plateNumber}",
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  Text(
                    "Color: ${ride.carDetails.color}",
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  Text(
                    "Capacity: ${ride.carDetails.seatingDisplay}",
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                    Text(
                  "Year: ${ride.carDetails.year}",
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
                Text(
                  "Insurance: ${ride.carDetails.insuranceCompany}",
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                ),
              ],
              ),
            ),
            if (ride.carDetails.imageUrl != null &&
                ride.carDetails.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    ride.carDetails.imageUrl!,
                    height: 80,
                    width: 110,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 60,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    final bg = hexStringToColor("365770");
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 60, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            "Please log in to view your bookings",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const UserLoginPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: bg,
            ),
            child: const Text('Log In Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, {String? subtitle}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'none':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status) {
      case 'submitted':
        return Icons.access_time;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.error;
      case 'none':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status) {
      case 'submitted':
        return 'Payment Submitted - Waiting for Approval';
      case 'approved':
        return 'Payment Approved';
      case 'rejected':
        return 'Payment Rejected';
      case 'none':
        return 'Payment Required';
      default:
        return 'Payment';
    }
  }

  Widget _buildPaymentTimeline(Map<String, dynamic> data, String status) {
    final widgets = <Widget>[];

    if (data['paymentSubmittedAt'] != null) {
      widgets.add(
        _buildTimelineItem(
          'Submitted',
          data['paymentSubmittedAt'],
          Icons.upload_file,
        ),
      );
    }

    if (status == 'approved' && data['paymentApprovedAt'] != null) {
      widgets.add(
        _buildTimelineItem(
          'Approved',
          data['paymentApprovedAt'],
          Icons.check_circle,
        ),
      );
    }

    if (status == 'rejected' && data['paymentRejectedAt'] != null) {
      widgets.add(
        _buildTimelineItem('Rejected', data['paymentRejectedAt'], Icons.error),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildTimelineItem(String label, dynamic timestamp, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ${_formatDate(timestamp)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.accepted:
        return Colors.green;
      case BookingStatus.rejected:
        return Colors.red;
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getStatusText(BookingStatus status) {
    return status.toString().split('.').last.toUpperCase();
  }

  // ==================== PAYMENT DETAILS DIALOG ====================
  void _showPaymentDetails(
    BuildContext context,
    Ride ride,
    Booking booking,
    String paymentStatus,
  ) {
    final bookingData = _bookingDetails[booking.id];
    final receiptUrl = _getReceiptUrl(booking.id);
    final driverName = _driverNames[ride.driverId] ?? 'Driver';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Payment Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.directions_car),
                    title: const Text('Ride Details'),
                    subtitle: Text('${ride.start} → ${ride.end}'),
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person),
                    title: const Text('Driver'),
                    subtitle: Text(driverName),
                  ),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_money),
                    title: const Text('Fare'),
                    subtitle: Text('RM ${ride.fare.toStringAsFixed(2)}'),
                  ),

                  const Divider(),

                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _getPaymentStatusIcon(paymentStatus),
                      color: _getPaymentStatusColor(paymentStatus),
                    ),
                    title: Text(
                      'Payment Status',
                      style: TextStyle(
                        color: _getPaymentStatusColor(paymentStatus),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(_getPaymentStatusText(paymentStatus)),
                  ),

                  if (bookingData != null) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Timeline:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (bookingData['paymentSubmittedAt'] != null)
                      _buildTimelineItemDialog(
                        'Submitted',
                        bookingData['paymentSubmittedAt'],
                      ),
                    if (paymentStatus == 'approved' &&
                        bookingData['paymentApprovedAt'] != null)
                      _buildTimelineItemDialog(
                        'Approved',
                        bookingData['paymentApprovedAt'],
                      ),
                    if (paymentStatus == 'rejected' &&
                        bookingData['paymentRejectedAt'] != null)
                      _buildTimelineItemDialog(
                        'Rejected',
                        bookingData['paymentRejectedAt'],
                      ),
                  ],

                  if (paymentStatus == 'rejected' &&
                      bookingData?['rejectionReason'] != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Reason: ${bookingData!['rejectionReason']}',
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                  ],

                  if (receiptUrl != null) ...[
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Opening receipt...')),
                        );
                      },
                      icon: const Icon(Icons.receipt, color: Colors.white),
                      label: const Text('View Receipt', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hexStringToColor("365770"),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: hexStringToColor("365770"))),
              ),
              if (paymentStatus == 'rejected')
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) =>
                                PaymentScreen(ride: ride, booking: booking),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Resubmit Payment'),
                ),
            ],
          ),
    );
  }

  Widget _buildTimelineItemDialog(String label, dynamic timestamp) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Text(
            '• $label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(_formatDate(timestamp)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");
    const double bottomNavArea = 96;

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      drawer: const PassengerAppDrawer(),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
        ),
        title: const Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Text(
            " My Bookings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              print('🔄 Manual refresh triggered');
              _refreshBookingData();
              _refreshRidesData();
              setState(() {});
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TabBar(
              controller: _tabController,
              indicator: const UnderlineTabIndicator(
                borderSide: BorderSide(color: Colors.white, width: 3),
                insets: EdgeInsets.symmetric(horizontal: 14),
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 1),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              tabs: const [
                Tab(text: "Active"),
                Tab(text: "Payment"),
                Tab(text: "Completed"),
                Tab(text: "Cancelled"),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [bg, bg, bg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: bottomNavArea),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveBookingsContent(),
                  _buildPaymentBookingsContent(),
                  _buildCompletedBookingsContent(),
                  _buildCancelledBookingsContent(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: UniversalBottomNavBar.passenger(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
      ),
    );
  }
}