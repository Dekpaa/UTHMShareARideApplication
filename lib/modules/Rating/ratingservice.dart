import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';

class RatingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<double> getDriverAverageRating(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      double totalRating = 0;
      int totalRatings = 0;

      for (final rideDoc in snapshot.docs) {
        final rideData = rideDoc.data();
        final bookings = rideData['bookings'] as List<dynamic>?;

        if (bookings != null) {
          for (final booking in bookings) {
            final rating = booking['rating'] as int?;
            if (rating != null && rating > 0) {
              totalRating += rating.toDouble();
              totalRatings++;
            }
          }
        }
      }

      return totalRatings > 0 ? totalRating / totalRatings : 0.0;
    } catch (e) {
      print('Error getting driver rating: $e');
      return 0.0;
    }
  }

  static Future<int> getDriverTotalRatings(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection('rides')
          .where('driverId', isEqualTo: driverId)
          .get();

      if (snapshot.docs.isEmpty) return 0;

      int totalRatings = 0;

      for (final rideDoc in snapshot.docs) {
        final rideData = rideDoc.data();
        final bookings = rideData['bookings'] as List<dynamic>?;

        if (bookings != null) {
          for (final booking in bookings) {
            final rating = booking['rating'] as int?;
            if (rating != null && rating > 0) {
              totalRatings++;
            }
          }
        }
      }

      return totalRatings;
    } catch (e) {
      print('Error getting driver total ratings: $e');
      return 0;
    }
  }

  static Future<void> updateDriverRating(String driverId) async {
    try {
      final averageRating = await getDriverAverageRating(driverId);
      final totalRatings = await getDriverTotalRatings(driverId);

      await _firestore.collection('drivers').doc(driverId).update({
        'averageRating': averageRating,
        'totalRatings': totalRatings,
        'ratingUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating driver rating: $e');
    }
  }

  // Check if user has already rated a booking
  static Future<bool> hasUserRated(String bookingId) async {
    try {
      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        final data = bookingDoc.data();
        return data?['rating'] != null && data?['rating'] > 0;
      }
      return false;
    } catch (e) {
      print('Error checking rating: $e');
      return false;
    }
  }
static Future<void> syncRatingToAllCollections({
  required String rideId,
  required String bookingId,
  required int rating,
  String? review,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    
    // Dapatkan ride info untuk driverId
    final rideDoc = await firestore.collection('rides').doc(rideId).get();
    if (!rideDoc.exists) return;
    
    final rideData = rideDoc.data();
    final driverId = rideData?['driverId'];
    if (driverId == null) return;
    
    // 1. Update di bookings collection
    await firestore.collection('bookings').doc(bookingId).update({
      'rating': rating,
      'review': review,
      'ratedAt': FieldValue.serverTimestamp(),
    });
    
    // 2. Update di rides collection (bookings array)
    final bookings = rideData?['bookings'] as List<dynamic>?;
    if (bookings != null) {
      final updatedBookings = bookings.map((b) {
        if (b is Map<String, dynamic> && b['id'] == bookingId) {
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
    
    // 3. Update driver's average rating
    await updateDriverRating(driverId);
    
  } catch (e) {
    print('Error syncing rating: $e');
    throw e;
  }
}
  static Future<Map<String, dynamic>?> getBookingRating(String bookingId) async {
    try {
      final bookingDoc = await _firestore
          .collection('bookings')
          .doc(bookingId)
          .get();

      if (bookingDoc.exists) {
        final data = bookingDoc.data();
        return {
          'rating': data?['rating'],
          'review': data?['review'],
          'ratedAt': data?['ratedAt'],
        };
      }
      return null;
    } catch (e) {
      print('Error getting booking rating: $e');
      return null;
    }
  }

  // Get all ratings for passenger
  static Future<List<Map<String, dynamic>>> getPassengerRatings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('bookings')
          .where('passengerId', isEqualTo: user.uid)
          .where('rating', isGreaterThan: 0)
          .orderBy('ratedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'rating': data['rating'],
          'review': data['review'],
          'ratedAt': data['ratedAt'],
          'rideId': data['rideId'],
        };
      }).toList();
    } catch (e) {
      print('Error getting passenger ratings: $e');
      return [];
    }
  }
}