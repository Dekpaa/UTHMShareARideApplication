import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uthmshareride/modules/Passenger/mybooking.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'pdf_preview_page.dart';
import 'image_preview_page.dart';

class PaymentScreen extends StatefulWidget {
  final Ride ride;
  final Booking booking;

  const PaymentScreen({
    super.key,
    required this.ride,
    required this.booking,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  File? _receiptFile;
  String? _receiptFileType;
  String? _receiptFileName;

  bool _isLoading = true;
  bool _isSubmitting = false;

  String? _bankName;
  String? _accountName;
  String? _accountNumber;
  String? _qrUrl;
  String _paymentStatus = 'none';
  String _rejectionReason = '';
  Timestamp? _rejectionDate;
  Timestamp? _lastSubmittedDate;
  
  StreamSubscription<DocumentSnapshot>? _bookingSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    final bookingDocId = '${widget.ride.id}_${widget.booking.passengerId}';
    
    _bookingSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingDocId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _paymentStatus = data['paymentStatus'] ?? 'none';
            _rejectionReason = data['rejectionReason'] ?? '';
            _rejectionDate = data['paymentRejectedAt'];
            _lastSubmittedDate = data['paymentSubmittedAt'];
            
            if (_paymentStatus == 'approved') {
              _onPaymentApproved();
            } else if (_paymentStatus == 'rejected') {
              _onPaymentRejected();
            }
          });
        }
      }
    });
  }

  void _onPaymentApproved() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment approved! Thank you.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MyBookingsPage(initialTabIndex: 2), 
          ),
          (route) => false,
        );
      }
    });
  }

  void _onPaymentRejected() {
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Payment Rejected'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _rejectionReason.isNotEmpty 
                      ? 'Reason: $_rejectionReason'
                      : 'Your payment has been rejected by the driver.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.amber.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please upload a new receipt with correct information.',
                          style: TextStyle(
                            color: Colors.amber.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  Future<void> _loadData() async {
    try {
      // Load driver payment info
      final driverDoc = await FirebaseFirestore.instance
          .collection('driver_payment')
          .doc(widget.ride.driverId)
          .get();

      // Load booking info
      final bookingDocId = '${widget.ride.id}_${widget.booking.passengerId}';
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingDocId)
          .get();

      final driverData = driverDoc.data();
      final bookingData = bookingDoc.data();

      setState(() {
        _bankName = driverData?['bankName'];
        _accountName = driverData?['accountName'];
        _accountNumber = driverData?['accountNumber'];
        _qrUrl = driverData?['qrUrl'];
        _paymentStatus = bookingData?['paymentStatus'] ?? 'none';
        _rejectionReason = bookingData?['rejectionReason'] ?? '';
        _rejectionDate = bookingData?['paymentRejectedAt'];
        _lastSubmittedDate = bookingData?['paymentSubmittedAt'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading payment details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final ext = result.files.single.extension?.toLowerCase();

      setState(() {
        _receiptFile = File(result.files.single.path!);
        _receiptFileType = ext == 'pdf' ? 'pdf' : 'image';
        _receiptFileName = result.files.single.name;
      });
    }
  }

  String _getBookingDocId() {
    return '${widget.ride.id}_${widget.booking.passengerId}';
  }

  Future<void> _submitPayment() async {
    if (_receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload receipt first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bookingDocId = _getBookingDocId();

      // 1. Upload receipt
      String? receiptUrl;
      if (_receiptFile != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileExt = _receiptFileType == 'pdf' ? 'pdf' : 'jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('receipts')
            .child('${widget.booking.passengerId}_$timestamp.$fileExt');
        
        await storageRef.putFile(_receiptFile!);
        receiptUrl = await storageRef.getDownloadURL();
      }

      // 2. Update booking - Reset rejection reason
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingDocId)
          .update({
        'paymentStatus': 'submitted',
        'receiptUrl': receiptUrl,
        'receiptFileName': _receiptFileName,
        'receiptFileType': _receiptFileType,
        'paymentSubmittedAt': FieldValue.serverTimestamp(),
        'driverId': widget.ride.driverId,
        'passengerName': widget.booking.passengerName,
        'updatedAt': FieldValue.serverTimestamp(),
        'isPaid': false,
        'rejectionReason': FieldValue.delete(),
        'paymentRejectedAt': FieldValue.delete(),
      });

      // 3. Create notification for driver
      String notificationTitle = 'Payment Submitted';
      String notificationMessage = '${widget.booking.passengerName} has submitted payment receipt.';
      
      if (_paymentStatus == 'rejected') {
        notificationTitle = 'Payment Resubmitted';
        notificationMessage = '${widget.booking.passengerName} has resubmitted payment after rejection.';
      }

      await _createNotification(
        bookingDocId,
        notificationTitle,
        notificationMessage,
        widget.ride.driverId,
      );

      // 4. Update state
      setState(() {
        _paymentStatus = 'submitted';
        _rejectionReason = '';
        _rejectionDate = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate ke MyBookingsPage dengan Payment tab (index 1)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => MyBookingsPage(initialTabIndex: 1),
          ),
          (route) => false,
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _createNotification(
    String bookingId,
    String title,
    String message,
    String driverId,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'bookingId': bookingId,
        'title': title,
        'message': message,
        'driverId': driverId,
        'passengerId': widget.booking.passengerId,
        'passengerName': widget.booking.passengerName,
        'type': 'payment_submitted',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  Widget _buildReceiptPreview() {
    if (_receiptFile == null) return Container();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        children: [
          Icon(
            _receiptFileType == 'pdf' 
              ? Icons.picture_as_pdf 
              : Icons.image,
            color: Colors.green.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    if (_receiptFileType == 'pdf') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfPreviewPage(file: _receiptFile!),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ImagePreviewPage(file: _receiptFile!),
                        ),
                      );
                    }
                  },
                  child: Text(
                    _receiptFileName!,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Text(
                  'Tap to preview',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              setState(() {
                _receiptFile = null;
                _receiptFileName = null;
              });
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildRejectionHistory() {
    if (_paymentStatus != 'rejected') return Container();
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.grey.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'Payment History',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_lastSubmittedDate != null)
            Row(
              children: [
                Icon(Icons.upload, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submitted: ${_formatDate(_lastSubmittedDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          if (_rejectionDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Icon(Icons.cancel, size: 14, color: Colors.red.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejected: ${_formatDate(_rejectionDate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = hexStringToColor("365770");
    final canUpload = (_paymentStatus == 'none' || _paymentStatus == 'rejected') && !_isSubmitting;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        title: Text(
          _paymentStatus == 'rejected' ? 'Resubmit Payment' : 'Payment Details',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_paymentStatus == 'rejected')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Payment Rejected',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          if (_rejectionReason.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reason for rejection:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _rejectionReason,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Please upload a new receipt with correct information.',
                                    style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // PAYMENT HISTORY (for rejected payments)
                  _buildRejectionHistory(),

                  // PAYMENT METHODS SECTION
                  _buildSection(
                    title: 'Bank Transfer Details',
                    icon: Icons.account_balance,
                    children: [
                      _buildDetailRow('Bank Name', _bankName ?? 'Not provided'),
                      _buildDetailRow('Account Number', _accountNumber ?? 'Not provided'),
                      _buildDetailRow('Account Name', _accountName ?? 'Not provided'),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // QR CODE SECTION
                  if (_qrUrl != null && _qrUrl!.isNotEmpty)
                    _buildSection(
                      title: 'QR Code Payment',
                      icon: Icons.qr_code,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Scan QR Code to Pay',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                Image.network(
                                  _qrUrl!,
                                  height: 180,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text('Unable to load QR code'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    'Amount: RM ${widget.ride.fare.toStringAsFixed(2)}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // UPLOAD RECEIPT SECTION
                  if (canUpload)
                    _buildSection(
                      title: _paymentStatus == 'rejected' 
                          ? 'Upload New Receipt' 
                          : 'Upload Receipt',
                      icon: _paymentStatus == 'rejected' 
                          ? Icons.refresh 
                          : Icons.upload_file,
                      children: [
                        Text(
                          _paymentStatus == 'rejected'
                              ? 'Please upload a new receipt with the following requirements:'
                              : 'Please upload proof of payment (screenshot or PDF)',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 12),
                        
                        // REQUIREMENTS LIST
                        if (_paymentStatus == 'rejected')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Requirements:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildRequirementItem('1. Correct amount (RM ${widget.ride.fare.toStringAsFixed(2)})'),
                                _buildRequirementItem('2. Clear transaction ID'),
                                _buildRequirementItem('3. Visible payment date'),
                                _buildRequirementItem('4. Bank name visible'),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 16),
                        
                        ElevatedButton.icon(
                          onPressed: _pickReceipt,
                          icon: Icon(
                            _paymentStatus == 'rejected'
                                ? Icons.replay
                                : Icons.attach_file,
                            size: 22,
                          ),
                          label: Text(
                            _paymentStatus == 'rejected'
                                ? 'Choose New Receipt File'
                                : 'Choose Receipt File'
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: _paymentStatus == 'rejected'
                                ? Colors.orange
                                : hexStringToColor("365770"),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        
                        if (_receiptFile != null) ...[
                          const SizedBox(height: 16),
                          _buildReceiptPreview(),
                        ],
                      ],
                    ),

                  const SizedBox(height: 24),

                  // SUBMIT BUTTON
                  if (canUpload)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _receiptFile != null ? _submitPayment : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _paymentStatus == 'rejected' 
                              ? Colors.orange 
                              : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: _isSubmitting
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Submitting...',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _paymentStatus == 'rejected'
                                        ? Icons.refresh
                                        : Icons.send,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _paymentStatus == 'rejected'
                                        ? 'Resubmit Payment'
                                        : 'Submit Payment',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                  // HELP SECTION
                  if (_paymentStatus == 'rejected')
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.help, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Need Help?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'If you have issues with payment, please:',
                              style: TextStyle(color: Colors.blue.shade800),
                            ),
                            const SizedBox(height: 8),
                            _buildHelpItem('1. Check your payment details'),
                            _buildHelpItem('2. Contact driver for clarification'),
                            _buildHelpItem('3. Ensure receipt matches exact amount'),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 3,
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
                Icon(icon, color: hexStringToColor("365770")),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color.fromARGB(255, 112, 105, 105),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'submitted': return Colors.orange;
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getPaymentStatusIcon(String status) {
    switch (status) {
      case 'submitted': return Icons.access_time;
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.error;
      default: return Icons.payment;
    }
  }

  String _getPaymentStatusText(String status) {
    switch (status) {
      case 'submitted': return 'Payment submitted. Waiting for driver approval.';
      case 'approved': return 'Payment approved by driver.';
      case 'rejected': return 'Payment rejected by driver';
      default: return 'Payment required';
    }
  }
}