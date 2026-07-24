import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uthmshareride/modules/Message/driverInfo.dart';
import 'package:uthmshareride/modules/ShareRide/ridedata.dart';
import 'package:uthmshareride/modules/Message/roomchat.dart';

class DriverMessagePage extends StatefulWidget {
  final Ride ride;
  final String bookingId;
  final String driverName;
  final String currentUserId;
  final String passengerId;

  const DriverMessagePage({
    super.key,
    required this.ride,
    required this.bookingId,
    required this.driverName,
    required this.currentUserId,
    required this.passengerId,
  });

  @override
  State<DriverMessagePage> createState() => _DriverMessagePageState();
}

class _DriverMessagePageState extends State<DriverMessagePage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _focusNode = FocusNode();

  String? _driverPhotoUrl;
  String? _driverPhone;
  bool _loadingPhone = true;

  CollectionReference<Map<String, dynamic>> get _chatCollectionRef =>
      _firestore.collection('rides')
        .doc(widget.ride.id)
        .collection('chats');

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ================= LOAD DRIVER INFO =================
  Future<void> _loadDriverInfo() async {
    try {
      final document = await _firestore
          .collection('drivers')
          .doc(widget.ride.driverId)
          .get();

      if (document.exists && mounted) {
        setState(() {
          _driverPhotoUrl = document.data()?['photoUrl'];
          _driverPhone = document.data()?['phone'];
          _loadingPhone = false;
        });
      } else {
        setState(() {
          _loadingPhone = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver info: $e');
      setState(() {
        _loadingPhone = false;
      });
    }
  }

  // ================= CALL DRIVER =================
  Future<void> _callDriver() async {
    if (_driverPhone == null || _driverPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number not available')),
      );
      return;
    }

final confirmCall = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    title: const Text(
      'Call Driver',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Color(0xFF365770),
      ),
    ),
    content: Text(
      'Call ${widget.driverName}?',
      style: const TextStyle(fontSize: 16),
    ),
    actionsAlignment: MainAxisAlignment.spaceBetween,
    actions: [
      // Cancel Button (Merah)
      ElevatedButton(
        onPressed: () => Navigator.pop(context, false),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          shadowColor: Colors.red.withOpacity(0.3),
        ),
        child: const Text('CANCEL'),
      ),
      
      // Call Button (Hijau)
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
          shadowColor: Colors.green.withOpacity(0.3),
        ),
        child: const Text('CALL'),
      ),
    ],
  ),
);

    if (confirmCall != true) return;

    final callUri = Uri.parse('tel:${_driverPhone!}');
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot make call')),
      );
    }
  }

  // ================= SEND TEXT MESSAGE =================
  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    try {
      // Simpan teks sebelum di-clear
      final messageText = text;
      
      // 🔥 CLEAR TEXT FIELD SEBELUM MENGIRIM
      _textController.clear();
      
      // 🔥 Hilangkan fokus keyboard
      _focusNode.unfocus();

      // Add message to chats subcollection
      await _chatCollectionRef.add({
        'type': 'text',
        'text': messageText,
        'senderId': widget.currentUserId,  // Passenger ID
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update chat room
      await _updateChatRoom(messageText);
      
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  // ================= IMAGE PICKING WITH PREVIEW =================
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      
      if (pickedImage == null) return;
      
      // Show preview before sending
      await _showImagePreview(File(pickedImage.path));
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  Future<void> _showImagePreview(File imageFile) async {
    // Show preview dialog
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview image
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  imageFile,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // If user chooses to send, upload the image
    if (shouldSend == true) {
      await _sendImageMessage(imageFile);
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref(
        'chat_images/${widget.ride.id}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await storageRef.putFile(imageFile);
      final imageUrl = await storageRef.getDownloadURL();

      // Add image message to chat
      await _chatCollectionRef.add({
        'type': 'image',
        'imageUrl': imageUrl,
        'senderId': widget.currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update chat room
      await _updateChatRoom('📷 Image');
      _scrollToBottom();

      // Close loading dialog
      Navigator.pop(context);

    } catch (e) {
      debugPrint('Error sending image: $e');
      
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send image')),
      );
    }
  }

  // ================= UPDATE CHAT ROOM =================
  Future<void> _updateChatRoom(String lastMessage) async {
    try {
      // Get driver info
      final driverDoc = await _firestore
          .collection('drivers')
          .doc(widget.ride.driverId)
          .get();
      
      final driverName = driverDoc.data()?['name'] ?? widget.driverName;
      final driverPhotoUrl = driverDoc.data()?['photoUrl'] ?? _driverPhotoUrl ?? '';

      // Get passenger info
      final passengerDoc = await _firestore
          .collection('passengers')
          .doc(widget.passengerId)
          .get();
      
      final passengerData = passengerDoc.data();
      final passengerName = passengerData?['name'] ?? 'Passenger';
      final passengerPhotoUrl = passengerData?['photoUrl'] ?? '';

      // PERBAIKAN 1: Ganti dengan updateOrCreateChatRoom
      await ChatRoomService.updateOrCreateChatRoom(
        rideId: widget.ride.id,
        driverId: widget.ride.driverId,
        driverName: driverName,
        driverPhotoUrl: driverPhotoUrl,
        passengerId: widget.passengerId,
        passengerName: passengerName,
        passengerPhotoUrl: passengerPhotoUrl,
        lastMessage: lastMessage,
        senderId: widget.passengerId, // Passenger yang mengirim
      );

      // PERBAIKAN 2: Ganti dengan incrementUnreadForRecipient
      await ChatRoomService.incrementUnreadForRecipient(
        rideId: widget.ride.id,
        driverId: widget.ride.driverId,
        passengerId: widget.passengerId,
        senderId: widget.passengerId, // Passenger yang mengirim
      );

    } catch (e) {
      debugPrint('ERROR updating chat room: $e');
    }
  }

  // ================= VIEW IMAGE FULL SCREEN =================
  void _viewImageFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download feature coming soon')),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 5.0,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= DATE/TIME FORMATTING =================
  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(now, date)) return 'Today';
    if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), date)) {
      return 'Yesterday';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  String _formatMessageTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF365770),
        leading: const BackButton(color: Colors.white),
        title: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => DriverInfoDialog(
                ride: widget.ride,
                driverName: widget.driverName,
                driverPhotoUrl: _driverPhotoUrl,
                passengerId: widget.currentUserId,
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: _driverPhotoUrl != null
                    ? NetworkImage(_driverPhotoUrl!)
                    : null,
                child: _driverPhotoUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driverName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: _loadingPhone ? null : _callDriver,
            tooltip: 'Call Driver',
          ),
        ],
      ),

      // ================= CHAT BODY =================
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _chatCollectionRef
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, 
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No messages yet'),
                        Text('Say hello to start the conversation!'),
                      ],
                    ),
                  );
                }

                DateTime? previousMessageDay;
                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageDoc = messages[index];
                    final messageData = messageDoc.data();
                    
                    final isSentByMe = messageData['senderId'] == widget.currentUserId;
                    final messageTimestamp = messageData['timestamp'] as Timestamp?;
                    final messageTime = messageTimestamp?.toDate();
                    
                    final showDateSeparator = messageTime != null &&
                        (previousMessageDay == null ||
                            !DateUtils.isSameDay(previousMessageDay!, messageTime));
                    
                    if (messageTime != null) {
                      previousMessageDay = messageTime;
                    }

                    return Column(
                      children: [
                        // Date separator
                        if (showDateSeparator && messageTime != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatMessageDate(messageTime),
                                style: const TextStyle(
                                  fontSize: 12, 
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        
                        // Message bubble
                        Align(
                          alignment: isSentByMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: messageData['type'] == 'image'
                                ? GestureDetector(
                                    onTap: () => _viewImageFullScreen(
                                      messageData['imageUrl']
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          messageData['imageUrl'],
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Container(
                                              width: 200,
                                              height: 200,
                                              color: Colors.grey[200],
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded /
                                                          loadingProgress.expectedTotalBytes!
                                                      : null,
                                                ),
                                              ),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 200,
                                              height: 200,
                                              color: Colors.grey[200],
                                              child: const Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.broken_image, color: Colors.grey),
                                                  Text('Failed to load image'),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    margin: EdgeInsets.only(
                                      left: isSentByMe ? 40 : 0,
                                      right: isSentByMe ? 0 : 40,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSentByMe
                                          ? const Color(0xFF365770)
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      messageData['text'] ?? '',
                                      style: TextStyle(
                                        color: isSentByMe 
                                            ? Colors.white 
                                            : Colors.black,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        
                        // Message time
                        if (messageTime != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 6),
                            child: Align(
                              alignment: isSentByMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: isSentByMe ? 8 : 0,
                                  left: isSentByMe ? 0 : 8,
                                ),
                                child: Text(
                                  _formatMessageTime(messageTime),
                                  style: const TextStyle(
                                    fontSize: 10, 
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ================= MESSAGE INPUT =================
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: const Color(0xFF365770),
              child: Row(
                children: [
                  _buildCircularButton(
                    icon: Icons.add,
                    onTap: _showImageSourceOptions,
                    tooltip: 'Attach photo',
                    iconColor: const Color(0xFF365770),
                  ),
                  const SizedBox(width: 8),
                  
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              minLines: 1,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Type your message...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                                suffixIcon: _textController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _textController.clear();
                                          _focusNode.requestFocus();
                                        },
                                        padding: EdgeInsets.zero,
                                      )
                                    : null,
                              ),
                              onSubmitted: (_) => _sendTextMessage(),
                              textInputAction: TextInputAction.send,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  _buildCircularButton(
                    icon: Icons.send,
                    onTap: _sendTextMessage,
                    iconColor: const Color(0xFF365770),
                    tooltip: 'Send message',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= CIRCULAR BUTTON WIDGET =================
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(icon, color: iconColor),
          onPressed: onTap,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          iconSize: 20,
        ),
      ),
    );
  }
}