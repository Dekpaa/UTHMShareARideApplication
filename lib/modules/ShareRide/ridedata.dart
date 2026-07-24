import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:uthmshareride/modules/Driver/car.dart';
import 'package:uthmshareride/modules/Message/roomchat.dart';

enum BookingStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  confirmed,
}

String bookingStatusToString(BookingStatus status) {
  switch (status) {
    case BookingStatus.pending:
      return 'pending';
    case BookingStatus.accepted:
      return 'accepted';
    case BookingStatus.rejected:
      return 'rejected';
    case BookingStatus.cancelled:
      return 'cancelled';
    case BookingStatus.confirmed:
      return 'confirmed';
  }
}

/// Convert string (from Firestore) -> enum
BookingStatus bookingStatusFromString(String value) {
  switch (value) {
    case 'accepted':
      return BookingStatus.accepted;
    case 'rejected':
      return BookingStatus.rejected;
    case 'cancelled':
      return BookingStatus.cancelled;
    case 'confirmed':
      return BookingStatus.confirmed;
    case 'pending':
    default:
      return BookingStatus.pending;
  }
}

/// ===== BOOKING MODEL =====
class Booking {
  final String id;
  final String passengerId;
  final String passengerName;
  final BookingStatus status;
  final bool isPaid;
  final int? rating;
  final String? review;
  final String? rideId;
  final Timestamp? ratedAt;
  final String paymentStatus;
  final String? rejectionReason;
  final Timestamp? paymentRejectedAt;
  

  Booking({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.status,
    this.isPaid = false,
    this.paymentStatus = 'none',
    this.rating,
    this.review,
    this.rideId,
    this.ratedAt,
    this.rejectionReason,
    this.paymentRejectedAt,
  });

  Booking copyWith({
    String? id,
    String? passengerId,
    String? passengerName,
    BookingStatus? status,
    bool? isPaid,
    int? rating,
    String? review,
    String? rideId,
    Timestamp? ratedAt,
    String? paymentStatus,
    String? rejectionReason,
    Timestamp? paymentRejectedAt,
    
  }) {
    return Booking(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      status: status ?? this.status,
      isPaid: isPaid ?? this.isPaid,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      rideId: rideId ?? this.rideId,
      ratedAt: ratedAt ?? this.ratedAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      paymentRejectedAt: paymentRejectedAt ?? this.paymentRejectedAt,
    );
  }

  factory Booking.fromMap(Map<String, dynamic> data) {
    return Booking(
      id: data['id'] ?? '',
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? 'Passenger',
      status: bookingStatusFromString(data['status'] ?? 'pending'),
      isPaid: (data['isPaid'] ?? false) as bool,
      rating: data['rating'],
      review: data['review'],
      rideId: data['rideId'],
      ratedAt: data['ratedAt'],
      paymentStatus: data['paymentStatus'] ?? 'none',
      rejectionReason: data['rejectionReason'],
      paymentRejectedAt: data['paymentRejectedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'status': bookingStatusToString(status),
      'isPaid': isPaid,
      'paymentStatus': paymentStatus,
    };

    if (rating != null) {
      map['rating'] = rating;
    }
    if (review != null) {
      map['review'] = review;
    }
    if (rideId != null && rideId!.isNotEmpty) {
      map['rideId'] = rideId;
    }
    if (ratedAt != null) { 
      map['ratedAt'] = ratedAt;
    }
    if (rejectionReason != null) map['rejectionReason'] = rejectionReason;
    if (paymentRejectedAt != null) map['paymentRejectedAt'] = paymentRejectedAt;
    return map;
  }
}

class Ride {
  final String id;
  final String driverId;
  final String start;
  final String end;
  final String date;
  final String time;
  final double fare;
  final String status;
  final bool hasArrived;
  final bool isTracking;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;
  final double? currentLat;
  final double? currentLng;
  final CarDetails carDetails;
  final List<Booking> bookings;
  final String? driverName;
  final String? driverPhone;

  Ride({
    required this.id,
    required this.driverId,
    required this.start,
    required this.end,
    required this.date,
    required this.time,
    required this.fare,
    required this.status,
    required this.hasArrived,
    required this.isTracking,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.currentLat,
    this.currentLng,
    required this.carDetails,
    required this.bookings,
    this.driverName,
    this.driverPhone,
  });

