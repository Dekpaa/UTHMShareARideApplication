import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/Component/Universal_nav_bar.dart';
import 'package:uthmshareride/modules/Driver/driver_homepage.dart';
import 'package:uthmshareride/modules/Message/listchatdriver.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class DriverRideHistoryPage extends StatefulWidget {
  const DriverRideHistoryPage({super.key});

  @override
  State<DriverRideHistoryPage> createState() => _DriverRideHistoryPageState();
}

class _DriverRideHistoryPageState extends State<DriverRideHistoryPage> {
  int _selectedIndex = 1;
  String _selectedFilter = 'all';
  
  String? _currentDriverId;
  String _currentDriverName = "Driver";
  final List<Ride> _allRides = [];
  final Map<String, String> _passengerNames = {};
  final Set<String> _requestedPassengerIds = {};
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridesStreamSub;
  
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initUserAndListenData();
  }

  @override
  void dispose() {
    _ridesStreamSub?.cancel();
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

      _currentDriverId = user.uid;

      // Load driver info
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_currentDriverId)
          .get();
          
      if (driverDoc.exists) {
        setState(() {
          _currentDriverName = (driverDoc.data()?['fullName'] ?? 'Driver').toString();
        });
      }

      // LISTEN TO RIDES COLLECTION (driver's rides only)
      _ridesStreamSub = FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: _currentDriverId)
          .snapshots()
          .listen((snapshot) {
            if (!mounted) return;
            
            setState(() {
              _allRides.clear();
              _allRides.addAll(
                snapshot.docs
                    .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
                    .toList(),
              );
              _isLoading = false;
            });
            
            // Fetch passenger names
            for (final ride in _allRides) {
              for (final booking in ride.bookings) {
                _fetchPassengerName(booking.passengerId);
              }
            }
          }, onError: (error) {
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchPassengerName(String passengerId) async {
    if (passengerId.isEmpty || 
        _passengerNames.containsKey(passengerId) ||
        _requestedPassengerIds.contains(passengerId)) return;

    _requestedPassengerIds.add(passengerId);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('passengers')
          .doc(passengerId)
          .get();

      if (!mounted) return;
      
      setState(() {
        _passengerNames[passengerId] = doc.exists 
            ? (doc.data()?['fullName'] ?? 'Passenger')
            : 'Passenger';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _passengerNames[passengerId] = 'Passenger';
      });
    }
  }

  // GET COMPLETED RIDES
  List<Map<String, dynamic>> _getCompletedRides() {
    final completedRides = <Map<String, dynamic>>[];
    
    for (final ride in _allRides) {
      if (ride.status == 'completed') {
        // Get the accepted booking (should be only one)
        final acceptedBooking = ride.bookings
            .where((b) => b.status == BookingStatus.accepted)
            .firstOrNull;
        
        if (acceptedBooking != null) {
          final passengerName = _passengerNames[acceptedBooking.passengerId] ?? 
                              acceptedBooking.passengerName ?? 
                              'Passenger';
          
          completedRides.add({
            'type': 'completed',
            'ride': ride,
            'booking': acceptedBooking,
            'passengerName': passengerName,
            'isPaid': acceptedBooking.isPaid == true,
            'rating': acceptedBooking.rating,
            'review': acceptedBooking.review,
            'completedAt': ride.toMap()['completedAt'],
          });
        }
      }
    }
    
    // Sort by completion date (latest first)
    completedRides.sort((a, b) {
      final completedAtA = a['completedAt'] as Timestamp?;
      final completedAtB = b['completedAt'] as Timestamp?;
      
      if (completedAtA != null && completedAtB != null) {
        return completedAtB.compareTo(completedAtA);
      }
      
      // Fallback to ride date/time
      final rideA = a['ride'] as Ride;
      final rideB = b['ride'] as Ride;
      final dateTimeA = _parseRideDateTime(rideA);
      final dateTimeB = _parseRideDateTime(rideB);
      
      if (dateTimeA != null && dateTimeB != null) {
        return dateTimeB.compareTo(dateTimeA);
      }
      
      return 0;
    });
    
    return completedRides;
  }

  // GET CANCELLED RIDES
  List<Map<String, dynamic>> _getCancelledRides() {
    final cancelledRides = <Map<String, dynamic>>[];
    
    for (final ride in _allRides) {
      if (ride.status.startsWith('cancelled_') ||
          ride.bookings.every((b) => 
            b.status == BookingStatus.rejected || 
            b.status == BookingStatus.cancelled)) {
        
        String cancellationReason;
        if (ride.status == 'cancelled_by_driver') {
          cancellationReason = 'Cancelled by you';
        } else if (ride.status == 'cancelled_by_passenger') {
          cancellationReason = 'Cancelled by passenger';
        } else {
          cancellationReason = 'Booking rejected';
        }
        
        // Get the booking (should be only one)
        final booking = ride.bookings.isNotEmpty ? ride.bookings.first : null;
        final passengerName = booking != null 
            ? (_passengerNames[booking.passengerId] ?? 
               booking.passengerName ?? 
               'Passenger')
            : 'Passenger';
        
        cancelledRides.add({
          'type': 'cancelled',
          'ride': ride,
          'cancellationReason': cancellationReason,
          'passengerName': passengerName,
          'bookingStatus': booking?.status.toString() ?? '',
          'cancelledAt': ride.toMap()['cancelledAt'],
        });
      }
    }
    
    // Sort by cancellation date (latest first)
    cancelledRides.sort((a, b) {
      final cancelledAtA = a['cancelledAt'] as Timestamp?;
      final cancelledAtB = b['cancelledAt'] as Timestamp?;
      
      if (cancelledAtA != null && cancelledAtB != null) {
        return cancelledAtB.compareTo(cancelledAtA);
      }
      
      // Fallback to ride date/time
      final rideA = a['ride'] as Ride;
      final rideB = b['ride'] as Ride;
      final dateTimeA = _parseRideDateTime(rideA);
      final dateTimeB = _parseRideDateTime(rideB);
      
      if (dateTimeA != null && dateTimeB != null) {
        return dateTimeB.compareTo(dateTimeA);
      }
      
      return 0;
    });
    
    return cancelledRides;
  }

  // PARSE DATE TIME
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
      return null;
    }
  }

  // BUILD HISTORY LIST
  Widget _buildHistoryList() {
    List<Map<String, dynamic>> ridesData;
    
    if (_selectedFilter == 'all') {
      final completed = _getCompletedRides();
      final cancelled = _getCancelledRides();
      ridesData = [...completed, ...cancelled]
        ..sort((a, b) {
          final dateA = a['completedAt'] ?? a['cancelledAt'];
          final dateB = b['completedAt'] ?? b['cancelledAt'];
          
          if (dateA != null && dateB != null) {
            return (dateB as Timestamp).compareTo(dateA as Timestamp);
          }
          
          final rideA = a['ride'] as Ride;
          final rideB = b['ride'] as Ride;
          final dateTimeA = _parseRideDateTime(rideA);
          final dateTimeB = _parseRideDateTime(rideB);
          
          if (dateTimeA != null && dateTimeB != null) {
            return dateTimeB.compareTo(dateTimeA);
          }
          
          return 0;
        });
    } else if (_selectedFilter == 'completed') {
      ridesData = _getCompletedRides();
    } else {
      ridesData = _getCancelledRides();
    }

    if (ridesData.isEmpty) {
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
              _selectedFilter == 'all' ? 'No ride history' :
              _selectedFilter == 'completed' ? 'No completed rides' : 
              'No cancelled rides',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all' ? 'Your ride history will appear here' :
              _selectedFilter == 'completed' ? 'Completed rides will appear here' : 
              'Cancelled rides will appear here',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: ridesData.length,
      itemBuilder: (context, index) {
        final data = ridesData[index];
        final isCompleted = data['type'] == 'completed';
        
        return _buildRideCard(data, isCompleted);
      },
    );
  }

  // BUILD RIDE CARD
  Widget _buildRideCard(Map<String, dynamic> data, bool isCompleted) {
    final ride = data['ride'] as Ride;
    final passengerName = data['passengerName'] as String;
    final bg = hexStringToColor("365770");
    
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
            // STATUS BADGE
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
            
            // ROUTE INFO
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
            
            // PASSENGER INFO
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          passengerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        
                        if (isCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (data['isPaid'] as bool?) == true
                                        ? Colors.green.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (data['isPaid'] as bool?) == true
                                          ? Colors.green.shade200
                                          : Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    (data['isPaid'] as bool?) == true ? 'PAID' : 'UNPAID',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: (data['isPaid'] as bool?) == true
                                          ? Colors.green.shade800
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // DATE, TIME & FARE
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 4),
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
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Fare',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'RM ${ride.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // CANCELLATION REASON (for cancelled rides)
            if (!isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info,
                        size: 14,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['cancellationReason'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // RATING & REVIEW (for completed rides with rating)
            if (isCompleted && data['rating'] != null && (data['rating'] as int) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Rating',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                Icons.star,
                                size: 16,
                                color: index < (data['rating'] as int)
                                    ? Colors.amber
                                    : Colors.grey.shade300,
                              );
                            }),
                          ),
                        ],
                      ),
                      
                      if (data['review'] != null && 
                          (data['review'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            '"${data['review']}"',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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
            'Loading ride history...',
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
            " Ride History",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // FILTER CHIPS
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
          
          // HISTORY LIST
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

// Helper extension for firstOrNull
extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    try {
      return first;
    } catch (e) {
      return null;
    }
  }
}