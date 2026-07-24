import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';

class AvailableRidesPage extends StatefulWidget {
  final String? fromLocation;
  final String? toLocation;
  final String? selectedDate;
  final String? selectedTime;
  final LatLng? fromLatLng;
  final LatLng? toLatLng;

  const AvailableRidesPage({
    super.key,
    this.fromLocation,
    this.toLocation,
    this.selectedDate,
    this.selectedTime,
    this.fromLatLng,
    this.toLatLng,
  });

  @override
  State<AvailableRidesPage> createState() => _AvailableRidesPageState();
}

class _AvailableRidesPageState extends State<AvailableRidesPage> {
  final Distance _distanceCalculator = const Distance();
  final RideService _rideService = RideService();

  String _currentPassengerId = '';
  String _currentPassengerName = 'Passenger';

  // cache driver names
  final Map<String, String> _driverNames = {};
  final Set<String> _requestedDriverIds = {};

  // NEW: Sorting and filtering variables
  String _sortBy = 'dateTime'; // Default sort by date & time
  bool _showLatestOnly = false; // Toggle for showing latest rides only
  List<String> _sortOptions = [
    'dateTime', // Date & Time (Earliest)
    'dateTimeDesc', // Date & Time (Latest)
    'fareAsc', // Fare (Low to High)
    'fareDesc', // Fare (High to Low)
    'distance', // Distance (Nearest)
  ];

