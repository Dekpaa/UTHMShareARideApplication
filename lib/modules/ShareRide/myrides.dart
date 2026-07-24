import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uthmshareride/Component/Universal_nav_bar.dart';
import 'package:uthmshareride/modules/Driver/drawer.dart';
import 'package:uthmshareride/modules/Driver/driver_homepage.dart';
import 'package:uthmshareride/modules/Message/listchatdriver.dart';
import 'package:uthmshareride/modules/Payment/driver_review_payment.dart';
import 'package:uthmshareride/modules/Payment/passenger_paymentscreen.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/modules/Trackride/driver_trackride.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:collection/collection.dart';

class MyRidesPage extends StatefulWidget {
  final int initialTabIndex;

  const MyRidesPage({super.key, this.initialTabIndex = 0});

  @override
  State<MyRidesPage> createState() => _MyRidesPageState();
}

class _MyRidesPageState extends State<MyRidesPage>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 1;
  late TabController _tabController;

  late String _currentDriverId;
  late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _ridesStreamSub;

  final List<Ride> _allRides = [];
  final Map<String, String> _passengerNames = {};
  final Set<String> _requestedPassengerIds = {};
  final Map<String, Map<String, dynamic>> _bookingPaymentData = {};
  StreamSubscription<QuerySnapshot>? _bookingsSub;

  // Untuk sorting
  List<MapEntry<String, Map<String, dynamic>>> _sortedPayments = [];

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    _currentDriverId = user?.uid ?? '';

    if (_currentDriverId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in as driver'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }

    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(_handleTabSelection);

    _listenToRideUpdates();
    _listenToBookingPayments();
    _updateDriverRatingStats();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _ridesStreamSub.cancel();
    _bookingsSub?.cancel();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.index == 2) {
      _refreshPaymentData();
    }
    setState(() {});
  }

  void _refreshPaymentData() {
    // Refresh payment data when switching to payment tab
    setState(() {});
  }

  void _listenToRideUpdates() {
    _ridesStreamSub = FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: _currentDriverId)
        .snapshots()
        .listen((snapshot) {
          final rides =
              snapshot.docs
                  .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
                  .toList();

          if (!mounted) return;

          setState(() {
            _allRides
              ..clear()
              ..addAll(rides);
          });

          for (final ride in rides) {
            for (final booking in ride.bookings) {
              _fetchPassengerName(booking.passengerId);
            }
          }
        });
  }

  void _listenToBookingPayments() {
    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('driverId', isEqualTo: _currentDriverId)
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          setState(() {
            _bookingPaymentData.clear();
            for (var doc in snapshot.docs) {
              final data = doc.data();
              _bookingPaymentData[doc.id] = {...data, 'bookingDocId': doc.id};
            }
            
            // Sort payment data
            _sortPaymentData();
          });
        });
  }

  // Fungsi untuk parse date string ke DateTime
  DateTime? _parseRideDateTime(Ride ride) {
    try {
      // Format expected: "DD/MM/YYYY" untuk date dan "HH:MM" untuk time
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

  // Fungsi untuk sort rides berdasarkan date dan time
  List<Ride> _sortRidesByDateTime(List<Ride> rides, {bool ascending = false}) {
    return List.from(rides)
      ..sort((a, b) {
        final dateTimeA = _parseRideDateTime(a);
        final dateTimeB = _parseRideDateTime(b);
        
        // Jika kedua-dua boleh parse, bandingkan
        if (dateTimeA != null && dateTimeB != null) {
          return ascending 
              ? dateTimeA.compareTo(dateTimeB)
              : dateTimeB.compareTo(dateTimeA); // Descending (terkini dulu)
        }
        
        // Jika salah satu null, letak yang null di belakang
        if (dateTimeA == null && dateTimeB != null) {
          return ascending ? 1 : -1;
        }
        if (dateTimeA != null && dateTimeB != null) {
          return ascending ? -1 : 1;
        }
        
        // Jika kedua-dua null, sort berdasarkan ID
        return a.id.compareTo(b.id);
      });
  }

  // Fungsi untuk sort payment data berdasarkan submission date
  void _sortPaymentData() {
    _sortedPayments = _bookingPaymentData.entries.toList()
      ..sort((a, b) {
        final dateA = a.value['paymentSubmittedAt'] as Timestamp?;
        final dateB = b.value['paymentSubmittedAt'] as Timestamp?;
        
        if (dateA != null && dateB != null) {
          return dateB.compareTo(dateA); // Terbaru dulu
        }
        
        if (dateA == null && dateB != null) return 1;
        if (dateA != null && dateB != null) return -1;
        
        return 0;
      });
  }

  Future<void> _fetchPassengerName(String passengerId) async {
    if (passengerId.isEmpty) return;

    if (_passengerNames.containsKey(passengerId) ||
        _requestedPassengerIds.contains(passengerId)) {
      return;
    }

    _requestedPassengerIds.add(passengerId);

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('passengers')
              .doc(passengerId)
              .get();

      String name = 'Passenger';
      if (doc.exists) {
        name = (doc.data()?['fullName'] ?? 'Passenger').toString();
      }

      if (!mounted) return;
      setState(() {
        _passengerNames[passengerId] = name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _passengerNames[passengerId] = 'Passenger';
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DriverHomepage()),
      );
    } else if (index == 1) {
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ListChatDriverPage()),
      );
    }
  }

  Map<String, dynamic>? _getPaymentDataForBooking(Booking booking) {
    for (var entry in _bookingPaymentData.entries) {
      final data = entry.value;
      if (data['rideId'] == booking.rideId &&
          data['passengerId'] == booking.passengerId) {
        return data;
      }
    }
    return null;
  }

  String? _getBookingDocumentId(Booking booking) {
    for (var entry in _bookingPaymentData.entries) {
      final data = entry.value;
      if (data['rideId'] == booking.rideId &&
          data['passengerId'] == booking.passengerId) {
        return entry.key;
      }
    }
    return null;
  }

  Ride? _getRideById(String rideId) {
    try {
      return _allRides.firstWhere((r) => r.id == rideId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateRideFields(
    String rideId,
    Map<String, dynamic> data,
  ) async {
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .update(data);
  }

  Future<void> _updateBookingsOnFirestore(
    String rideId,
    List<Booking> bookings,
  ) async {
    await _updateRideFields(rideId, {
      'bookings': bookings.map((b) => b.toMap()).toList(),
    });
  }

  Future<void> _acceptBooking(String rideId, String bookingId) async {
    final ride = _getRideById(rideId);
    if (ride == null) return;

    Booking? acceptedBooking;

    final updatedBookings =
        ride.bookings.map((b) {
          if (b.id == bookingId) {
            acceptedBooking = b;
            return Booking(
              id: b.id,
              passengerId: b.passengerId,
              passengerName: b.passengerName,
              status: BookingStatus.accepted,
              isPaid: b.isPaid,
              rating: b.rating,
              review: b.review,
              rideId: rideId,
            );
          }
          return b;
        }).toList();

    await _updateBookingsOnFirestore(rideId, updatedBookings);

    if (acceptedBooking != null) {
      await _createBookingDocument(ride: ride, booking: acceptedBooking!);
      await _createChatRoomOnAccept(ride: ride, booking: acceptedBooking!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking Accepted! Chat room created.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _createBookingDocument({
    required Ride ride,
    required Booking booking,
  }) async {
    try {
      final bookingId = '${ride.id}_${booking.passengerId}';

      final passengerName =
          _passengerNames[booking.passengerId] ??
          booking.passengerName ??
          'Passenger';

      final driverDoc =
          await FirebaseFirestore.instance
              .collection('drivers')
              .doc(_currentDriverId)
              .get();
      final driverName =
          driverDoc.data()?['fullName'] ??
          FirebaseAuth.instance.currentUser?.displayName ??
          'Driver';

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .set({
            'id': bookingId,
            'rideId': ride.id,
            'driverId': ride.driverId,
            'passengerId': booking.passengerId,
            'passengerName': passengerName,
            'driverName': driverName,
            'status': 'accepted',
            'fare': ride.fare,
            'paymentStatus': 'none',
            'isPaid': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error creating booking document: $e');
    }
  }

  Future<void> _rejectBooking(String rideId, String bookingId) async {
    final ride = _getRideById(rideId);
    if (ride == null) return;

    final updatedBookings =
        ride.bookings
            .map(
              (b) => Booking(
                id: b.id,
                passengerId: b.passengerId,
                passengerName: b.passengerName,
                status: b.id == bookingId ? BookingStatus.rejected : b.status,
                isPaid: b.isPaid,
                rating: b.rating,
                review: b.review,
                rideId: rideId,
              ),
            )
            .toList();

    await _updateBookingsOnFirestore(rideId, updatedBookings);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Booking Rejected!'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _markRideAsCompleted(String rideId) async {
    final ride = _getRideById(rideId);
    if (ride == null) return;

    if (ride.status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride is already completed'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final updatedBookings =
        ride.bookings
            .map(
              (b) => Booking(
                id: b.id,
                passengerId: b.passengerId,
                passengerName: b.passengerName,
                status: b.status,
                isPaid: b.isPaid,
                rating: b.rating,
                review: b.review,
                rideId: rideId,
              ),
            )
            .toList();

    await _updateRideFields(rideId, {
      'status': 'completed',
      'isTracking': false,
      'hasArrived': true,
      'completedAt': FieldValue.serverTimestamp(),
      'bookings': updatedBookings.map((b) => b.toMap()).toList(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ride marked as Completed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _cancelRide(String rideId) async {
    final bg = hexStringToColor("365770");

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Cancel Ride'),
            content: const Text(
              'Are you sure you want to cancel this ride? All pending bookings will be rejected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('No', style: TextStyle(color: bg)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ride = _getRideById(rideId);
                  if (ride == null) {
                    Navigator.pop(context);
                    return;
                  }

                  final updatedBookings =
                      ride.bookings
                          .map(
                            (b) => Booking(
                              id: b.id,
                              passengerId: b.passengerId,
                              passengerName: b.passengerName,
                              status:
                                  b.status == BookingStatus.pending
                                      ? BookingStatus.rejected
                                      : b.status,
                              isPaid: b.isPaid,
                              rating: b.rating,
                              review: b.review,
                              rideId: rideId,
                            ),
                          )
                          .toList();

                  await _updateRideFields(rideId, {
                    'status': 'cancelled_by_driver',
                    'isTracking': false,
                    'hasArrived': false,
                    'cancelledAt': FieldValue.serverTimestamp(),
                    'bookings': updatedBookings.map((b) => b.toMap()).toList(),
                  });

                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ride cancelled!'),
                      backgroundColor: Colors.red,
                    ),
                  );
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

  Future<void> _createChatRoomOnAccept({
    required Ride ride,
    required Booking booking,
  }) async {
    final roomId = '${ride.id}_${booking.passengerId}';

    final passengerName =
        _passengerNames[booking.passengerId] ??
        booking.passengerName ??
        'Passenger';

    await FirebaseFirestore.instance.collection('chat_rooms').doc(roomId).set({
      'roomId': roomId,
      'rideId': ride.id,
      'driverId': FirebaseAuth.instance.currentUser!.uid,
      'passengerId': booking.passengerId,
      'driverName': FirebaseAuth.instance.currentUser?.displayName ?? 'Driver',
      'driverPhotoUrl': '',
      'passengerName': passengerName,
      'passengerPhotoUrl': '',
      'lastMessage': 'Booking accepted. You can start chatting now.',
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _startDriverTracking(String rideId) async {
    if (_currentDriverId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver not logged in.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final ride = _getRideById(rideId);
    if (ride == null) return;

    if (ride.isTracking == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverTrackRidePage(
            rideId: rideId,
            driverId: _currentDriverId,
            isResuming: true,
          ),
        ),
      );
      return;
    }

    if (ride.hasArrived == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride already arrived. Cannot start tracking.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (ride.status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride already completed. Cannot start tracking.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (ride.status.startsWith('cancelled_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride cancelled. Cannot start tracking.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _updateRideFields(rideId, {
      'isTracking': true,
      'hasArrived': false,
      'trackingStartedAt': FieldValue.serverTimestamp(),
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriverTrackRidePage(
          rideId: rideId,
          driverId: _currentDriverId,
          isResuming: false,
        ),
      ),
    );
  }

  // ==================== FIXED: APPROVE PAYMENT ====================
  Future<void> _approvePassengerPayment(
    String rideId,
    Booking booking,
    String bookingDocId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingDocId)
          .update({
            'paymentStatus': 'approved',
            'paymentApprovedAt': FieldValue.serverTimestamp(),
            'approvalNote': 'Payment approved by driver',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      final ride = _getRideById(rideId);
      if (ride == null) return;

      final updatedBookings =
          ride.bookings.map((b) {
            if (b.passengerId == booking.passengerId) {
              return Booking(
                id: b.id,
                passengerId: b.passengerId,
                passengerName: b.passengerName,
                status: b.status,
                isPaid: true,
                rating: b.rating,
                review: b.review,
                rideId: rideId,
              );
            }
            return b;
          }).toList();

      await _updateBookingsOnFirestore(rideId, updatedBookings);

      await RideStorage().updateBookingPaymentStatus(rideId, booking.id, true);

      await _sendNotification(
        bookingDocId,
        'Payment Approved',
        'Your payment has been approved by driver.',
        booking.passengerId,
      );

      // REMOVE FROM PENDING LIST
      if (!mounted) return;
      setState(() {
        _bookingPaymentData.remove(bookingDocId);
        _sortPaymentData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment approved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _refreshPaymentData();
    } catch (e) {
      print('Error approving payment: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== FIXED: REJECT PAYMENT WITH REASON ====================
  Future<void> _rejectPassengerPayment(
    String rideId,
    Booking booking,
    String bookingDocId,
    String rejectionReason,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingDocId)
          .update({
            'paymentStatus': 'rejected',
            'rejectionReason': rejectionReason,
            'paymentRejectedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      final ride = _getRideById(rideId);
      if (ride == null) return;

      final updatedBookings = ride.bookings.map((b) {
        if (b.passengerId == booking.passengerId) {
          return Booking(
            id: b.id,
            passengerId: b.passengerId,
            passengerName: b.passengerName,
            status: b.status,
            isPaid: false,
            rating: b.rating,
            review: b.review,
            rideId: rideId,
          );
        }
        return b;
      }).toList();

      await _updateBookingsOnFirestore(rideId, updatedBookings);

      await RideStorage().updateBookingPaymentStatus(
        rideId,
        booking.id,
        false,
      );

      await _sendNotification(
        bookingDocId,
        'Payment Rejected',
        'Your payment was rejected. Reason: $rejectionReason',
        booking.passengerId,
      );

      // REMOVE FROM PENDING LIST
      if (!mounted) return;
      setState(() {
        _bookingPaymentData.remove(bookingDocId);
        _sortPaymentData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment rejected. Passenger will resubmit payment.'),
          backgroundColor: Colors.orange,
        ),
      );

      _refreshPaymentData();
    } catch (e) {
      print('Error rejecting payment: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _sendNotification(
    String bookingId,
    String title,
    String message,
    String passengerId,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'bookingId': bookingId,
        'passengerId': passengerId,
        'driverId': _currentDriverId,
        'title': title,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'payment_update',
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  void _viewReceipt(
    BuildContext context, {
    required String receiptUrl,
    required String receiptType,
    required String passengerName,
  }) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Receipt from $passengerName'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (receiptType == 'pdf')
                    const Column(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 60, color: Colors.red),
                        SizedBox(height: 10),
                        Text(
                          'PDF Receipt',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  else
                    Image.network(
                      receiptUrl,
                      height: 300,
                      fit: BoxFit.contain,
                      errorBuilder:
                          (_, __, ___) => const Column(
                            children: [
                              Icon(Icons.error, size: 60, color: Colors.red),
                              SizedBox(height: 10),
                              Text('Cannot load receipt image'),
                            ],
                          ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: hexStringToColor("365770"))),
              ),
            ],
          ),
    );
  }

  // ==================== FIXED: CONFIRM APPROVE PAYMENT ====================
  Future<void> _confirmApprovePayment(
    BuildContext context,
    String rideId,
    Booking booking,
    Map<String, dynamic> paymentData,
  ) async {
    final bookingDocId = paymentData['bookingDocId'];
    if (bookingDocId == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Approve Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Are you sure you want to approve this payment?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: hexStringToColor("365770"))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _approvePassengerPayment(rideId, booking, bookingDocId);
                },
                child: const Text('Approve'),
              ),
            ],
          ),
    );
  }

  // ==================== FIXED: CONFIRM REJECT PAYMENT WITH REASON INPUT ====================
  Future<void> _confirmRejectPayment(
    BuildContext context,
    String rideId,
    Booking booking,
    Map<String, dynamic> paymentData,
  ) async {
    final bookingDocId = paymentData['bookingDocId'];
    if (bookingDocId == null) return;

    TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Reject Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please provide a reason for rejection:'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Wrong amount, blur receipt, etc.',
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: hexStringToColor("365770"))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason for rejection'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(context);
                  await _rejectPassengerPayment(rideId, booking, bookingDocId, reason);
                },
                child: const Text('Reject with Reason'),
              ),
            ],
          );
        },
      ),
    );
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

  // Fungsi untuk mendapatkan sorted ongoing rides
  List<Ride> _getSortedOngoingRides() {
    final ongoingRides = _allRides.where((ride) {
      return ride.driverId == _currentDriverId &&
          ride.status == 'ongoing' &&
          !ride.hasArrived;
    }).toList();
    
    return _sortRidesByDateTime(ongoingRides);
  }

  Widget _buildOngoingRidesContent() {
    final sortedOngoingRides = _getSortedOngoingRides();

    if (sortedOngoingRides.isEmpty) {
      return _buildEmptyState(
        "No ongoing rides",
        Icons.directions_car,
        "Share a ride to see it here!",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedOngoingRides.length,
      itemBuilder: (context, index) {
        final ride = sortedOngoingRides[index];
        final acceptedBookings =
            ride.bookings
                .where((b) => b.status == BookingStatus.accepted)
                .toList();

        final pendingBookings =
        ride.bookings
            .where((b) => b.status == BookingStatus.pending)
            .toList();
        
        bool shouldShowCancelButton = acceptedBookings.isEmpty;
        bool shouldShowTrackingButton = acceptedBookings.isNotEmpty;
        
        return _buildRideCard(
          ride: ride,
          acceptedBookings: acceptedBookings,
          showPaymentActions: true,
          showTrackingButton: shouldShowTrackingButton,
          showCompleteButton: true,
          showCancelButton: shouldShowCancelButton,
        );
      },
    );
  }

  // Fungsi untuk mendapatkan sorted pending rides
  List<Ride> _getSortedPendingRides() {
    final pendingRides = _allRides.where((ride) {
      return ride.driverId == _currentDriverId &&
          ride.bookings.any(
            (booking) => booking.status == BookingStatus.pending,
          );
    }).toList();
    
    return _sortRidesByDateTime(pendingRides);
  }

  Widget _buildPendingRidesContent() {
    final sortedPendingRides = _getSortedPendingRides();

    if (sortedPendingRides.isEmpty) {
      return _buildEmptyState(
        "No pending ride requests",
        Icons.pending_actions,
        "Passenger requests will appear here",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedPendingRides.length,
      itemBuilder: (context, index) {
        final ride = sortedPendingRides[index];
        final pendingBookings =
            ride.bookings
                .where((b) => b.status == BookingStatus.pending)
                .toList();

        return _buildRideCard(
          ride: ride,
          pendingBookings: pendingBookings,
          showBookingActions: true,
        );
      },
    );
  }

  // ==================== FIXED: PAYMENT REVIEW CONTENT ====================
  Widget _buildPaymentReviewContent() {
    // FILTER HANYA yang status == 'submitted'
    final pendingPayments = _sortedPayments
        .where((entry) => entry.value['paymentStatus'] == 'submitted')
        .toList();

    final pendingCount = pendingPayments.length;

    return Column(
      children: [
        Expanded(
          child:
              pendingCount > 0
                  ? _buildPaymentList(pendingPayments)
                  : _buildNoPaymentsState(),
        ),
      ],
    );
  }

  Widget _buildPaymentList(
    List<MapEntry<String, Map<String, dynamic>>> payments,
  ) {
    final bg = hexStringToColor("365770");
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final entry = payments[index];
        final paymentData = entry.value;
        final bookingDocId = entry.key;
        final rideId = paymentData['rideId'];
        final passengerId = paymentData['passengerId'];
        final passengerName = paymentData['passengerName'] ?? 'Passenger';
        final fare = paymentData['fare'] ?? 0.0;
        final receiptUrl = paymentData['receiptUrl'];
        final submittedAt = paymentData['paymentSubmittedAt'];

        final ride = _getRideById(rideId);
        if (ride == null) return Container();

        final booking = FirstWhereOrNullExtension(ride.bookings).firstWhereOrNull(
          (b) => b.passengerId == passengerId,
        );

        if (booking == null) return Container();

        return Card(
          color: Colors.white.withOpacity(0.95),
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bg.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.person,
                        color: bg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passengerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (submittedAt != null)
                            Text(
                              'Submitted: ${_formatDate(submittedAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'PENDING',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.blueGrey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${ride.start} → ${ride.end}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RM ${fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (receiptUrl != null)
                  Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            () => _viewReceipt(
                              context,
                              receiptUrl: receiptUrl,
                              receiptType:
                                  paymentData['receiptFileType'] ?? 'image',
                              passengerName: passengerName,
                            ),
                        icon: const Icon(Icons.receipt, size: 16, color: Colors.white),
                        label: const Text('View Receipt', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bg,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 40),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed:
                          () => _confirmRejectPayment(
                            context,
                            ride.id,
                            booking,
                            paymentData,
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed:
                          () => _confirmApprovePayment(
                            context,
                            ride.id,
                            booking,
                            paymentData,
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoPaymentsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green.shade300),
          const SizedBox(height: 20),
          const Text(
            'Payments Reviewed',
            style: TextStyle(
              fontSize: 20,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'You have no pending payments to review at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk mendapatkan sorted completed rides
  List<Ride> _getSortedCompletedRides() {
    final completedRides = _allRides.where((ride) {
      return ride.driverId == _currentDriverId &&
          ride.status == 'completed';
    }).toList();
    
    return _sortRidesByDateTime(completedRides);
  }

  Widget _buildCompletedRidesContent() {
    final sortedCompletedRides = _getSortedCompletedRides();

    if (sortedCompletedRides.isEmpty) {
      return _buildEmptyState(
        "No completed rides",
        Icons.check_circle,
        "Completed rides will appear here",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedCompletedRides.length,
      itemBuilder: (context, index) {
        final ride = sortedCompletedRides[index];

        final acceptedBookings = ride.bookings
            .where((b) => b.status == BookingStatus.accepted)
            .toList();

        int paidCount = 0;
        List<Map<String, dynamic>> passengerRatings = [];

        for (var booking in acceptedBookings) {
          final bookingData = _getBookingDataFromFirestore(booking);

          if (bookingData != null &&
              bookingData['paymentStatus'] == 'approved') {
            paidCount++;
          }

          if (bookingData != null &&
              bookingData['rating'] != null &&
              bookingData['rating'] > 0) {

            passengerRatings.add({
              'passengerName':
                  _passengerNames[booking.passengerId] ??
                  booking.passengerName ??
                  'Passenger',
              'rating': bookingData['rating'],
              'review': bookingData['review'] ?? '',
              'ratedAt': bookingData['ratedAt'],
            });
          }
        }

        return _buildCompletedRideCard(
          ride: ride,
          acceptedBookings: acceptedBookings,
          paidCount: paidCount,
          passengerRatings: passengerRatings,
          rideRatings: passengerRatings,
        );
      },
    );
  }

  Widget _buildCompletedRideCard({
    required Ride ride,
    required List<Booking> acceptedBookings,
    required int paidCount,
    required List<Map<String, dynamic>> passengerRatings,
    required List<Map<String, dynamic>> rideRatings,
  }) {
    final ratingSummary = _calculateRatingsSummary(rideRatings);
    final totalRatings = ratingSummary['total'] as int;
    final averageRating = ratingSummary['average'] as double;

    return Card(
      color: Colors.white.withOpacity(0.95),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                      'FROM : ',
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
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TO :     ',
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
              ],
            ),

            const SizedBox(height: 8),

            _buildDateTimeFare(
              ride,
              fareColor: Colors.green[700],
            ),

            const SizedBox(height: 10),

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
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            if (acceptedBookings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Passengers:',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ...acceptedBookings.map((booking) {
                final passengerName =
                    _passengerNames[booking.passengerId] ??
                    booking.passengerName ??
                    'Passenger';
                final bookingData = _getBookingDataFromFirestore(booking);
                final isPaid = bookingData?['paymentStatus'] == 'approved';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          passengerName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isPaid ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPaid
                                ? Colors.green.shade200
                                : Colors.orange.shade200,
                          ),
                        ),
                        child: Text(
                          isPaid ? 'PAID' : 'UNPAID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isPaid
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(width: 12),
            if (passengerRatings.isNotEmpty) ...[
              Text(
                'Rating and Review:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ...passengerRatings.map((rating) {
                return _buildPassengerRatingCard(rating);
              }).toList(),
            ],

          ],
        ),
      ),
    );
  }

  Widget _buildPassengerRatingCard(Map<String, dynamic> rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      rating['passengerName'] ?? 'Passenger',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      Icons.star,
                      size: 16,
                      color: index < (rating['rating'] as int? ?? 0)
                          ? Colors.amber
                          : Colors.grey[300],
                    );
                  }),
                ),
              ],
            ),
            
            if (rating['review'] != null && rating['review'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Review"${rating['review']}"',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            if (rating['ratedAt'] != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatRatingDate(rating['ratedAt']),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatRatingDate(dynamic timestamp) {
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
  
  Map<String, dynamic>? _getBookingDataFromFirestore(Booking booking) {
    for (var entry in _bookingPaymentData.entries) {
      final data = entry.value;
      if (data['rideId'] == booking.rideId &&
          data['passengerId'] == booking.passengerId) {
        return data;
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getPassengerRatings(String rideId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('rideId', isEqualTo: rideId)
          .where('driverId', isEqualTo: _currentDriverId)
          .where('rating', isGreaterThan: 0)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'bookingId': doc.id,
          'rating': data['rating'] ?? 0,
          'review': data['review'] ?? '',
          'ratedAt': data['ratedAt'],
          'passengerId': data['passengerId'],
          'passengerName': data['passengerName'] ?? 'Passenger',
        };
      }).toList();
    } catch (e) {
      print('Error fetching passenger ratings: $e');
      return [];
    }
  }

  Map<String, dynamic> _calculateRatingsSummary(List<Map<String, dynamic>> ratings) {
    if (ratings.isEmpty) {
      return {
        'average': 0.0,
        'total': 0,
        'distribution': {5: 0, 4: 0, 3: 0, 2: 0, 1: 0},
      };
    }

    double totalRating = 0;
    Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    for (var rating in ratings) {
      final stars = rating['rating'] as int;
      totalRating += stars;
      distribution[stars] = (distribution[stars] ?? 0) + 1;
    }

    return {
      'average': totalRating / ratings.length,
      'total': ratings.length,
      'distribution': distribution,
    };
  }

  Future<void> _updateDriverRatingStats() async {
    try {
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('driverId', isEqualTo: _currentDriverId)
          .where('rating', isGreaterThan: 0)
          .get();

      if (ratingsSnapshot.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('drivers').doc(_currentDriverId).update({
          'averageRating': 0.0,
          'totalRatings': 0,
          'ratingUpdatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      double totalRating = 0;
      int totalRatings = 0;
      Map<int, int> distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

      for (final doc in ratingsSnapshot.docs) {
        final rating = doc.data()['rating'] as int?;
        if (rating != null && rating > 0) {
          totalRating += rating.toDouble();
          totalRatings++;
          distribution[rating] = (distribution[rating] ?? 0) + 1;
        }
      }

      final averageRating = totalRatings > 0 ? totalRating / totalRatings : 0.0;

      await FirebaseFirestore.instance.collection('drivers').doc(_currentDriverId).update({
        'averageRating': double.parse(averageRating.toStringAsFixed(1)),
        'totalRatings': totalRatings,
        'ratingDistribution': distribution,
        'ratingUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Updated rating stats for driver: $_currentDriverId');
    } catch (e) {
      print('❌ Error updating driver rating stats: $e');
    }
  }

  // Fungsi untuk mendapatkan sorted cancelled rides
  List<Ride> _getSortedCancelledRides() {
    final cancelledRides = _allRides.where((ride) {
      final isCancelledStatus =
          ride.status.startsWith('cancelled_') ||
          (ride.bookings.isNotEmpty &&
              ride.bookings.every(
                (b) =>
                    b.status == BookingStatus.rejected ||
                    b.status == BookingStatus.cancelled,
              ));

      return ride.driverId == _currentDriverId && isCancelledStatus;
    }).toList();
    
    return _sortRidesByDateTime(cancelledRides);
  }

  Widget _buildCancelledRidesContent() {
    final sortedCancelledRides = _getSortedCancelledRides();

    if (sortedCancelledRides.isEmpty) {
      return _buildEmptyState(
        "No cancelled rides",
        Icons.cancel,
        "Cancelled rides will appear here",
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: sortedCancelledRides.length,
      itemBuilder: (context, index) {
        final ride = sortedCancelledRides[index];
        final rejectedBookings =
            ride.bookings
                .where((b) => b.status == BookingStatus.rejected)
                .toList();

        String cancellationReason = '';
        if (ride.status == 'cancelled_by_driver') {
          cancellationReason = 'Cancelled by Driver';
        } else if (ride.status == 'cancelled_by_passenger') {
          cancellationReason = 'Cancelled by Passenger';
        } else if (rejectedBookings.isNotEmpty) {
          cancellationReason = 'Rejected by Driver';
        }

        return _buildRideCard(
          ride: ride,
          rejectedBookings: rejectedBookings,
          cancellationReason: cancellationReason,
          showCancelledStatus: true,
        );
      },
    );
  }

  Widget _buildRideCard({
    required Ride ride,
    List<Booking>? acceptedBookings,
    List<Booking>? pendingBookings,
    List<Booking>? rejectedBookings,
    String? cancellationReason,
    int paidCount = 0,
    int totalRatings = 0,
    double averageRating = 0.0,
    List<Map<String, dynamic>> passengerRatings = const [],
    bool showPaymentActions = false,
    bool showBookingActions = false,
    bool showTrackingButton = false,
    bool showCompleteButton = false,
    bool showCancelButton = false,
    bool showCompletedStatus = false,
    bool showCancelledStatus = false,
  }) {
    final bg = hexStringToColor("365770");
    
    return Card(
      color: Colors.white.withOpacity(0.95),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                      'FROM : ',
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
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TO :     ',
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
              ],
            ),

            const SizedBox(height: 8),

            _buildDateTimeFare(
              ride,
              fareColor: showCancelledStatus ? Colors.red[700] : null,
            ),

            const SizedBox(height: 10),

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

            if (pendingBookings != null && pendingBookings.isNotEmpty) ...[
              const Divider(height: 20, color: Colors.grey),
              Text(
                'Pending Bookings:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
              ),
              ...pendingBookings.map((booking) {
                final passengerName =
                    _passengerNames[booking.passengerId] ??
                    booking.passengerName ??
                    'Passenger';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person,
                        size: 20,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Passenger: $passengerName',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      if (showBookingActions)
                        Wrap(
                          spacing: 8.0,
                          children: [
                            ElevatedButton(
                              onPressed:
                                  () => _acceptBooking(ride.id, booking.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              child: const Text('Accept'),
                            ),
                            ElevatedButton(
                              onPressed:
                                  () => _rejectBooking(ride.id, booking.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              }),
            ],

            if (acceptedBookings != null && acceptedBookings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Passengers:',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ...acceptedBookings.map((booking) {
                final passengerName =
                    _passengerNames[booking.passengerId] ??
                    booking.passengerName ??
                    'Passenger';
                final paymentData = _getPaymentDataForBooking(booking);
                final paymentStatus = paymentData?['paymentStatus'] ?? 'none';
                final isPaid =
                    paymentStatus == 'approved' || booking.isPaid == true;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '• $passengerName',
                              style: TextStyle(
                                fontSize: 14,
                                color: isPaid ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (booking.rating != null && booking.rating! > 0)
                          Row(
                            children: [
                              ...List.generate(
                                booking.rating!,
                                (index) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                              ),
                              if (booking.review != null && 
                                  booking.review!.isNotEmpty)
                                const SizedBox(width: 4),
                              if (booking.review != null && 
                                  booking.review!.isNotEmpty)
                                Icon(
                                  Icons.comment,
                                  size: 14,
                                  color: Colors.blueGrey,
                                ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isPaid
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isPaid
                                        ? Colors.green.shade200
                                        : Colors.orange.shade200,
                              ),
                            ),
                            child: Text(
                              isPaid ? 'PAID' : 'UNPAID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    isPaid
                                        ? Colors.green.shade800
                                        : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                        if (booking.review != null && 
                        booking.review!.isNotEmpty && 
                        booking.rating != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0, top: 2.0),
                        child: Text(
                          '"${booking.review!}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      if (showPaymentActions &&
                          paymentData != null &&
                          paymentData['receiptUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, left: 12.0),
                          child: Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed:
                                    () => _viewReceipt(
                                      context,
                                      receiptUrl: paymentData['receiptUrl'],
                                      receiptType:
                                          paymentData['receiptFileType'] ??
                                          'image',
                                      passengerName: passengerName,
                                    ),
                                icon: const Icon(Icons.receipt, size: 16, color: Colors.white),
                                label: const Text('View Receipt', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: bg,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(0, 30),
                                ),
                              ),

                              if (paymentStatus == 'submitted') ...[
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed:
                                      () => _confirmApprovePayment(
                                        context,
                                        ride.id,
                                        booking,
                                        paymentData,
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 30),
                                  ),
                                  icon: const Icon(Icons.check, size: 14, color: Colors.white),
                                  label: const Text('Approve', style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed:
                                      () => _confirmRejectPayment(
                                        context,
                                        ride.id,
                                        booking,
                                        paymentData,
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 30),
                                  ),
                                  icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                  label: const Text('Reject', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            
                              if (paymentStatus == 'rejected')
                                Text(
                                  '❌ Payment rejected',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),

                              if (paymentStatus == 'approved')
                                Text(
                                  '✅ Payment approved',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green[700],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          
          if (showCompletedStatus && totalRatings > 0) ...[
            const Divider(height: 20, color: Colors.grey),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Passenger Ratings:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($totalRatings ${totalRatings > 1 ? 'ratings' : 'rating'})',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (passengerRatings.length > 1) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent feedback from passengers:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...passengerRatings.take(3).map((rating) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.shade50,
                              ),
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ...List.generate(
                                        rating['rating'],
                                        (index) => const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        rating['passengerName'],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (rating['review'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        rating['review'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ],
          if (passengerRatings.length > 3) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _showAllRatingsDialog(context, passengerRatings);
                },
                icon: const Icon(Icons.more_horiz, size: 16),
                label: const Text('View all feedback'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
            if (rejectedBookings != null && rejectedBookings.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Rejected Bookings:',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              ...rejectedBookings.map((booking) {
                final passengerName =
                    _passengerNames[booking.passengerId] ??
                    booking.passengerName ??
                    'Passenger';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    '• $passengerName',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                );
              }),
            ],

      if (showCompletedStatus || showCancelledStatus) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (showCompletedStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (showCompletedStatus && totalRatings > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '$averageRating ($totalRatings)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (showCancelledStatus)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel, size: 14, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          'Cancelled ($cancellationReason)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (showCompletedStatus && paidCount > 0) const Spacer(),

                if (showCompletedStatus && paidCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Paid: $paidCount/${acceptedBookings?.length ?? 0}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ],

            if (showTrackingButton ||
                showCompleteButton ||
                showCancelButton) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    if (showTrackingButton && !ride.hasArrived)
                      ElevatedButton.icon(
                        onPressed: () => _startDriverTracking(ride.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ride.isTracking 
                              ? Colors.blueAccent
                              : bg,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: Icon(
                          ride.isTracking 
                              ? Icons.location_on
                              : Icons.play_arrow,
                          size: 16,
                          color: Colors.white,
                        ),
                        label: Text(
                          ride.isTracking 
                              ? 'Resume Tracking'
                              : ride.hasArrived 
                                  ? 'Ride Arrived'
                                  : 'Start Tracking',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),

                    if (showCompleteButton && ride.hasArrived && ride.status != 'completed')
                      ElevatedButton.icon(
                        onPressed: () => _markRideAsCompleted(ride.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                        label: const Text('Complete Ride', style: TextStyle(color: Colors.white)),
                      ),

                    if (showCancelButton &&
                        !ride.isTracking && 
                        !ride.hasArrived &&
                        ride.status != 'completed' &&
                        !ride.status.startsWith('cancelled_'))
                      ElevatedButton.icon(
                        onPressed: () => _cancelRide(ride.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.cancel, size: 16, color: Colors.white),
                        label: const Text('Cancel Ride', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, [String? subtitle]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return const DriverHomepage();
      case 1:
        return const MyRidesPage();
      case 2:
        return const ListChatDriverPage();
      default:
        return const DriverHomepage();
    }
  }

  void _showAllRatingsDialog(
    BuildContext context,
    List<Map<String, dynamic>> ratings,
  ) {
    final bg = hexStringToColor("365770");
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('All Passenger Ratings'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var rating in ratings)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.blue.shade50,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 20,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rating['passengerName'] ?? 'Passenger',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (rating['ratedAt'] != null)
                                      Text(
                                        _formatRatingDate(rating['ratedAt']),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ...List.generate(
                                rating['rating'],
                                (index) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                          if (rating['review'] != null &&
                              rating['review'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '"${rating['review']}"',
                                style: TextStyle(
                                  fontSize: 13,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: bg)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = hexStringToColor("365770");
    const double bottomNavArea = 96;

    return Scaffold(
      extendBody: true,
      drawer: const DriverAppDrawer(),
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Text(
            "My Rides",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
                Tab(text: "Ongoing"),
                Tab(text: "Pending"),
                Tab(text: "Payments"),
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
                  _buildOngoingRidesContent(),
                  _buildPendingRidesContent(),
                  _buildPaymentReviewContent(),
                  _buildCompletedRidesContent(),
                  _buildCancelledRidesContent(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: UniversalBottomNavBar.driver(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
      ),
    );
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}