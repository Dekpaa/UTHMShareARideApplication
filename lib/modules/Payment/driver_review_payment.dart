// File: lib/modules/ShareRide/driver_payment_review_page.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:collection/collection.dart';

class DriverPaymentReviewPage extends StatefulWidget {
  const DriverPaymentReviewPage({super.key});

  @override
  State<DriverPaymentReviewPage> createState() => _DriverPaymentReviewPageState();
}

class _DriverPaymentReviewPageState extends State<DriverPaymentReviewPage> {
  late String _currentDriverId;
  final Map<String, Map<String, dynamic>> _pendingPayments = {};
  final List<Ride> _allRides = [];
  final Map<String, String> _passengerNames = {};
  final Set<String> _requestedPassengerIds = {};
  
  StreamSubscription<QuerySnapshot>? _bookingsSub;
  StreamSubscription<QuerySnapshot>? _ridesSub;
  
  bool _isLoading = true;

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
    
    _loadAllData();
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _ridesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      // 1. Load all rides for this driver
      final ridesSnapshot = await FirebaseFirestore.instance
          .collection('rides')
          .where('driverId', isEqualTo: _currentDriverId)
          .get();

      if (!mounted) return;
      
      setState(() {
        _allRides
          ..clear()
          ..addAll(ridesSnapshot.docs
              .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
              .toList());
      });

      // 2. Load all bookings with pending payments
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('driverId', isEqualTo: _currentDriverId)
          .where('paymentStatus', isEqualTo: 'submitted')
          .get();

      if (!mounted) return;
      
      final pendingData = <String, Map<String, dynamic>>{};
      
      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        pendingData[doc.id] = {
          ...data,
          'bookingDocId': doc.id,
        };
        
