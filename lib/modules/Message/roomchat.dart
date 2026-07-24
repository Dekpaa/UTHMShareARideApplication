import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ChatRoomService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String generateRoomId({
    required String rideId,
    required String driverId,
    required String passengerId,
  }) {
    // Urutkan participant IDs untuk konsistensi
    final participants = [driverId, passengerId]..sort();
    return '${rideId}_${participants[0]}_${participants[1]}';
  }

  /// Find existing chat room by rideId and participants
  static Future<String?> findExistingChatRoom({
    required String rideId,
    required String driverId,
    required String passengerId,
  }) async {
    try {
      // Cari menggunakan consistent room ID
      final roomId = generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );
      
      final doc = await _firestore.collection('chat_rooms').doc(roomId).get();
      if (doc.exists) {
        return roomId;
      }
      
      // Cari juga dengan query alternative
      final querySnapshot = await _firestore
          .collection('chat_rooms')
          .where('rideId', isEqualTo: rideId)
          .where('driverId', isEqualTo: driverId)
          .where('passengerId', isEqualTo: passengerId)
          .limit(1)
          .get();
          
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error finding existing chat room: $e');
      return null;
    }
  }

  /// Update atau create chat room (SINGLE METHOD) - DIPERBAIKI DENGAN DEBUG
  static Future<void> updateOrCreateChatRoom({
    required String rideId,
    required String driverId,
    required String driverName,
    String? driverPhotoUrl,
    required String passengerId,
    required String passengerName,
    String? passengerPhotoUrl,
    required String lastMessage,
    String? senderId, // Optional: siapa yang mengirim pesan
  }) async {
    try {
      // Cari chat room yang sedia ada
      final existingRoomId = await findExistingChatRoom(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );
      
      final roomId = existingRoomId ?? generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );

      debugPrint('''
      📝 SAVING CHAT ROOM:
      Room ID: $roomId
      Ride ID: $rideId
      Driver ID: $driverId
      Driver Name: $driverName
      Passenger ID: $passengerId
      Passenger Name: $passengerName  <--- INI YANG PENTING
      Last Message: $lastMessage
      Sender ID: $senderId
      ''');

      final now = DateTime.now();
      final timestamp = now.millisecondsSinceEpoch;
      
      final chatRoomData = {
        'roomId': roomId,
        'rideId': rideId,
        
        // Participant IDs
        'driverId': driverId,
        'passengerId': passengerId,
        
        // Display information
        'driverName': driverName,
        'driverPhotoUrl': driverPhotoUrl ?? '',
        'passengerName': passengerName, // <-- INI DISIMPAN
        'passengerPhotoUrl': passengerPhotoUrl ?? '',
        
        // Message information
        'lastMessage': lastMessage,
        'lastMessageTime': Timestamp.fromDate(now),
        'lastMessageTimestamp': timestamp,
        
        // Unread tracking
        'hasUnread': true,
        'unreadDriver': senderId == passengerId ? 1 : 0,
        'unreadPassenger': senderId == driverId ? 1 : 0,
        'lastSenderId': senderId,
        
        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        
        // Untuk query fleksibel
        'participants': {
          driverId: true,
          passengerId: true,
        },
        
        'chatType': 'ride_chat',
      };

      await _firestore.collection('chat_rooms').doc(roomId).set(
        chatRoomData, 
        SetOptions(merge: true)
      );

      debugPrint('✅ Chat room saved with passenger name: "$passengerName"');
    } catch (e) {
      debugPrint('❌ Error updating/creating chat room: $e');
      rethrow;
    }
  }

  /// Method khusus untuk increment unread
  static Future<void> incrementUnreadForRecipient({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String senderId, // Siapa yang mengirim
  }) async {
    try {
      final roomId = generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );

      final updateData = <String, dynamic>{
        'hasUnread': true,
        'lastSenderId': senderId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Tentukan siapa yang harus dapat increment unread
      if (senderId == driverId) {
        // Driver yang kirim -> Passenger unread
        updateData['unreadPassenger'] = FieldValue.increment(1);
      } else if (senderId == passengerId) {
        // Passenger yang kirim -> Driver unread
        updateData['unreadDriver'] = FieldValue.increment(1);
      }

      await _firestore.collection('chat_rooms').doc(roomId).update(updateData);
      
      debugPrint('📈 Unread incremented for room: $roomId (sender: $senderId)');
    } catch (e) {
      debugPrint('Error incrementing unread: $e');
      // Jika document tidak ada, buat dulu
      if (e.toString().contains('document') && e.toString().contains('not found')) {
        debugPrint('Document not found, will create on next message');
        // Create the chat room first
        await updateOrCreateChatRoom(
          rideId: rideId,
          driverId: driverId,
          driverName: 'Driver',
          passengerId: passengerId,
          passengerName: 'Passenger',
          lastMessage: 'New message',
          senderId: senderId,
        );
      }
    }
  }

  /// Reset unread untuk user tertentu
  static Future<void> resetUnreadForUser({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String userId, // User yang membuka chat
  }) async {
    try {
      final roomId = generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );

      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Reset berdasarkan siapa yang membuka
      if (userId == driverId) {
        updateData['unreadDriver'] = 0;
      } else if (userId == passengerId) {
        updateData['unreadPassenger'] = 0;
      }

      // Jika semua sudah dibaca
      if ((updateData['unreadDriver'] ?? 0) == 0 && 
          (updateData['unreadPassenger'] ?? 0) == 0) {
        updateData['hasUnread'] = false;
      }

      await _firestore.collection('chat_rooms').doc(roomId).update(updateData);
      
      debugPrint('👁️ Unread reset for user: $userId in room: $roomId');
    } catch (e) {
      debugPrint('Error resetting unread: $e');
    }
  }

  /// Get chat room untuk driver (fix double entry)
  static Stream<QuerySnapshot> getDriverChatRooms(String driverId) {
    debugPrint('🔍 Getting chat rooms for driver: $driverId');
    return _firestore
        .collection('chat_rooms')
        .where('driverId', isEqualTo: driverId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  /// Get chat room untuk passenger (fix double entry)
  static Stream<QuerySnapshot> getPassengerChatRooms(String passengerId) {
    debugPrint('🔍 Getting chat rooms for passenger: $passengerId');
    return _firestore
        .collection('chat_rooms')
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();
  }

  /// Get single chat room by ID
  static Future<DocumentSnapshot> getChatRoomById(String roomId) async {
    return await _firestore.collection('chat_rooms').doc(roomId).get();
  }

  /// Get chat room stream by ID
  static Stream<DocumentSnapshot> getChatRoomStreamById(String roomId) {
    return _firestore.collection('chat_rooms').doc(roomId).snapshots();
  }

  /// Hapus chat room
  static Future<void> deleteChatRoom({
    required String rideId,
    required String driverId,
    required String passengerId,
  }) async {
    try {
      final roomId = generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );

      await _firestore.collection('chat_rooms').doc(roomId).delete();
      debugPrint('🗑️ Chat room deleted: $roomId');
    } catch (e) {
      debugPrint('Error deleting chat room: $e');
    }
  }

  /// Method untuk backward compatibility
  static Future<void> updateChatRoom({
    required String rideId,
    required String driverId,
    required String driverName,
    required String driverPhotoUrl,
    required String passengerId,
    required String passengerName,
    required String passengerPhotoUrl,
    required String lastMessage,
    required String senderId,
  }) async {
    // Redirect ke updateOrCreateChatRoom untuk konsistensi
    await updateOrCreateChatRoom(
      rideId: rideId,
      driverId: driverId,
      driverName: driverName,
      driverPhotoUrl: driverPhotoUrl,
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhotoUrl: passengerPhotoUrl,
      lastMessage: lastMessage,
      senderId: senderId,
    );
  }

  /// Clean up duplicate chat rooms
  static Future<void> cleanupDuplicateChatRooms() async {
    try {
      debugPrint('🔄 Starting duplicate chat rooms cleanup...');
      
      final snapshot = await _firestore.collection('chat_rooms').get();
      final rooms = snapshot.docs;
      
      debugPrint('📊 Total chat rooms found: ${rooms.length}');
      
      final Map<String, List<DocumentSnapshot>> groupedRooms = {};
      final Map<String, DocumentSnapshot> roomsToKeep = {};
      final List<DocumentReference> roomsToDelete = [];
      
      // Group by consistent room ID
      for (final room in rooms) {
        final data = room.data() as Map<String, dynamic>?;
        if (data != null) {
          final rideId = data['rideId'] as String?;
          final driverId = data['driverId'] as String?;
          final passengerId = data['passengerId'] as String?;
          
          if (rideId != null && driverId != null && passengerId != null) {
            final consistentId = generateRoomId(
              rideId: rideId,
              driverId: driverId,
              passengerId: passengerId,
            );
            
            if (!groupedRooms.containsKey(consistentId)) {
              groupedRooms[consistentId] = [];
            }
            groupedRooms[consistentId]!.add(room);
          }
        }
      }
      
      // Process each group
      for (final entry in groupedRooms.entries) {
        final roomList = entry.value;
        
        if (roomList.length > 1) {
          debugPrint('🔍 Found ${roomList.length} duplicates for key: ${entry.key}');
          
          // Sort by last message timestamp (most recent first)
          roomList.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>?;
            final bData = b.data() as Map<String, dynamic>?;
            final aTime = aData != null ? (aData['lastMessageTimestamp'] as int? ?? 0) : 0;
            final bTime = bData != null ? (bData['lastMessageTimestamp'] as int? ?? 0) : 0;
            return bTime.compareTo(aTime);
          });
          
          // Keep the most recent one
          final keepRoom = roomList.first;
          roomsToKeep[entry.key] = keepRoom;
          
          // Mark others for deletion
          for (int i = 1; i < roomList.length; i++) {
            roomsToDelete.add(roomList[i].reference);
          }
          
          debugPrint('✅ Will keep: ${keepRoom.id}');
        } else if (roomList.length == 1) {
          // Single room, keep it
          roomsToKeep[entry.key] = roomList.first;
        }
      }
      
      // Delete duplicates in batches
      if (roomsToDelete.isNotEmpty) {
        debugPrint('🗑️ Preparing to delete ${roomsToDelete.length} duplicate rooms...');
        
        final batch = _firestore.batch();
        for (final ref in roomsToDelete) {
          batch.delete(ref);
        }
        
        await batch.commit();
        debugPrint('✅ Successfully deleted ${roomsToDelete.length} duplicate rooms');
      } else {
        debugPrint('✅ No duplicate rooms found');
      }
      
      // Update remaining rooms with consistent ID if needed
      for (final entry in roomsToKeep.entries) {
        final room = entry.value;
        final data = room.data() as Map<String, dynamic>?;
        final currentId = room.id;
        final consistentId = entry.key;
        
        if (currentId != consistentId && data != null) {
          debugPrint('🔄 Updating room ID from $currentId to $consistentId');
          
          // Create new room with consistent ID
          await _firestore.collection('chat_rooms').doc(consistentId).set(data);
          
          // Delete old room
          await room.reference.delete();
        }
      }
      
      debugPrint('🎉 Chat rooms cleanup completed successfully!');
    } catch (e) {
      debugPrint('❌ Error cleaning up duplicate chat rooms: $e');
      rethrow;
    }
  }

  /// Get all messages for a specific chat room
  static Stream<QuerySnapshot> getChatMessages(String rideId, String driverId, String passengerId) {
    final roomId = generateRoomId(
      rideId: rideId,
      driverId: driverId,
      passengerId: passengerId,
    );
    
    return _firestore
        .collection('rides')
        .doc(rideId)
        .collection('chats')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  /// Send a text message
  static Future<void> sendTextMessage({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String senderId,
    required String text,
  }) async {
    try {
      await _firestore
          .collection('rides')
          .doc(rideId)
          .collection('chats')
          .add({
            'type': 'text',
            'text': text,
            'senderId': senderId,
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      // Update chat room
      await updateOrCreateChatRoom(
        rideId: rideId,
        driverId: driverId,
        driverName: 'Driver',
        passengerId: passengerId,
        passengerName: 'Passenger',
        lastMessage: text,
        senderId: senderId,
      );
      
      debugPrint('💬 Text message sent');
    } catch (e) {
      debugPrint('Error sending text message: $e');
      rethrow;
    }
  }

  static Future<void> sendImageMessage({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String senderId,
    required String imageUrl,
  }) async {
    try {
      await _firestore
          .collection('rides')
          .doc(rideId)
          .collection('chats')
          .add({
            'type': 'image',
            'imageUrl': imageUrl,
            'senderId': senderId,
            'timestamp': FieldValue.serverTimestamp(),
          });
      
      // Update chat room
      await updateOrCreateChatRoom(
        rideId: rideId,
        driverId: driverId,
        driverName: 'Driver',
        passengerId: passengerId,
        passengerName: 'Passenger',
        lastMessage: '📷 Image',
        senderId: senderId,
      );
      
      debugPrint('🖼️ Image message sent');
    } catch (e) {
      debugPrint('Error sending image message: $e');
      rethrow;
    }
  }

  /// Check if chat room exists
  static Future<bool> chatRoomExists({
    required String rideId,
    required String driverId,
    required String passengerId,
  }) async {
    try {
      final roomId = generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );
      
      final doc = await _firestore.collection('chat_rooms').doc(roomId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking chat room existence: $e');
      return false;
    }
  }

  /// Get unread count for user
  static Future<int> getUnreadCountForUser({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String userId,
  }) async {
    try {
      final roomId = generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );
      
      final doc = await _firestore.collection('chat_rooms').doc(roomId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          if (userId == driverId) {
            return (data['unreadDriver'] as int? ?? 0);
          } else if (userId == passengerId) {
            return (data['unreadPassenger'] as int? ?? 0);
          }
        }
      }
      return 0;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark all messages as read
  static Future<void> markAllAsRead({
    required String rideId,
    required String driverId,
    required String passengerId,
    required String userId,
  }) async {
    try {
      final roomId = generateRoomId(
        rideId: rideId,
        driverId: driverId,
        passengerId: passengerId,
      );
      
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'hasUnread': false,
      };

      if (userId == driverId) {
        updateData['unreadDriver'] = 0;
      } else if (userId == passengerId) {
        updateData['unreadPassenger'] = 0;
      }

      await _firestore.collection('chat_rooms').doc(roomId).update(updateData);
      
      debugPrint('📖 All messages marked as read for user: $userId');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Simple cleanup function (alternative)
  static Future<void> simpleCleanupDuplicateChatRooms() async {
    try {
      debugPrint('🔄 Starting simple duplicate chat rooms cleanup...');
      
      final snapshot = await _firestore.collection('chat_rooms').get();
      final Map<String, DocumentSnapshot> uniqueRooms = {};
      final List<DocumentReference> duplicates = [];
      
      for (final room in snapshot.docs) {
        final data = room.data() as Map<String, dynamic>?;
        if (data != null) {
          final rideId = data['rideId'] as String?;
          final driverId = data['driverId'] as String?;
          final passengerId = data['passengerId'] as String?;
          
          if (rideId != null && driverId != null && passengerId != null) {
            final key = generateRoomId(
              rideId: rideId,
              driverId: driverId,
              passengerId: passengerId,
            );
            
            if (!uniqueRooms.containsKey(key)) {
              uniqueRooms[key] = room;
            } else {
              // Compare timestamps to keep the most recent
              final existingRoom = uniqueRooms[key]!;
              final existingData = existingRoom.data() as Map<String, dynamic>?;
              final currentTimestamp = data['lastMessageTimestamp'] as int? ?? 0;
              final existingTimestamp = existingData?['lastMessageTimestamp'] as int? ?? 0;
              
              if (currentTimestamp > existingTimestamp) {
                duplicates.add(existingRoom.reference);
                uniqueRooms[key] = room;
              } else {
                duplicates.add(room.reference);
              }
            }
          }
        }
      }
      
      // Delete duplicates
      if (duplicates.isNotEmpty) {
        debugPrint('🗑️ Deleting ${duplicates.length} duplicate rooms...');
        final batch = _firestore.batch();
        for (final ref in duplicates) {
          batch.delete(ref);
        }
        await batch.commit();
        debugPrint('✅ Deleted ${duplicates.length} duplicate rooms');
      }
      
      debugPrint('🎉 Cleanup completed. ${uniqueRooms.length} unique rooms remaining.');
    } catch (e) {
      debugPrint('❌ Error in simple cleanup: $e');
    }
  }

  /// UPDATED: Function to update existing chat rooms with passenger names
  static Future<void> updateExistingChatRoomsWithPassengerNames() async {
    try {
      debugPrint('🔄 Updating existing chat rooms with passenger names...');
      
      final snapshot = await _firestore.collection('chat_rooms').get();
      final batch = _firestore.batch();
      int updatedCount = 0;
      
      for (final room in snapshot.docs) {
        final data = room.data() as Map<String, dynamic>?;
        if (data != null) {
          final passengerId = data['passengerId'] as String?;
          
          if (passengerId != null) {
            // Check if passengerName is missing, empty, or default
            final currentPassengerName = data['passengerName'] as String?;
            if (currentPassengerName == null || 
                currentPassengerName.isEmpty || 
                currentPassengerName == 'Passenger' ||
                currentPassengerName == 'PassengerName') {
              
              debugPrint('🔍 Found chat room without proper passenger name: ${room.id}');
              debugPrint('   Passenger ID: $passengerId');
              debugPrint('   Current name: "$currentPassengerName"');
              
              try {
                // Get passenger info from Firestore
                final passengerDoc = await _firestore.collection('passengers').doc(passengerId).get();
                if (passengerDoc.exists) {
                  final passengerData = passengerDoc.data() as Map<String, dynamic>?;
                  if (passengerData != null) {
                    // Try different field names
                    final passengerName = passengerData['fullName'] ?? 
                                         passengerData['name'] ?? 
                                         passengerData['displayName'] ??
                                         passengerData['username'] ??
                                         'Passenger';
                    
                    debugPrint('   Found passenger in Firestore: $passengerName');
                    
                    // Update the chat room
                    batch.update(room.reference, {
                      'passengerName': passengerName,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    updatedCount++;
                    
                    debugPrint('✅ Updated room ${room.id} with passenger name: "$passengerName"');
                  } else {
                    debugPrint('⚠️ Passenger data is null for ID: $passengerId');
                  }
                } else {
                  debugPrint('⚠️ Passenger document not found for ID: $passengerId');
                }
              } catch (e) {
                debugPrint('❌ Error fetching passenger data: $e');
              }
            }
          }
        }
      }
      
      if (updatedCount > 0) {
        await batch.commit();
        debugPrint('🎉 Successfully updated $updatedCount chat rooms with passenger names');
      } else {
        debugPrint('✅ All chat rooms already have proper passenger names');
      }
      
    } catch (e) {
      debugPrint('❌ Error updating chat rooms: $e');
      rethrow;
    }
  }

  /// NEW: Get passenger info from Firestore
  static Future<Map<String, dynamic>?> getPassengerInfo(String passengerId) async {
    try {
      final doc = await _firestore.collection('passengers').doc(passengerId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting passenger info: $e');
      return null;
    }
  }

  static Future<void> updateChatRoomPassengerName({
    required String roomId,
    required String passengerName,
  }) async {
    try {
      await _firestore.collection('chat_rooms').doc(roomId).update({
        'passengerName': passengerName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Updated room $roomId with passenger name: "$passengerName"');
    } catch (e) {
      debugPrint('Error updating chat room passenger name: $e');
    }
  }
}