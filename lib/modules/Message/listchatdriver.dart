import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uthmshareride/modules/Message/drivertopassmessage.dart';
import 'package:uthmshareride/modules/Message/roomchat.dart'; // TAMBAH INI
import 'package:uthmshareride/modules/Driver/drawer.dart';

class ListChatDriverPage extends StatelessWidget {
  const ListChatDriverPage({super.key});

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
      drawer: const DriverAppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF365770),
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ChatRoomService.getDriverChatRooms(user.uid), // PERBAIKAN
        builder: (context, snapshot) {
          // Debug information
          if (snapshot.hasData) {
            debugPrint('===== DEBUG CHAT ROOMS FOR DRIVER =====');
            debugPrint('Driver UID: ${user.uid}');
            debugPrint('Number of chat rooms: ${snapshot.data!.docs.length}');
            debugPrint('');
            
            for (var i = 0; i < snapshot.data!.docs.length; i++) {
              final doc = snapshot.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              
              debugPrint('Document $i: ${doc.id}');
              debugPrint('  passengerId: ${data['passengerId']}');
              debugPrint('  passengerName: "${data['passengerName']}"');
              debugPrint('  passengerName is null: ${data['passengerName'] == null}');
              debugPrint('  passengerName isEmpty: ${data['passengerName']?.isEmpty ?? true}');
              debugPrint('  passengerPhotoUrl: ${data['passengerPhotoUrl']}');
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
                    'Messages will appear when passengers send their first message',
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
              separatorBuilder: (_, __) => Container(height: 0),
              itemBuilder: (context, index) {
                final document = docs[index];
                final data = document.data() as Map<String, dynamic>;
                
                final rawPassengerName = data['passengerName'];
                final passengerName = rawPassengerName?.toString() ?? 'Passenger';
                final lastMessage = data['lastMessage']?.toString() ?? '';
                final passengerPhotoUrl = data['passengerPhotoUrl']?.toString() ?? '';
                final passengerId = data['passengerId']?.toString() ?? '';
                final rideId = data['rideId']?.toString() ?? '';
                final lastMessageTime = data['lastMessageTime'] as Timestamp?;

                return FutureBuilder<DocumentSnapshot>(
                  future: passengerName == 'Passenger' || passengerPhotoUrl.isEmpty
                      ? FirebaseFirestore.instance
                          .collection('passengers')
                          .doc(passengerId)
                          .get()
                      : null,
                  builder: (context, passengerSnap) {
                    String finalPassengerName = passengerName;
                    String finalPassengerPhotoUrl = passengerPhotoUrl;
                    
                    if (passengerSnap.connectionState == ConnectionState.waiting) {
                      return _buildLoadingTile(
                        passengerName: passengerName,
                        passengerPhotoUrl: passengerPhotoUrl,
                        lastMessage: lastMessage,
                        lastMessageTime: lastMessageTime,
                      );
                    }
                    
                    if (passengerSnap.hasData && passengerSnap.data!.exists) {
                      final passengerData = passengerSnap.data!.data() as Map<String, dynamic>?;
                      if (passengerData != null) {
                        // Update passenger name
                        finalPassengerName = passengerData['fullName'] ?? 
                                            passengerData['name'] ?? 
                                            passengerData['displayName'] ?? 
                                            finalPassengerName;
                                            
                        finalPassengerPhotoUrl = passengerData['photoUrl'] ?? 
                                                passengerData['profileImage'] ?? 
                                                finalPassengerPhotoUrl;
                        
                        debugPrint('Fetched passenger info: $finalPassengerName, photo: $finalPassengerPhotoUrl');
                        
                        // Update chat_room jika data tidak lengkap
                        if (passengerName == 'Passenger' || passengerPhotoUrl.isEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            try {
                              document.reference.update({
                                'passengerName': finalPassengerName,
                                'passengerPhotoUrl': finalPassengerPhotoUrl,
                              });
                              debugPrint('✅ Updated chat room ${document.id} with passenger info');
                            } catch (e) {
                              debugPrint('❌ Error updating chat room: $e');
                            }
                          });
                        }
                      }
                    }

                    return _buildChatTile(
                      passengerName: finalPassengerName,
                      passengerPhotoUrl: finalPassengerPhotoUrl,
                      lastMessage: lastMessage,
                      lastMessageTime: lastMessageTime,
                      rideId: rideId,
                      passengerId: passengerId,
                      driverId: user.uid,
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

  // Helper: Build loading tile while fetching passenger info
  Widget _buildLoadingTile({
    required String passengerName,
    required String passengerPhotoUrl,
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
          backgroundImage: passengerPhotoUrl.isNotEmpty
              ? NetworkImage(passengerPhotoUrl) as ImageProvider
              : null,
          child: passengerPhotoUrl.isEmpty
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
              passengerName,
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

  // Helper: Build chat tile
  Widget _buildChatTile({
    required String passengerName,
    required String passengerPhotoUrl,
    required String lastMessage,
    required Timestamp? lastMessageTime,
    required String rideId,
    required String passengerId,
    required String driverId,
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
          backgroundImage: passengerPhotoUrl.isNotEmpty
              ? NetworkImage(passengerPhotoUrl) as ImageProvider
              : null,
          child: passengerPhotoUrl.isEmpty
              ? Icon(
                  Icons.person,
                  color: Colors.white.withOpacity(0.7),
                  size: 24,
                )
              : null,
        ),
        title: Text(
          passengerName,
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
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PassengerMessagePage(
                rideId: rideId,
                driverId: driverId,
                passengerId: passengerId,
                passengerName: passengerName,
              ),
            ),
          );
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