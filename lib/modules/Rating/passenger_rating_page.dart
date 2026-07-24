import 'package:flutter/material.dart';
import 'package:uthmshareride/modules/Rating/ratingservice.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/utils/color_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassengerRatingDialog {
  static Future<void> _submitRatingToFirestore({
    required String rideId,
    required String bookingId,
    required int rating,
    String? review,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      final bookingDoc =
          await firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return;

      final bookingData = bookingDoc.data();
      final driverId = bookingData?['driverId'];
      if (driverId == null) return;
      final now = Timestamp.now();
      await firestore.collection('bookings').doc(bookingId).update({
        'rating': rating,
        'review': review ?? '',
        'ratedAt': now,
        'isRated': true,
      });

      final rideDoc = await firestore.collection('rides').doc(rideId).get();
      if (rideDoc.exists) {
        final rideData = rideDoc.data();
        final bookings = rideData?['bookings'] as List<dynamic>?;

        if (bookings != null) {
          final updatedBookings = bookings.map((b) {
            if (b is Map<String, dynamic> && b['id'] == bookingId) {
              return {
                ...b,
                'rating': rating,
                'review': review ?? '',
                'ratedAt': now,
                'isRated': true,
              };
            }
            return b;
          }).toList();

          await firestore.collection('rides').doc(rideId).update({
            'bookings': updatedBookings,
          });
        }
      }

      await _updateDriverRating(driverId);
      await _logRatingToAnalytics(
        rideId: rideId,
        bookingId: bookingId,
        driverId: driverId,
        passengerId: currentUser.uid,
        rating: rating,
        review: review,
      );

      print('✅ Rating submitted successfully to all collections');
    } catch (e) {
      print('Error submitting rating: $e');
      throw e;
    }
  }

  static Future<void> _updateDriverRating(String driverId) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final ratingsSnapshot = await firestore
          .collection('bookings')
          .where('driverId', isEqualTo: driverId)
          .where('rating', isGreaterThan: 0)
          .get();

      if (ratingsSnapshot.docs.isEmpty) return;

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

      // Update di drivers collection
      await firestore.collection('drivers').doc(driverId).update({
        'averageRating': double.parse(averageRating.toStringAsFixed(1)),
        'totalRatings': totalRatings,
        'lastRatingUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating driver rating: $e');
    }
  }

  static Future<void> _logRatingToAnalytics({
    required String rideId,
    required String bookingId,
    required String driverId,
    required String passengerId,
    required int rating,
    String? review,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('rating_review').doc(bookingId).set({
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
      print('Error logging rating: $e');
    }
  }

  static Future<void> show({
    required BuildContext context,
    required String rideId,
    required String bookingId,
    required Function() onRatingSubmitted,
  }) async {
    int? selectedRating;
    final TextEditingController reviewController = TextEditingController();
    final primaryColor = hexStringToColor("365770");

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              elevation: 10,
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 700,
                  maxHeight: 600, // Batasi tinggi maksimum
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // Kurangi padding dari 24
                  child: SingleChildScrollView(
                    // Tambahkan SingleChildScrollView
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header dengan icon bintang
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.star,
                                color: primaryColor,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rate Your Experience',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  Text(
                                    'How was your ride?',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Section rating dengan bintang
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tap on the stars below',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // STARS
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  final isFilled = index < (selectedRating ?? 0);
                                  final ratingValue = index + 1;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedRating = ratingValue;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 3),
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        isFilled
                                            ? Icons.star
                                            : Icons.star_outline,
                                        color: isFilled
                                            ? Colors.amber
                                            : Colors.grey[400],
                                        size: 20,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // RATING TEXT
                            if (selectedRating != null)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _getRatingColor(selectedRating!)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.emoji_emotions,
                                        color: _getRatingColor(selectedRating!),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getRatingText(selectedRating!),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _getRatingColor(
                                              selectedRating!),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20), // Kurangi dari 24

                        // Section review
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review (Optional)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Share your experience with the driver',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        const Color.fromARGB(255, 205, 186, 186)),
                              ),
                              child: TextField(
                                controller: reviewController,
                                decoration: InputDecoration(
                                  hintText: 'Write your review here...',
                                  hintStyle: TextStyle(color: Colors.grey[500]),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(10),
                                ),
                                maxLines: 4,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24), // Kurangi dari 32

                        // BUTTONS
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  side: BorderSide(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: selectedRating != null
                                    ? () async {
                                        if (selectedRating != null) {
                                          final reviewText =
                                              reviewController.text.trim();
                                          Navigator.of(context).pop();

                                          await _submitRatingToFirestore(
                                            rideId: rideId,
                                            bookingId: bookingId,
                                            rating: selectedRating!,
                                            review: reviewText.isNotEmpty
                                                ? reviewText
                                                : null,
                                          );

                                          onRatingSubmitted();

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    Icon(Icons.check_circle,
                                                        color: Colors.white,
                                                        size: 20),
                                                    const SizedBox(width: 10),
                                                    const Text(
                                                        'Thank you for your feedback!'),
                                                  ],
                                                ),
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedRating != null
                                      ? primaryColor
                                      : Colors.grey[400],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.send,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Submit',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }

  static Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}