  Ride copyWith({
    String? id,
    String? driverId,
    String? start,
    String? end,
    String? date,
    String? time,
    double? fare,
    String? status,
    bool? hasArrived,
    bool? isTracking,
    double? startLat,
    double? startLng,
    double? endLat,
    double? endLng,
    double? currentLat,
    double? currentLng,
    CarDetails? carDetails,
    List<Booking>? bookings,
    String? driverName,
    String? driverPhone,
    String? passengerCount,
  }) {
    return Ride(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      start: start ?? this.start,
      end: end ?? this.end,
      date: date ?? this.date,
      time: time ?? this.time,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      hasArrived: hasArrived ?? this.hasArrived,
      isTracking: isTracking ?? this.isTracking,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      endLat: endLat ?? this.endLat,
      endLng: endLng ?? this.endLng,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      carDetails: carDetails ?? this.carDetails,
      bookings: bookings ?? this.bookings,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  LatLng? get startLatLng {
    if (startLat == null || startLng == null) return null;
    return LatLng(startLat!, startLng!);
  }

  LatLng? get endLatLng {
    if (endLat == null || endLng == null) return null;
    return LatLng(endLat!, endLng!);
  }

  static int _parseCarYear(dynamic raw) {
    final currentYear = DateTime.now().year;
    if (raw == null) return currentYear;
    if (raw is int) return raw;
    return int.tryParse(raw.toString()) ?? currentYear;
  }

  /// fromFirestore: cuba guna `carDetails` (sub-map), kalau tak ada baru fallback flatten
  factory Ride.fromFirestore(Map<String, dynamic> data, String docId) {
    // ===== BOOKINGS =====
    final rawBookings = (data['bookings'] as List?) ?? [];
    final bookings = rawBookings
        .map((b) {
          final bookingData = Map<String, dynamic>.from(b as Map);
          return Booking.fromMap({
            ...bookingData,
            'rideId': docId, // Pastikan booking ada rideId
          });
        })
        .toList();

    CarDetails car;
    final rawCar = data['carDetails'];

    if (rawCar is Map<String, dynamic>) {
      car = CarDetails.fromMap(rawCar);
    } else {
      car = CarDetails(
        id: (data['carId'] ?? '').toString(),
        model: (data['carModel'] ?? '').toString(),
        plateNumber: (data['carPlateNumber'] ?? '').toString(),
        color: (data['carColor'] ?? '').toString(),
        seatingRange: (data['carSeatingRange'] ?? 'Select').toString(),
        year: _parseCarYear(data['carYear']),
        transmission: (data['carTransmission'] ?? 'Select').toString(),
        fuelType: (data['carFuelType'] ?? 'Select').toString(),
        insuranceCompany: data['carInsuranceCompany'],
        imageUrl: data['carImageUrl'],
      );
    }

    return Ride(
      id: docId,
      driverId: data['driverId'] ?? '',
      start: data['start'] ?? '',
      end: data['end'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      fare: _toDouble(data['fare']) ?? 0.0,
      status: data['status'] ?? 'ongoing',
      hasArrived: (data['hasArrived'] ?? false) as bool,
      isTracking: (data['isTracking'] ?? false) as bool,
      startLat: _toDouble(data['startLat']),
      startLng: _toDouble(data['startLng']),
      endLat: _toDouble(data['endLat']),
      endLng: _toDouble(data['endLng']),
      currentLat: _toDouble(data['currentLat']),
      currentLng: _toDouble(data['currentLng']),
      carDetails: car,
      bookings: bookings,
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'driverId': driverId,
      'start': start,
      'end': end,
      'date': date,
      'time': time,
      'fare': fare,
      'status': status,
      'hasArrived': hasArrived,
      'isTracking': isTracking,
      'carDetails': carDetails.toMap(),
      'bookings': bookings.map((b) => b.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (startLat != null) map['startLat'] = startLat;
    if (startLng != null) map['startLng'] = startLng;
    if (endLat != null) map['endLat'] = endLat;
    if (endLng != null) map['endLng'] = endLng;
    if (currentLat != null) map['currentLat'] = currentLat;
    if (currentLng != null) map['currentLng'] = currentLng;
    if (driverName != null && driverName!.isNotEmpty) {
      map['driverName'] = driverName;
    }
    if (driverPhone != null && driverPhone!.isNotEmpty) {
      map['driverPhone'] = driverPhone;
    }

    return map;
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

/// ===== RIDE STORAGE (Single source of truth + Firebase) =====
class RideStorage {
  RideStorage._internal() {
    _initListener();
  }

  static final RideStorage _instance = RideStorage._internal();
  factory RideStorage() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<Ride> _rides = [];
  final StreamController<List<Ride>> _ridesController =
      StreamController<List<Ride>>.broadcast();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;

  void _initListener() {
    _firestoreSub ??= _db
        .collection('rides')
        .where('status', whereIn: ['ongoing', 'upcoming'])
        .orderBy('date', descending: false)
        .snapshots()
        .listen((snapshot) {
      _rides.clear();
      _rides.addAll(
        snapshot.docs.map((doc) {
          final data = doc.data();
          return Ride.fromFirestore(data, doc.id);
        }).toList(),
      );
      _ridesController.add(List.unmodifiable(_rides));
    });
  }

  List<Ride> get rides => List.unmodifiable(_rides);

  Stream<List<Ride>> get ridesStream => _ridesController.stream;

  Ride? getRideById(String rideId) {
    return _rides.firstWhereOrNull((r) => r.id == rideId);
  }

  /// Create ride baru (digunakan di ShareRideFormPage)
  Future<String> createRide(Ride ride) async {
    try {
      // Validate location is within Johor (gunakan bounds dari LocationPickerPage)
      final startLatLng = ride.startLatLng;
      final endLatLng = ride.endLatLng;

      // Check if coordinates are within Johor
      if (!_isWithinJohor(startLatLng) || !_isWithinJohor(endLatLng)) {
        throw Exception('Start or end location is outside Johor area');
      }

      final docRef = await _db.collection('rides').add(ride.toMap());
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating ride: $e');
      rethrow;
    }
  }

  // Helper function to check if location is within Johor
  bool _isWithinJohor(LatLng? latLng) {
    if (latLng == null) return false;

    // Johor bounds (sama seperti di LocationPickerPage)
    final johorBounds = {
      'southwest': {'lat': 1.2085, 'lng': 102.3699},
      'northeast': {'lat': 2.7993, 'lng': 104.4355}
    };

    return latLng.latitude >= johorBounds['southwest']!['lat']! &&
        latLng.latitude <= johorBounds['northeast']!['lat']! &&
        latLng.longitude >= johorBounds['southwest']!['lng']! &&
        latLng.longitude <= johorBounds['northeast']!['lng']!;
  }

  /// ===== BOOKING OPS =====

  Future<void> addBookingToRide(String rideId, Booking booking) async {
    try {
      final docRef = _db.collection('rides').doc(rideId);
      final bookingId = booking.id.isNotEmpty
          ? booking.id
          : '${rideId}_${booking.passengerId}_${DateTime.now().millisecondsSinceEpoch}';

      final newBooking = booking.copyWith(
        id: bookingId,
        rideId: rideId,
      );

      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) {
          throw Exception('Ride not found');
        }

        final data = snap.data() as Map<String, dynamic>;
        final raw = (data['bookings'] as List?) ?? [];
        final bookings = raw
            .map<Map<String, dynamic>>(
                (b) => Map<String, dynamic>.from(b as Map))
            .toList();

        // Check if booking already exists
        final existingBooking = bookings.firstWhereOrNull(
            (b) => b['passengerId'] == booking.passengerId && b['rideId'] == rideId);

        if (existingBooking != null) {
          throw Exception('You have already booked this ride');
        }

        bookings.add(newBooking.toMap());
        transaction.update(docRef, {'bookings': bookings});
      });

      // Create booking document di collection 'bookings'
      await _createBookingDocument(rideId, newBooking);
    } catch (e) {
      debugPrint('Error adding booking to ride: $e');
      rethrow;
    }
  }

  Future<void> _createBookingDocument(String rideId, Booking booking) async {
    try {
      final bookingDocId = '${rideId}_${booking.passengerId}';

      // Get ride info
      final rideDoc = await _db.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) return;

      final rideData = rideDoc.data()!;
      final driverId = rideData['driverId'] ?? '';

      // Get passenger info
      String passengerName = booking.passengerName;
      try {
        final passengerDoc = await _db.collection('passengers').doc(booking.passengerId).get();
        if (passengerDoc.exists) {
          passengerName = passengerDoc.data()?['fullName'] ?? passengerName;
        }
      } catch (_) {}

      // Get driver info
      String driverName = 'Driver';
      try {
        final driverDoc = await _db.collection('drivers').doc(driverId).get();
        if (driverDoc.exists) {
          driverName = driverDoc.data()?['fullName'] ?? driverName;
        }
      } catch (_) {}

      await _db.collection('bookings').doc(bookingDocId).set({
        'id': bookingDocId,
        'rideId': rideId,
        'driverId': driverId,
        'passengerId': booking.passengerId,
        'passengerName': passengerName,
        'driverName': driverName,
        'status': bookingStatusToString(booking.status),
        'fare': rideData['fare'] ?? 0.0,
        'startLocation': rideData['start'] ?? '',
        'endLocation': rideData['end'] ?? '',
        'rideDate': rideData['date'] ?? '',
        'rideTime': rideData['time'] ?? '',
        'paymentStatus': 'none',
        'isPaid': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating booking document: $e');
      // Don't rethrow - main booking sudah berjaya dibuat di rides collection
    }
  }


  Future<void> updateBookingStatus(
    String rideId,
    String bookingId,
    BookingStatus newStatus,
  ) async {
    try {
      final docRef = _db.collection('rides').doc(rideId);

      Booking? updatedBooking;

      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final raw = (data['bookings'] as List?) ?? [];
        final bookings = raw
            .map<Map<String, dynamic>>(
                (b) => Map<String, dynamic>.from(b as Map))
            .toList();

        for (var i = 0; i < bookings.length; i++) {
          if ((bookings[i]['id'] ?? '') == bookingId) {
            bookings[i]['status'] = bookingStatusToString(newStatus);
            updatedBooking = Booking.fromMap(bookings[i]);
            break;
          }
        }

        if (updatedBooking != null) {
          transaction.update(docRef, {'bookings': bookings});
        }
      });

      if (newStatus == BookingStatus.accepted && updatedBooking != null) {
        await _createChatRoomForAcceptedBooking(
          rideId: rideId,
          booking: updatedBooking,
        );
      }

      final ride = getRideById(rideId);
      if (ride != null) {
        final booking = ride.bookings.firstWhereOrNull((b) => b.id == bookingId);
        if (booking != null) {
          final bookingDocId = '${rideId}_${booking.passengerId}';
          await _db.collection('bookings').doc(bookingDocId).update({
            'status': bookingStatusToString(newStatus),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating booking status: $e');
      rethrow;
    }
  }


Future<void> _createChatRoomForAcceptedBooking({
  required String rideId,
  required Booking? booking,
}) async {
  try {
    debugPrint('🔄 Creating chat room for accepted booking: ${booking?.id}');

    // Check if booking is null
    if (booking == null) {
      debugPrint('❌ Booking is null, cannot create chat room');
      return;
    }

    // Dapatkan ride info
    final ride = getRideById(rideId);
    if (ride == null) {
      debugPrint('❌ Ride not found: $rideId');
      return;
    }

    // Dapatkan driver info
    String driverName = 'Driver';
    String? driverPhotoUrl;
    try {
      final driverDoc = await _db.collection('drivers').doc(ride.driverId).get();
      if (driverDoc.exists) {
        final driverData = driverDoc.data()!;
        driverName = driverData['fullName'] ?? driverData['name'] ?? 'Driver'; // Priority: fullName -> name
        driverPhotoUrl = driverData['photoUrl'] ?? '';
      }
    } catch (e) {
      debugPrint('Error getting driver info: $e');
    }

    // PERBAIKAN: Dapatkan passenger info dengan lebih baik
    String passengerName = booking.passengerName;
    String? passengerPhotoUrl;
    try {
      final passengerDoc = await _db.collection('passengers').doc(booking.passengerId).get();
      if (passengerDoc.exists) {
        final passengerData = passengerDoc.data()!;
        // Priority: fullName -> name -> booking.passengerName
        passengerName = passengerData['fullName'] ?? 
                       passengerData['name'] ?? 
                       booking.passengerName;
        passengerPhotoUrl = passengerData['photoUrl'] ?? '';
        debugPrint('✅ Got passenger name: $passengerName from Firestore');
      } else {
        debugPrint('⚠️ Passenger document not found, using booking name: $passengerName');
      }
    } catch (e) {
      debugPrint('Error getting passenger info: $e');
    }

    // Buat chat room
    await ChatRoomService.updateOrCreateChatRoom(
      rideId: rideId,
      driverId: ride.driverId,
      driverName: driverName,
      driverPhotoUrl: driverPhotoUrl,
      passengerId: booking.passengerId,
      passengerName: passengerName, // Gunakan nama yang sudah di-fetch
      passengerPhotoUrl: passengerPhotoUrl,
      lastMessage: 'Booking accepted. You can start chatting now.',
      senderId: ride.driverId,
    );

    debugPrint('✅ Chat room created for passenger: $passengerName');
  } catch (e) {
    debugPrint('❌ Error creating chat room for accepted booking: $e');
  }
}

  Future<void> updateBookingPaymentStatus(
    String rideId,
    String bookingId,
    bool isPaid,
  ) async {
    try {
      final docRef = _db.collection('rides').doc(rideId);
      

      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) return;

        final data = snap.data() as Map<String, dynamic>;
        final raw = (data['bookings'] as List?) ?? [];
        final bookings = raw
            .map<Map<String, dynamic>>(
                (b) => Map<String, dynamic>.from(b as Map))
            .toList();

        bool found = false;
        for (var i = 0; i < bookings.length; i++) {
          if ((bookings[i]['id'] ?? '') == bookingId) {
            bookings[i]['isPaid'] = isPaid;
            found = true;
            break;
          }
        }

        if (found) {
          final bookingModels = bookings.map(Booking.fromMap).toList();
          final accepted = bookingModels.where((b) => b.status == BookingStatus.accepted).toList();
          final allPaid = accepted.isNotEmpty && accepted.every((b) => b.isPaid == true);

          final updates = <String, dynamic>{'bookings': bookings};
          if (allPaid && data['status'] == 'ongoing') {
            updates['status'] = 'completed';
          }

          transaction.update(docRef, updates);
        }
      });

      
      final ride = getRideById(rideId);
      if (ride != null) {
        final booking = ride.bookings.firstWhereOrNull((b) => b.id == bookingId);
        if (booking != null) {
          final bookingDocId = '${rideId}_${booking.passengerId}';
          final paymentStatus = isPaid ? 'approved' : 'submitted';


          await _db.collection('bookings').doc(bookingDocId).update({
            'isPaid': isPaid,
            'paymentStatus': paymentStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            ...(isPaid ? {'paymentApprovedAt': FieldValue.serverTimestamp()} : {}),
          });
        }
      }
    } catch (e) {
      debugPrint('Error updating booking payment status: $e');
      rethrow;
    }
  }

// TAMBAH method ini di class RideStorage
Future<void> updateBookingRatingAndReview(
  String rideId,
  String bookingId,
  int rating,
  String? review,
  String driverId,
) async {
  try {
    final firestore = FirebaseFirestore.instance;

    await firestore.collection('bookings').doc(bookingId).update({
      'rating': rating,
      'review': review,
      'ratedAt': FieldValue.serverTimestamp(),
    });
    
    // Update di rides collection (bookings array)
    final rideDoc = await firestore.collection('rides').doc(rideId).get();
    if (rideDoc.exists) {
      final rideData = rideDoc.data();
      final bookings = rideData?['bookings'] as List<dynamic>?;
      
      if (bookings != null) {
        final updatedBookings = bookings.map((b) {
          if (b is Map<String, dynamic> && 
              b['id'] == bookingId) {
            return {
              ...b,
              'rating': rating,
              'review': review,
              'ratedAt': FieldValue.serverTimestamp(),
            };
          }
          return b;
        }).toList();
        
        await firestore.collection('rides').doc(rideId).update({
          'bookings': updatedBookings,
        });
      }
    }
    
    // Update driver's average rating
    await _updateDriverRatingStats(driverId);
    
  } catch (e) {
    print('Error updating rating in RideStorage: $e');
    throw e;
  }
}

Future<void> _updateDriverRatingStats(String driverId) async {
  try {
    final ratingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('driverId', isEqualTo: driverId)
        .where('rating', isGreaterThan: 0)
        .get();

    if (ratingsSnapshot.docs.isEmpty) {
      // Set default rating jika tiada ratings lagi
      await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({
        'averageRating': 0.0,
        'totalRatings': 0,
        'ratingUpdatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    double totalRating = 0;
    int totalRatings = 0;

    for (final doc in ratingsSnapshot.docs) {
      final rating = doc.data()['rating'] as int?;
      if (rating != null && rating > 0) {
        totalRating += rating.toDouble();
        totalRatings++;
      }
    }

    final averageRating = totalRatings > 0 ? totalRating / totalRatings : 0.0;

    await FirebaseFirestore.instance.collection('drivers').doc(driverId).update({
      'averageRating': double.parse(averageRating.toStringAsFixed(1)),
      'totalRatings': totalRatings,
      'ratingUpdatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Updated rating stats for driver: $driverId - Avg: $averageRating, Total: $totalRatings');
  } catch (e) {
    debugPrint('❌ Error updating driver rating stats: $e');
  }
}

Future<void> _logRatingToDatabase(
  String rideId,
  String bookingId,
  String? driverId,
  String passengerId,
  int rating,
  String? review,
) async {
  try {
    final ratingId = '${rideId}_${bookingId}_${DateTime.now().millisecondsSinceEpoch}';
    
    await _db.collection('ratings').doc(ratingId).set({
      'id': ratingId,
      'rideId': rideId,
      'bookingId': bookingId,
      'driverId': driverId,
      'passengerId': passengerId,
      'rating': rating,
      'review': review ?? '',
      'ratedAt': FieldValue.serverTimestamp(),
      'type': 'passenger_to_driver',
    });
  } catch (e) {
    debugPrint('❌ Error logging rating: $e');
    // Jangan throw error untuk logging sahaja
  }
}

Future<Map<String, dynamic>> getDriverRatingInfo(String driverId) async {
  try {
    final driverDoc = await _db.collection('drivers').doc(driverId).get();
    
    if (!driverDoc.exists) {
      return {
        'averageRating': 0.0,
        'totalRatings': 0,
        'ratingDistribution': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
      };
    }

    final data = driverDoc.data()!;
    return {
      'averageRating': (data['averageRating'] ?? 0.0).toDouble(),
      'totalRatings': data['totalRatings'] ?? 0,
      'ratingDistribution': data['ratingDistribution'] ?? {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
      'ratingUpdatedAt': data['ratingUpdatedAt'],
    };
  } catch (e) {
    debugPrint('❌ Error getting driver rating info: $e');
    return {
      'averageRating': 0.0,
      'totalRatings': 0,
      'ratingDistribution': {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0},
    };
  }
}

// Check if user has rated a specific booking
Future<bool> hasUserRatedBooking(String bookingId) async {
  try {
    final bookingDoc = await _db.collection('bookings').doc(bookingId).get();
    
    if (!bookingDoc.exists) return false;
    
    final data = bookingDoc.data()!;
    final rating = data['rating'] as int?;
    final hasRating = rating != null && rating > 0;
    
    return hasRating;
  } catch (e) {
    debugPrint('❌ Error checking if user rated booking: $e');
    return false;
  }
}

// Get all ratings for a passenger
Future<List<Map<String, dynamic>>> getPassengerRatings(String passengerId) async {
  try {
    final snapshot = await _db
        .collection('bookings')
        .where('passengerId', isEqualTo: passengerId)
        .where('rating', isGreaterThan: 0)
        .orderBy('ratedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'rating': data['rating'] ?? 0,
        'review': data['review'] ?? '',
        'ratedAt': data['ratedAt'],
        'rideId': data['rideId'],
        'driverId': data['driverId'],
        'driverName': data['driverName'] ?? 'Driver',
        'rideDate': data['rideDate'] ?? '',
        'rideTime': data['rideTime'] ?? '',
        'startLocation': data['startLocation'] ?? '',
        'endLocation': data['endLocation'] ?? '',
      };
    }).toList();
  } catch (e) {
    debugPrint('❌ Error getting passenger ratings: $e');
    return [];
  }
}

// Get recent ratings for a driver
Future<List<Map<String, dynamic>>> getDriverRecentRatings(String driverId, {int limit = 5}) async {
  try {
    final snapshot = await _db
        .collection('bookings')
        .where('driverId', isEqualTo: driverId)
        .where('rating', isGreaterThan: 0)
        .orderBy('ratedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'rating': data['rating'] ?? 0,
        'review': data['review'] ?? '',
        'ratedAt': data['ratedAt'],
        'passengerName': data['passengerName'] ?? 'Passenger',
        'rideDate': data['rideDate'] ?? '',
      };
    }).toList();
  } catch (e) {
    debugPrint('❌ Error getting driver recent ratings: $e');
    return [];
  }
}

  /// ===== RIDE STATUS / LOCATION OPS =====

  Future<void> markRideAsCancelled(
    String rideId, {
    String? cancelledBy,
  }) async {
    try {
      String status = 'cancelled';
      if (cancelledBy == 'driver') {
        status = 'cancelled_by_driver';
      } else if (cancelledBy == 'passenger') {
        status = 'cancelled_by_passenger';
      }

      await _db.collection('rides').doc(rideId).update({
        'status': status,
        'isTracking': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error cancelling ride: $e');
      rethrow;
    }
  }

  Future<void> setRideTrackingStatus(String rideId, bool isTracking) async {
    try {
      await _db.collection('rides').doc(rideId).update({
        'isTracking': isTracking,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating tracking status: $e');
      rethrow;
    }
  }

  Future<void> setRideArrivalStatus(String rideId, bool hasArrived) async {
    try {
      await _db.collection('rides').doc(rideId).update({
        'hasArrived': hasArrived,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating arrival status: $e');
      rethrow;
    }
  }

  Future<void> updateRideLocation(
    String rideId,
    double lat,
    double lng,
  ) async {
    try {
      await _db.collection('rides').doc(rideId).update({
        'currentLat': lat,
        'currentLng': lng,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating ride location: $e');
      rethrow;
    }
  }

  Future<void> setRideCompleted(String rideId) async {
    try {
      await _db.collection('rides').doc(rideId).update({
        'status': 'completed',
        'isTracking': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting ride as completed: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _firestoreSub?.cancel();
    await _ridesController.close();
  }
}

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Format date untuk comparison
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Auto-delete completed rides yang lebih dari X hari
  Future<void> autoDeleteCompletedRides({int daysOld = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final cutoffDateStr = _formatDate(cutoffDate);

      final snapshot = await _firestore
          .collection('rides')
          .where('status', isEqualTo: 'completed')
          .where('date', isLessThan: cutoffDateStr)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }

        await batch.commit();
        debugPrint('✅ Deleted ${snapshot.docs.length} completed rides older than $daysOld days');
      }
    } catch (e) {
      debugPrint('❌ Error deleting completed rides: $e');
    }
  }

  Future<void> deleteRide(String rideId) async {
    try {
      await _firestore.collection('rides').doc(rideId).delete();
      debugPrint('✅ Ride $rideId deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting ride: $e');
      rethrow;
    }
  }

  // Update ride status to completed
  Future<void> markRideAsCompleted(String rideId) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error marking ride as completed: $e');
      rethrow;
    }
  }

  // Get rides by driver ID
  Stream<List<Ride>> getRidesByDriver(String driverId) {
    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: ['ongoing', 'upcoming', 'completed'])
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Get rides for passenger (rides they've booked)
  Stream<List<Ride>> getRidesForPassenger(String passengerId) {
    return _firestore
        .collection('rides')
        .where('bookings', arrayContainsAny: [
      {'passengerId': passengerId}
    ])
        .where('status', whereIn: ['ongoing', 'upcoming', 'completed'])
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Ride>> getUpcomingRides() {
    final today = _formatDate(DateTime.now());
    return _firestore
        .collection('rides')
        .where('date', isGreaterThanOrEqualTo: today)
        .where('status', whereIn: ['ongoing', 'upcoming'])
        .orderBy('date')
        .orderBy('time')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ride.fromFirestore(doc.data(), doc.id))
            .toList());
  }
}