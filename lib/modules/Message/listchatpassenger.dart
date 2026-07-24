import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uthmshareride/modules/Message/passtodrivermessage.dart';
import 'package:uthmshareride/modules/Message/roomchat.dart';
import 'package:uthmshareride/modules/Passenger/drawer.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';

class ListChatPassengerPage extends StatelessWidget {
  const ListChatPassengerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF365770),
        body: Center(
          child: Text(
            'Please log in first',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF365770),
      drawer: const PassengerAppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF365770),
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ChatRoomService.getPassengerChatRooms(user.uid),
        builder: (context, snapshot) {
          // Debug information
          if (snapshot.hasData) {
            debugPrint('===== DEBUG CHAT ROOMS FOR PASSENGER =====');
            debugPrint('Passenger UID: ${user.uid}');
            debugPrint('Number of chat rooms: ${snapshot.data!.docs.length}');
            debugPrint('');
            
            for (var i = 0; i < snapshot.data!.docs.length; i++) {
              final doc = snapshot.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              
              debugPrint('Document $i: ${doc.id}');
              debugPrint('  driverId: ${data['driverId']}');
              debugPrint('  driverName: "${data['driverName']}"');
              debugPrint('  passengerName: "${data['passengerName']}"');
              debugPrint('  driverName is null: ${data['driverName'] == null}');
              debugPrint('  driverName isEmpty: ${data['driverName']?.isEmpty ?? true}');
              debugPrint('  driverPhotoUrl: ${data['driverPhotoUrl']}');
              debugPrint('  lastMessage: ${data['lastMessage']}');
              debugPrint('---');
            }
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat,
                    size: 64,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Messages will appear when you book a ride',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF365770),
            ),
            child: ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, __) => Container(
                height: 0,
              ),
              itemBuilder: (context, index) {
                final document = docs[index];
                final data = document.data() as Map<String, dynamic>;
                
                // Extract data with null safety
                final driverId = data['driverId']?.toString() ?? '';
                final rawDriverName = data['driverName'];
                final String driverName;
                
                // Handle null/empty driverName
                if (rawDriverName == null || rawDriverName.toString().isEmpty) {
                  driverName = 'Driver';
                } else {
                  driverName = rawDriverName.toString();
                }
                
                final driverPhotoUrl = data['driverPhotoUrl']?.toString() ?? '';
                final lastMessage = data['lastMessage']?.toString() ?? '';
                final passengerId = data['passengerId']?.toString() ?? '';
                final rideId = data['rideId']?.toString() ?? '';
                final lastMessageTime = data['lastMessageTime'] as Timestamp?;

                return FutureBuilder<DocumentSnapshot>(
                  future: driverName == 'Driver' || driverPhotoUrl.isEmpty
                      ? FirebaseFirestore.instance
                          .collection('drivers')
                          .doc(driverId)
                          .get()
                      : null,
                  builder: (context, driverSnap) {
                    String finalDriverName = driverName;
                    String finalDriverPhotoUrl = driverPhotoUrl;
                    
                    if (driverSnap.connectionState == ConnectionState.waiting) {
                      return _buildLoadingTile(
                        driverPhotoUrl: driverPhotoUrl,
                        driverName: driverName,
                        lastMessage: lastMessage,
                        lastMessageTime: lastMessageTime,
                      );
                    }
                    
                    if (driverSnap.hasData && driverSnap.data!.exists) {
                      final driverData = driverSnap.data!.data() as Map<String, dynamic>?;
                      if (driverData != null) {
                        // Try different field names for driver name
                        finalDriverName = driverData['name'] ??
                                        driverData['displayName'] ??
                                        driverData['fullName'] ??
                                        driverData['driverName'] ??
                                        finalDriverName;
                                        
                        // Try different field names for photo
                        finalDriverPhotoUrl = driverData['photoUrl'] ?? 
                                            driverData['profileImage'] ?? 
                                            driverData['imageUrl'] ?? 
                                            driverData['avatar'] ?? 
                                            finalDriverPhotoUrl;
                        
                        debugPrint('Fetched driver info: $finalDriverName, photo: $finalDriverPhotoUrl');
                        
                        // Update chat_room if data was missing
                        if (driverName == 'Driver' || driverPhotoUrl.isEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              document.reference.update({
                                'driverName': finalDriverName,
                                'driverPhotoUrl': finalDriverPhotoUrl,
                              });
                              debugPrint('✅ Updated chat room ${document.id} with driver info');
                            } catch (e) {
                              debugPrint('❌ Error updating chat room: $e');
                            }
                          });
                        }
                      }
                    }

                    return _buildChatTile(
                      driverName: finalDriverName,
                      driverPhotoUrl: finalDriverPhotoUrl,
                      lastMessage: lastMessage,
                      lastMessageTime: lastMessageTime,
                      rideId: rideId,
                      passengerId: passengerId,
                      user: user,
                      context: context,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Helper: Build loading tile while fetching driver info
  Widget _buildLoadingTile({
    required String driverPhotoUrl,
    required String driverName,
    required String lastMessage,
    required Timestamp? lastMessageTime,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white.withOpacity(0.15),
          backgroundImage: driverPhotoUrl.isNotEmpty
              ? NetworkImage(driverPhotoUrl) as ImageProvider
              : null,
          child: driverPhotoUrl.isEmpty
              ? Icon(
                  Icons.person,
                  color: Colors.white.withOpacity(0.7),
                  size: 24,
                )
              : null,
        ),
        title: Row(
          children: [
            Text(
              driverName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ),
        trailing: lastMessageTime != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(lastMessageTime.toDate()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(lastMessageTime.toDate()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildChatTile({
    required String driverName,
    required String driverPhotoUrl,
    required String lastMessage,
    required Timestamp? lastMessageTime,
    required String rideId,
    required String passengerId,
    required User user,
    required BuildContext context,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white.withOpacity(0.15),
          backgroundImage: driverPhotoUrl.isNotEmpty
              ? NetworkImage(driverPhotoUrl) as ImageProvider
              : null,
          child: driverPhotoUrl.isEmpty
              ? Icon(
                  Icons.person,
                  color: Colors.white.withOpacity(0.7),
                  size: 24,
                )
              : null,
        ),
        title: Text(
          driverName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ),
        trailing: lastMessageTime != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(lastMessageTime.toDate()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(lastMessageTime.toDate()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink(),
        onTap: () async {
          try {
            if (rideId.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ride ID not found')),
              );
              return;
            }

            final rideSnapshot = await FirebaseFirestore.instance
                .collection('rides')
                .doc(rideId)
                .get();

            if (!rideSnapshot.exists) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ride information not found')),
              );
              return;
            }

            final ride = Ride.fromFirestore(
              rideSnapshot.data()!,
              rideSnapshot.id
            );
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverMessagePage(
                  ride: ride,
                  bookingId: ride.id,
                  driverName: driverName,
                  currentUserId: user.uid,
                  passengerId: passengerId,
                ),
              ),
            );
          } catch (e) {
            debugPrint('Error navigating to chat: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to open chat')),
            );
          }
        },
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (now.year == time.year && 
        now.month == time.month && 
        now.day == time.day) {
      return DateFormat('hh:mm a').format(time);
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }

  static String _formatDate(DateTime time) {
    final now = DateTime.now();
    if (now.year == time.year && 
        now.month == time.month && 
        now.day == time.day) {
      return 'Today';
    } else if (now.year == time.year && 
        now.month == time.month && 
        now.day - time.day == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('dd/MM/yyyy').format(time);
    }
  }
}