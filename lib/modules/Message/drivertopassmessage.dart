import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uthmshareride/modules/Message/passengerInfo.dart';
import 'package:uthmshareride/modules/Message/roomchat.dart';

class PassengerMessagePage extends StatefulWidget {
  final String rideId;
  final String driverId;
  final String passengerId;
  final String passengerName;

  const PassengerMessagePage({
    super.key,
    required this.rideId,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
  });

  @override
  State<PassengerMessagePage> createState() => _PassengerMessagePageState();
}

class _PassengerMessagePageState extends State<PassengerMessagePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  String? _passengerPhotoUrl;
  String? _passengerPhone;
  bool _loadingPhone = true;

  String get _currentUserId => widget.driverId;

  CollectionReference<Map<String, dynamic>> get _chatCollectionRef =>
      _firestore.collection('rides')
        .doc(widget.rideId)
        .collection('chats');

  @override
  void initState() {
    super.initState();
    _loadPassengerInfo();
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ================= LOAD PASSENGER INFO =================
  Future<void> _loadPassengerInfo() async {
    try {
      final document = await _firestore
          .collection('passengers')
          .doc(widget.passengerId)
          .get();

      if (document.exists && mounted) {
        setState(() {
          _passengerPhotoUrl = document.data()?['photoUrl'];
          _passengerPhone = document.data()?['phone'];
          _loadingPhone = false;
        });
      } else {
        setState(() {
          _loadingPhone = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading passenger info: $e');
      setState(() {
        _loadingPhone = false;
      });
    }
  }

  // ================= CALL PASSENGER =================
  Future<void> _callPassenger() async {
    if (_passengerPhone == null || _passengerPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passenger phone number not available')),
      );
      return;
    }

final confirmCall = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text(
      'Call Passenger',
      style: TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    content: Text('Call ${widget.passengerName}?'),
    actions: [
      // Cancel Button (Merah)
      ElevatedButton(
        onPressed: () => Navigator.pop(context, false),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red, // Warna merah
          foregroundColor: Colors.white, // Text putih
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Cancel'),
      ),
      
      // Call Button (Hijau)
      ElevatedButton(
        onPressed: () => Navigator.pop(context, true),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green, // Warna hijau
          foregroundColor: Colors.white, // Text putih
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Call'),
      ),
    ],
  ),
);

    if (confirmCall != true) return;

    final callUri = Uri.parse('tel:${_passengerPhone!}');
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
      
      _focusNode.unfocus();

      // Add message to chats subcollection
      await _chatCollectionRef.add({
        'type': 'text',
        'text': messageText,
        'senderId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update chat room with last message
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
  void _pickImageOption() {
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
      
      // 🔥 TAMBAHAN: Tunjukkan preview dulu
      await _showImagePreview(File(pickedImage.path));
      
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to pick image')),
      );
    }
  }

  // 🔥 TAMBAHAN: Function untuk show preview
  Future<void> _showImagePreview(File imageFile) async {
    // Tampilkan dialog preview
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

    // Jika user pilih "Send", kirim gambar
    if (shouldSend == true) {
      await _sendImageMessage(imageFile);
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref(
        'chat_images/${widget.rideId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await storageRef.putFile(imageFile);
      final imageUrl = await storageRef.getDownloadURL();

      // Add image message to chat
      await _chatCollectionRef.add({
        'type': 'image',
        'imageUrl': imageUrl,
        'senderId': _currentUserId,
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
          .doc(widget.driverId)
          .get();
      
      final driverName = driverDoc.data()?['name'] ?? 'Driver';
      final driverPhotoUrl = driverDoc.data()?['photoUrl'] ?? '';

      // Get passenger info
      final passengerDoc = await _firestore
          .collection('passengers')
          .doc(widget.passengerId)
          .get();
      
      final passengerName = passengerDoc.data()?['name'] ?? widget.passengerName;
      final passengerPhotoUrl = passengerDoc.data()?['photoUrl'] ?? _passengerPhotoUrl ?? '';

      await ChatRoomService.updateOrCreateChatRoom(
        rideId: widget.rideId,
        driverId: widget.driverId,
        driverName: driverName,
        driverPhotoUrl: driverPhotoUrl,
        passengerId: widget.passengerId,
        passengerName: passengerName,
        passengerPhotoUrl: passengerPhotoUrl,
        lastMessage: lastMessage,
        senderId: widget.driverId,
      );

      await ChatRoomService.incrementUnreadForRecipient(
        rideId: widget.rideId,
        driverId: widget.driverId,
        passengerId: widget.passengerId,
        senderId: widget.driverId, // Driver yang mengirim
      );

    } catch (e) {
      debugPrint('ERROR updating chat room: $e');
    }
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
              builder: (context) => PassengerInfoDialog(
                rideId: widget.rideId,
                driverId: widget.driverId,
                passengerId: widget.passengerId,
                passengerName: widget.passengerName,
                passengerPhotoUrl: _passengerPhotoUrl,
              ),
            );
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: _passengerPhotoUrl != null
                    ? NetworkImage(_passengerPhotoUrl!)
                    : null,
                child: _passengerPhotoUrl == null
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.passengerName,
                    maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: _loadingPhone ? null : _callPassenger,
            tooltip: 'Call Passenger',
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
                        Text('Start the conversation'),
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
                    
                    final isSentByMe = messageData['senderId'] == _currentUserId;
                    final messageTime = (messageData['timestamp'] as Timestamp?)?.toDate();
                    
                    // Check if we need to show date separator
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
                            child: Text(
                              _formatMessageDate(messageTime),
                              style: const TextStyle(
                                fontSize: 12, 
                                color: Colors.grey,
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
                                    onTap: () {
                                      // Show image in full screen
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          backgroundColor: Colors.black,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AppBar(
                                                backgroundColor: Colors.black,
                                                automaticallyImplyLeading: false,
                                                actions: [
                                                  IconButton(
                                                    icon: const Icon(Icons.close, color: Colors.white),
                                                    onPressed: () => Navigator.pop(context),
                                                  ),
                                                ],
                                              ),
                                              InteractiveViewer(
                                                minScale: 0.1,
                                                maxScale: 5.0,
                                                child: Image.network(
                                                  messageData['imageUrl'],
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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
                                  )
                                : Container(
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
                                      ),
                                    ),
                                  ),
                          ),
                        ),
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
                    onTap: _pickImageOption,
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
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Message passenger...',
                          border: InputBorder.none,
                          suffixIcon: _textController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _textController.clear();
                                    _focusNode.requestFocus();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _sendTextMessage(),
                        textInputAction: TextInputAction.send,
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