  @override
  void initState() {
    super.initState();

    // Run auto-cleanup when page loads
    _runAutoCleanup();

    final user = FirebaseAuth.instance.currentUser;
    _currentPassengerId = user?.uid ?? 'guest_passenger';

    if (_currentPassengerId != 'guest_passenger') {
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
      }).catchError((_) {
        // if error, keep default 'Passenger'
      });
    }
  }

  // Function to auto-delete completed rides
  Future<void> _runAutoCleanup() async {
    try {
      await _rideService.autoDeleteCompletedRides(daysOld: 1);
    } catch (e) {
      print('Auto-cleanup error: $e');
    }
  }

  Future<void> _fetchDriverName(String driverId) async {
    if (driverId.isEmpty) return;
    if (_driverNames.containsKey(driverId) ||
        _requestedDriverIds.contains(driverId)) {
      return;
    }

    _requestedDriverIds.add(driverId);

    try {
      final doc = await FirebaseFirestore.instance
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _driverNames[driverId] = 'Driver';
      });
    }
  }

  // NEW: Calculate distance for sorting
  double _calculateDistanceToRide(Ride ride) {
    final fromLatLng = widget.fromLatLng;
    final rideStartLatLng = ride.startLatLng;

    if (fromLatLng == null || rideStartLatLng == null) {
      return double.maxFinite;
    }

    try {
      return _distanceCalculator.as(
        LengthUnit.Meter,
        rideStartLatLng,
        fromLatLng,
      );
    } catch (e) {
      return double.maxFinite;
    }
  }

  // NEW: Parse date and time for sorting
  DateTime? _parseRideDateTime(Ride ride) {
    try {
      // Assuming date format is 'yyyy-MM-dd' and time format is 'HH:mm'
      final dateParts = ride.date.split('-');
      final timeParts = ride.time.split(':');
      
      if (dateParts.length == 3 && timeParts.length >= 2) {
        return DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
          int.parse(timeParts[0]),
          int.parse(timeParts[1]),
        );
      }
    } catch (e) {
      print('Error parsing date/time: $e');
    }
    return null;
  }

  // NEW: Filter rides based on latest only
  List<Ride> _filterLatestRides(List<Ride> rides) {
    if (!_showLatestOnly) return rides;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return rides.where((ride) {
      final rideDateTime = _parseRideDateTime(ride);
      if (rideDateTime == null) return false;
      
      final rideDate = DateTime(rideDateTime.year, rideDateTime.month, rideDateTime.day);
      return rideDate.isAtSameMomentAs(today) || rideDate.isAfter(today);
    }).toList();
  }

  // NEW: Sort rides based on selected criteria
  List<Ride> _sortRides(List<Ride> rides) {
    return List<Ride>.from(rides)
      ..sort((a, b) {
        switch (_sortBy) {
          case 'dateTime': // Earliest first
            final aDateTime = _parseRideDateTime(a);
            final bDateTime = _parseRideDateTime(b);
            
            if (aDateTime == null && bDateTime == null) return 0;
            if (aDateTime == null) return 1;
            if (bDateTime == null) return -1;
            
            return aDateTime.compareTo(bDateTime);
            
          case 'dateTimeDesc': // Latest first
            final aDateTime = _parseRideDateTime(a);
            final bDateTime = _parseRideDateTime(b);
            
            if (aDateTime == null && bDateTime == null) return 0;
            if (aDateTime == null) return 1;
            if (bDateTime == null) return -1;
            
            return bDateTime.compareTo(aDateTime);
            
          case 'fareAsc': // Lowest fare first
            return a.fare.compareTo(b.fare);
            
          case 'fareDesc': // Highest fare first
            return b.fare.compareTo(a.fare);
            
          case 'distance': // Nearest first
            final aDistance = _calculateDistanceToRide(a);
            final bDistance = _calculateDistanceToRide(b);
            return aDistance.compareTo(bDistance);
            
          default:
            return 0;
        }
      });
  }

  // NEW: Check if passenger already has active booking for a ride
  bool _hasActiveBookingForRide(Ride ride) {
    if (_currentPassengerId.isEmpty || _currentPassengerId == 'guest_passenger') {
      return false;
    }

    try {
      // Check if this passenger already has a pending/accepted/confirmed booking for this ride
      final existingBooking = ride.bookings.firstWhere(
        (b) =>
            b.passengerId == _currentPassengerId &&
            (b.status == BookingStatus.pending ||
                b.status == BookingStatus.accepted ||
                b.status == BookingStatus.confirmed),
      );
      return true; // Passenger has active booking for this ride
    } catch (_) {
      return false; // No active booking found
    }
  }

  Future<void> _bookRide(Ride ride) async {
    // Check if this passenger already has a pending/accepted/confirmed booking for this ride
    if (_hasActiveBookingForRide(ride)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already have an active booking for this ride.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final newBooking = Booking(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      passengerId: _currentPassengerId,
      passengerName: _currentPassengerName.trim(),
      status: BookingStatus.pending,
      isPaid: false,
    );

    try {
      await RideStorage().addBookingToRide(ride.id, newBooking);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Booking request sent for ride from ${ride.start} to ${ride.end}! Waiting for driver acceptance.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send booking: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildSearchSummaryBox() {
    final from = (widget.fromLocation ?? '').trim();
    final to = (widget.toLocation ?? '').trim();
    final date = (widget.selectedDate ?? '').trim();
    final time = (widget.selectedTime ?? '').trim();

    if (from.isEmpty && to.isEmpty && date.isEmpty && time.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Summary',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            // FROM
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FROM : ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Expanded(
                  child: Text(
                    from.isEmpty ? '-' : from,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // TO
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TO :     ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Expanded(
                  child: Text(
                    to.isEmpty ? '-' : to,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // DATE + TIME
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  date.isEmpty ? 'Date: Any' : 'Date: $date',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  time.isEmpty ? 'Time: Any' : 'Time: $time',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterControls() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter ',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            
            // Sort by dropdown
            Row(
              children: [
                const Icon(Icons.sort, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'Search by:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Colors.grey.shade400,
                          width: 1,
                        ),
                      ),
                    ),
                    items: _sortOptions.map((option) {
                      String displayText = '';
                      switch (option) {
                        case 'dateTime':
                          displayText = 'Date & Time (Earliest)';
                          break;
                        case 'dateTimeDesc':
                          displayText = 'Date & Time (Latest)';
                          break;
                        case 'fareAsc':
                          displayText = 'Fare (Low to High)';
                          break;
                        case 'fareDesc':
                          displayText = 'Fare (High to Low)';
                          break;
                        case 'distance':
                          displayText = 'Distance (Nearest)';
                          break;
                      }
                      
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(
                          displayText,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _sortBy = newValue;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
          ],
        ),
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
        title: const Text(
          'Available Rides',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          // Optional: Manual cleanup button for testing
          IconButton(
            icon: const Icon(Icons.clean_hands),
            onPressed: () {
              _runAutoCleanup();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cleaning up completed rides...'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            tooltip: 'Cleanup completed rides',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('rides').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSearchSummaryBox(),
                  _buildFilterControls(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Error loading rides: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSearchSummaryBox(),
                  _buildFilterControls(),
                  const SizedBox(height: 16),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No rides in the system yet.',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final allRides = snapshot.data!.docs.map((doc) {
            final data = doc.data();
            return Ride.fromFirestore(data, doc.id);
          }).toList();

          // Trigger driver name fetch for all rides
          for (final ride in allRides) {
            _fetchDriverName(ride.driverId);
          }

          final fromLatLng = widget.fromLatLng;
          final toLatLng = widget.toLatLng;
          final fromText = (widget.fromLocation ?? '').toLowerCase().trim();
          final toText = (widget.toLocation ?? '').toLowerCase().trim();
          final selDate = (widget.selectedDate ?? '').trim();
          final selTime = (widget.selectedTime ?? '').toLowerCase().trim();

          // Apply initial filtering
          var filteredRides = allRides.where((ride) {
            final status = ride.status.toLowerCase();
            if (status == 'completed') return false;
            if (status.startsWith('cancelled')) return false;

            // NEW: Check if passenger already has active booking for this ride
            if (_hasActiveBookingForRide(ride)) {
              return false; // Hide rides that passenger already booked
            }

            bool matchesFrom = true;
            if (fromLatLng != null && ride.startLatLng != null) {
              final distanceInMeters = _distanceCalculator.as(
                LengthUnit.Meter,
                ride.startLatLng!,
                fromLatLng,
              );
              matchesFrom = distanceInMeters <= 5000;
            } else if (fromText.isNotEmpty) {
              matchesFrom = ride.start.toLowerCase().contains(fromText);
            }

            bool matchesTo = true;
            if (toLatLng != null && ride.endLatLng != null) {
              final distanceInMeters = _distanceCalculator.as(
                LengthUnit.Meter,
                ride.endLatLng!,
                toLatLng,
              );
              matchesTo = distanceInMeters <= 5000;
            } else if (toText.isNotEmpty) {
              matchesTo = ride.end.toLowerCase().contains(toText);
            }

            final matchesDate = selDate.isEmpty || ride.date.trim() == selDate;
            final matchesTime =
                selTime.isEmpty || ride.time.toLowerCase().contains(selTime);

            return matchesFrom && matchesTo && matchesDate && matchesTime;
          }).toList();

          // NEW: Apply latest rides filter
          filteredRides = _filterLatestRides(filteredRides);
          
          // NEW: Apply sorting
          filteredRides = _sortRides(filteredRides);

          if (filteredRides.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSearchSummaryBox(),
                  _buildFilterControls(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: Text(
                        'No rides available for your search criteria.',
                        style: TextStyle(
                          color: Colors.white70, 
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSearchSummaryBox(),
                const SizedBox(height: 12),
                _buildFilterControls(),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredRides.length,
                    itemBuilder: (context, index) {
                      final ride = filteredRides[index];
                      final car = ride.carDetails;
                      final driverName =
                          _driverNames[ride.driverId] ?? 'Driver';

                      // booking state for current passenger
                      Booking? passengerBooking;
                      if (_currentPassengerId.isNotEmpty) {
                        try {
                          passengerBooking = ride.bookings.firstWhere(
                            (b) => b.passengerId == _currentPassengerId,
                          );
                        } catch (_) {
                          passengerBooking = null;
                        }
                      }

                      // Button state
                      String buttonText;
                      Color buttonBgColor;
                      Color buttonTextColor;
                      VoidCallback? onBookPressed;
                      bool showChatButton = false;

                      if (passengerBooking == null) {
                        buttonText = 'Book';
                        buttonBgColor = bg;
                        buttonTextColor = Colors.white;
                        onBookPressed = () => _bookRide(ride);
                      } else {
                        switch (passengerBooking.status) {
                          case BookingStatus.pending:
                            buttonText = 'Pending';
                            buttonBgColor = Colors.orange.shade400;
                            buttonTextColor = Colors.white;
                            onBookPressed = null;
                            break;
                          case BookingStatus.accepted:
                            buttonText = 'Booked';
                            buttonBgColor = Colors.green.shade400;
                            buttonTextColor = Colors.white;
                            onBookPressed = null;
                            showChatButton = true;
                            break;
                          case BookingStatus.rejected:
                            buttonText = 'Book Again';
                            buttonBgColor = bg;
                            buttonTextColor = Colors.white;
                            onBookPressed = () => _bookRide(ride);
                            break;
                          case BookingStatus.cancelled:
                            buttonText = 'Cancelled';
                            buttonBgColor = Colors.grey.shade400;
                            buttonTextColor = Colors.white;
                            onBookPressed = null;
                            break;
                          case BookingStatus.confirmed:
                            buttonText = 'Confirmed';
                            buttonBgColor = Colors.blue.shade400;
                            buttonTextColor = Colors.white;
                            onBookPressed = null;
                            showChatButton = true;
                            break;
                        }
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ride status badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(ride.status),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ride.status.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // NEW: Show distance if available
                              if (widget.fromLatLng != null && ride.startLatLng != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Distance: ${_calculateDistanceToRide(ride).toStringAsFixed(0)}m',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // FROM / TO
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'FROM : ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54,
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
                                  const SizedBox(height: 2),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'TO :     ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black54,
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
                                ],
                              ),

                              const SizedBox(height: 8),

                              // DATE + TIME
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Date: ${ride.date}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Time: ${ride.time}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // FARE
                              Row(
                                children: [
                                  const Icon(
                                    Icons.money,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Fare: RM ${ride.fare.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // DRIVER NAME (under fare)
                              Text(
                                'Driver: $driverName',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blueGrey.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(height: 10),

                              // CAR DETAILS
                              const Text(
                                'Car Details:',
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Model: ${car.model}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Plate No: ${car.plateNumber}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Color: ${car.color}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Capacity: ${car.seatingDisplay}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Year: ${car.year}',
                                          style: const TextStyle(
                                            color: Colors.black54,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (car.insuranceCompany != null &&
                                            car.insuranceCompany!.isNotEmpty)
                                          Text(
                                            'Insurance: ${car.insuranceCompany}',
                                            style: const TextStyle(
                                              color: Colors.black54,
                                              fontSize: 14,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (car.imageUrl != null &&
                                      car.imageUrl!.isNotEmpty)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 16.0),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                        child: Image.network(
                                          car.imageUrl!,
                                          height: 100,
                                          width: 130,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.broken_image,
                                            color: Colors.grey,
                                            size: 60,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 15),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      onPressed: onBookPressed,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: buttonBgColor,
                                        foregroundColor: buttonTextColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: Text(
                                        buttonText,
                                        style: const TextStyle(fontSize: 16),
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper function to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}