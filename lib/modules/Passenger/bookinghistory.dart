import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/Component/Universal_nav_bar.dart';
import 'package:uthmshareride/modules/Passenger/passangerhomepage.dart';
import 'package:uthmshareride/modules/Message/listchatdriver.dart';
import 'package:uthmshareride/modules/ShareRide/myrides.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class BookingHistoryPage extends StatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  State<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends State<BookingHistoryPage> {
  int _selectedIndex = 0;
  String _selectedFilter = 'all';
  
  String? _currentPassengerId;
  final List<Ride> _allRides = [];
  final Map<String, String> _driverNames = {};
  final Set<String> _requestedDriverIds = {};
  
  StreamSubscription<QuerySnapshot>? _ridesSub;
  
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initUserAndListenData();
  }

  @override
  void dispose() {
    _ridesSub?.cancel();
    super.dispose();
  }

  Future<void> _initUserAndListenData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
        return;
      }

      _currentPassengerId = user.uid;
      print('🆔 Passenger ID: $_currentPassengerId');

      // 🔥 LISTEN TO RIDES COLLECTION (SAMA SEPERTI MyBookingsPage)
      _ridesSub = FirebaseFirestore.instance
          .collection('rides')
          .snapshots()
          .listen((snapshot) {
            print('🚗 Total rides loaded: ${snapshot.docs.length}');
            
            if (!mounted) return;
            
            setState(() {
              _allRides.clear();
              _allRides.addAll(
                snapshot.docs
                    .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
                    .toList(),
              );
              _isLoading = false;
              
              // Debug: Print cancelled rides
              _debugPrintCancelledRides();
            });
            
            // Fetch driver names
            for (final ride in _allRides) {
              _fetchDriverName(ride.driverId);
            }
          }, onError: (error) {
            print('❌ Error loading rides: $error');
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          });

    } catch (e) {
      print('❌ Error initializing: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _debugPrintCancelledRides() {
    print('=== DEBUG: CHECKING CANCELLED RIDES ===');
    
    for (final ride in _allRides) {
      final bookings = ride.bookings.where((b) => 
          b.passengerId == _currentPassengerId && 
          (b.status == BookingStatus.cancelled || 
           b.status == BookingStatus.rejected));
      
      if (bookings.isNotEmpty) {
        print('🚫 Found cancelled booking in ride: ${ride.id}');
        print('   Ride status: ${ride.status}');
        print('   Date: ${ride.date}, Time: ${ride.time}');
        print('   From: ${ride.start} → To: ${ride.end}');
        for (var booking in bookings) {
          print('   Booking status: ${booking.status}');
          print('   Passenger ID: ${booking.passengerId}');
        }
      }
    }
    
    print('=== DEBUG END ===');
  }

  Future<void> _fetchDriverName(String driverId) async {
    if (driverId.isEmpty || _driverNames.containsKey(driverId)) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();

      if (!mounted) return;
      
      setState(() {
        _driverNames[driverId] = doc.exists 
            ? (doc.data()?['fullName'] ?? 'Driver')
            : 'Driver';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _driverNames[driverId] = 'Driver';
      });
    }
  }

  // 🔥 FUNGSI UTAMA: DAPATKAN CANCELLED BOOKINGS DARI RIDES
  List<Map<String, dynamic>> _getCancelledBookings() {
    if (_currentPassengerId == null) return [];
    
    final cancelledBookings = <Map<String, dynamic>>[];
    
    for (final ride in _allRides) {
      // Cari booking untuk passenger ini yang cancelled/rejected
      for (final booking in ride.bookings) {
        if (booking.passengerId == _currentPassengerId && 
            (booking.status == BookingStatus.cancelled || 
             booking.status == BookingStatus.rejected)) {
          
          cancelledBookings.add({
            'type': 'cancelled',
            'ride': ride,
            'booking': booking,
            'driverName': _driverNames[ride.driverId] ?? 'Driver',
            'cancelledAt': booking.status == BookingStatus.cancelled 
                ? 'Cancelled by you' 
                : 'Rejected by driver',
          });
        }
      }
      
      // 🔥 TAMBAH: Check jika ride itu sendiri cancelled (driver cancel ride)
      if (ride.status.startsWith('cancelled_') && 
          ride.bookings.any((b) => b.passengerId == _currentPassengerId)) {
        
        // Cari booking untuk passenger ini (walaupun status bukan cancelled)
        final passengerBooking = ride.bookings.firstWhere(
          (b) => b.passengerId == _currentPassengerId,
          orElse: () => Booking(
            id: '',
            passengerId: _currentPassengerId!,
            passengerName: 'Passenger',
            status: BookingStatus.rejected,
            isPaid: false,
            rideId: ride.id,
          ),
        );
        
        cancelledBookings.add({
          'type': 'ride_cancelled',
          'ride': ride,
          'booking': passengerBooking,
          'driverName': _driverNames[ride.driverId] ?? 'Driver',
          'cancelledAt': ride.status == 'cancelled_by_driver' 
              ? 'Ride cancelled by driver' 
              : 'Ride cancelled',
        });
      }
    }
    
    // Sort by date (latest first)
    cancelledBookings.sort((a, b) {
      final rideA = a['ride'] as Ride;
      final rideB = b['ride'] as Ride;
      
      final dateTimeA = _parseRideDateTime(rideA);
      final dateTimeB = _parseRideDateTime(rideB);
      
      if (dateTimeA != null && dateTimeB != null) {
        return dateTimeB.compareTo(dateTimeA);
      }
      
      return 0;
    });
    
    print('📋 Total cancelled bookings found: ${cancelledBookings.length}');
    return cancelledBookings;
  }

  // 🔥 FUNGSI UNTUK COMPLETED BOOKINGS
  List<Map<String, dynamic>> _getCompletedBookings() {
    if (_currentPassengerId == null) return [];
    
    final completedBookings = <Map<String, dynamic>>[];
    
    for (final ride in _allRides) {
      // Cari booking untuk passenger ini yang completed (payment approved)
      for (final booking in ride.bookings) {
        if (booking.passengerId == _currentPassengerId && 
            booking.isPaid == true) { // Atau check paymentStatus == 'approved'
          
          completedBookings.add({
            'type': 'completed',
            'ride': ride,
            'booking': booking,
            'driverName': _driverNames[ride.driverId] ?? 'Driver',
            'rating': booking.rating,
            'review': booking.review,
          });
        }
      }
    }
    
    // Sort by date (latest first)
    completedBookings.sort((a, b) {
      final rideA = a['ride'] as Ride;
      final rideB = b['ride'] as Ride;
      
      final dateTimeA = _parseRideDateTime(rideA);
      final dateTimeB = _parseRideDateTime(rideB);
      
      if (dateTimeA != null && dateTimeB != null) {
        return dateTimeB.compareTo(dateTimeA);
      }
      
      return 0;
    });
    
    print('✅ Total completed bookings found: ${completedBookings.length}');
    return completedBookings;
  }

  // 🔥 PARSE DATE TIME (SAMA SEPERTI MyBookingsPage)
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

  // 🔥 BUILD HISTORY LIST
  Widget _buildHistoryList() {
    List<Map<String, dynamic>> bookings;
    
    if (_selectedFilter == 'all') {
      final completed = _getCompletedBookings();
      final cancelled = _getCancelledBookings();
      bookings = [...completed, ...cancelled]
        ..sort((a, b) {
          final rideA = a['ride'] as Ride;
          final rideB = b['ride'] as Ride;
          final dateA = _parseRideDateTime(rideA);
          final dateB = _parseRideDateTime(rideB);
          if (dateA != null && dateB != null) {
            return dateB.compareTo(dateA);
          }
          return 0;
        });
    } else if (_selectedFilter == 'completed') {
      bookings = _getCompletedBookings();
    } else {
      bookings = _getCancelledBookings();
    }

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == 'all' ? Icons.history : 
              _selectedFilter == 'completed' ? Icons.check_circle : Icons.cancel,
              size: 60,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'all' ? 'No booking history' :
              _selectedFilter == 'completed' ? 'No completed rides' : 
              'No cancelled rides',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final data = bookings[index];
        final ride = data['ride'] as Ride;
        final booking = data['booking'] as Booking;
        final driverName = data['driverName'] as String;
        final isCompleted = data['type'] == 'completed';
        final cancelledAt = data['cancelledAt'] as String?;
        final rating = data['rating'] as int?;
        final hasRated = rating != null && rating > 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 STATUS BADGE
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted ? Icons.check_circle : Icons.cancel,
                        size: 14,
                        color: isCompleted ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCompleted ? 'COMPLETED' : 'CANCELLED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCompleted ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 🔥 ROUTE INFO
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ride.start,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Container(
                        height: 20,
                        width: 2,
                        color: Colors.grey[300],
                      ),
                    ),
                    
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ride.end,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // 🔥 DRIVER & FARE
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Driver: $driverName',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Row(
                      children: [
                        const Icon(Icons.attach_money, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'RM ${ride.fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // 🔥 DATE & TIME
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Date: ${ride.date}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Time: ${ride.time}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // 🔥 CANCELLED INFO
                if (!isCompleted && cancelledAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        cancelledAt,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade800,
                        ),
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

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Loading booking history...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.white70),
          const SizedBox(height: 16),
          const Text(
            'Error loading data',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _initUserAndListenData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: hexStringToColor("365770"),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");
    
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
            " Booking History",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PassengerHomepage()),
              ),
        ),
      ),
      body: Column(
        children: [
          // 🔥 FILTER CHIPS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip('All History', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled', 'cancelled'),
              ],
            ),
          ),
          
          // 🔥 HISTORY LIST
          Expanded(
            child: _isLoading
                ? _buildLoadingWidget()
                : _hasError
                    ? _buildErrorWidget()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    final bg = hexStringToColor("365770");
    
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? bg : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
        }
      },
      selectedColor: Colors.white,
      backgroundColor: Colors.white.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.white : Colors.transparent,
        ),
      ),
    );
  }
}