        // Fetch passenger name
        final passengerId = data['passengerId'];
        if (passengerId != null) {
          _fetchPassengerName(passengerId);
        }
      }
      
      setState(() {
        _pendingPayments.clear();
        _pendingPayments.addAll(pendingData);
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error loading data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading payments: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchPassengerName(String passengerId) async {
    if (passengerId.isEmpty) return;
    
    if (_passengerNames.containsKey(passengerId) || 
        _requestedPassengerIds.contains(passengerId)) {
      return;
    }
    
    _requestedPassengerIds.add(passengerId);
    
    try {
      final doc = await FirebaseFirestore.instance
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

  Ride? _getRideById(String rideId) {
    try {
      return _allRides.firstWhere((r) => r.id == rideId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _approvePayment(String bookingDocId) async {
    try {
      final paymentData = _pendingPayments[bookingDocId];
      if (paymentData == null) return;
      
      final rideId = paymentData['rideId'];
      final passengerId = paymentData['passengerId'];
      
      // 1. Update booking document
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingDocId)
          .update({
            'paymentStatus': 'approved',
            'paymentApprovedAt': FieldValue.serverTimestamp(),
            'isPaid': true,
            'approvalNote': 'Payment approved by driver',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // 2. Update ride's booking array
      final ride = _getRideById(rideId);
      if (ride != null) {
        final updatedBookings = ride.bookings.map((b) {
          if (b.passengerId == passengerId) {
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
        
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(rideId)
            .update({
              'bookings': updatedBookings.map((b) => b.toMap()).toList(),
            });
      }
      
      // 3. Remove from pending list
      if (!mounted) return;
      setState(() {
        _pendingPayments.remove(bookingDocId);
      });
      
      // 4. Create notification for passenger
      await _createNotification(
        bookingDocId,
        'Payment Approved',
        'Your payment has been approved by driver.',
        passengerId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      print('Error approving payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectPayment(String bookingDocId, String reason) async {
    try {
      final paymentData = _pendingPayments[bookingDocId];
      if (paymentData == null) return;
      
      final rideId = paymentData['rideId'];
      final passengerId = paymentData['passengerId'];
      
      // 1. Update booking document
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingDocId)
          .update({
            'paymentStatus': 'rejected',
            'rejectionReason': reason,
            'paymentRejectedAt': FieldValue.serverTimestamp(),
            'isPaid': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      // 2. Update ride's booking array
      final ride = _getRideById(rideId);
      if (ride != null) {
        final updatedBookings = ride.bookings.map((b) {
          if (b.passengerId == passengerId) {
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
        
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(rideId)
            .update({
              'bookings': updatedBookings.map((b) => b.toMap()).toList(),
            });
      }
      
      // 3. Remove from pending list
      if (!mounted) return;
      setState(() {
        _pendingPayments.remove(bookingDocId);
      });
      
      // 4. Create notification for passenger
      await _createNotification(
        bookingDocId,
        'Payment Rejected',
        'Your payment was rejected. Reason: $reason',
        passengerId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment rejected. Passenger will be notified.'),
          backgroundColor: Colors.orange,
        ),
      );
      
    } catch (e) {
      print('Error rejecting payment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _createNotification(
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

  void _viewReceiptDialog(Map<String, dynamic> paymentData) {
    final receiptUrl = paymentData['receiptUrl'];
    final receiptType = paymentData['receiptFileType'] ?? 'image';
    final passengerName = paymentData['passengerName'] ?? 'Passenger';
    final amount = (paymentData['fare'] ?? 0.0).toDouble();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Receipt from $passengerName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Amount: RM ${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              
              if (receiptType == 'pdf')
                Column(
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 80, color: Colors.red),
                    const SizedBox(height: 10),
                    const Text(
                      'PDF Receipt',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening PDF receipt...'),
                          ),
                        );
                      },
                      child: const Text('Open PDF'),
                    ),
                  ],
                )
              else if (receiptUrl != null && receiptUrl.isNotEmpty)
                Container(
                  height: 300,
                  width: double.maxFinite,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Image.network(
                    receiptUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 60, color: Colors.red),
                        SizedBox(height: 10),
                        Text('Cannot load receipt image'),
                      ],
                    ),
                  ),
                )
              else
                const Column(
                  children: [
                    Icon(Icons.receipt, size: 60, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('No receipt available'),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showApproveDialog(String bookingDocId) async {
    final paymentData = _pendingPayments[bookingDocId];
    if (paymentData == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to approve this payment?'),
            const SizedBox(height: 16),
            if (paymentData['receiptUrl'] != null)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, false);
                  _viewReceiptDialog(paymentData);
                },
                icon: const Icon(Icons.receipt),
                label: const Text('View Receipt'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _approvePayment(bookingDocId);
    }
  }

  Future<void> _showRejectDialog(String bookingDocId) async {
    final paymentData = _pendingPayments[bookingDocId];
    if (paymentData == null) return;
    
    final TextEditingController reasonController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Reject Payment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please provide a reason for rejection:'),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Invalid receipt, wrong amount, etc.',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a rejection reason'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reject'),
              ),
            ],
          );
        },
      ),
    );
    
    if (confirmed == true) {
      await _rejectPayment(bookingDocId, reasonController.text.trim());
    }
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

  Widget _buildPaymentCard(MapEntry<String, Map<String, dynamic>> entry) {
    final bookingDocId = entry.key;
    final paymentData = entry.value;
    
    final rideId = paymentData['rideId'];
    final passengerId = paymentData['passengerId'];
    final passengerName = paymentData['passengerName'] ?? 
                          _passengerNames[passengerId] ?? 
                          'Passenger';
    final fare = (paymentData['fare'] ?? 0.0).toDouble();
    final receiptUrl = paymentData['receiptUrl'];
    final submittedAt = paymentData['paymentSubmittedAt'];
    
    final ride = _getRideById(rideId);
    
    return Card(
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
                    color: hexStringToColor("365770").withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.person,
                    color: hexStringToColor("365770"),
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
                          fontSize: 13,
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
            
            // Ride Info
            if (ride != null) ...[
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
            ],
            
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
            
            // Receipt Preview Button
            if (receiptUrl != null && receiptUrl.isNotEmpty)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _viewReceiptDialog(paymentData),
                    icon: const Icon(Icons.receipt, size: 16),
                    label: const Text('View Receipt'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _showRejectDialog(bookingDocId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _showApproveDialog(bookingDocId),
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 20),
          const Text(
            'No Pending Payments',
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
              'Payments have been reviewed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: hexStringToColor("365770"),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            'Loading payments...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexStringToColor("365770");
    final pendingPayments = _pendingPayments.entries.toList();
    final pendingCount = pendingPayments.length;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        title: const Text('Payment Review'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: Colors.orange,
                radius: 12,
                child: Text(
                  pendingCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : pendingCount > 0
              ? ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingCount,
                  itemBuilder: (context, index) {
                    return _buildPaymentCard(pendingPayments[index]);
                  },
                )
              : _buildEmptyState(),
    );
  }
}