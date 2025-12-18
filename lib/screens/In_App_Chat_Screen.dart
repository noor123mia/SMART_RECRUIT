// lib/screens/In_App_Chat_Screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;

  const ChatScreen({
    Key? key,
    required this.peerId,
    required this.peerName,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _auth = FirebaseAuth.instance;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String _chatId;
  String _currentPeerName = '';

  // Color Theme
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color secondaryColor = Color(0xFF1D4ED8);
  static const Color accentColor = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    final myId = _auth.currentUser!.uid;
    _chatId = (myId.compareTo(widget.peerId) < 0)
        ? '${myId}_${widget.peerId}'
        : '${widget.peerId}_${myId}';
    _currentPeerName = widget.peerName;
    _refreshPeerName();
    _ensureChatDoc();
    _checkMyChatEnabled(myId);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Check if chat is enabled for a user (from 'UserSettings' first, fallback to 'users' or 'Users')
  Future<bool> _isChatEnabledForUser(String uid) async {
    try {
      // Primary: 'UserSettings'
      final docSettings = await FirebaseFirestore.instance
          .collection('UserSettings')
          .doc(uid)
          .get();
      if (docSettings.exists) {
        return (docSettings.data()?['chatEnabled'] as bool?) ?? true;
      }

      // Fallback to 'users'
      final docUsers =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (docUsers.exists) {
        return (docUsers.data()?['chatEnabled'] as bool?) ?? true;
      }

      // Fallback to 'Users'
      final docUpper =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (docUpper.exists) {
        return (docUpper.data()?['chatEnabled'] as bool?) ?? true;
      }
    } catch (e) {
      print('Error checking chat enabled: $e');
    }
    return true;
  }

  Future<void> _checkMyChatEnabled(String myId) async {
    final myEnabled = await _isChatEnabledForUser(myId);
    if (!myEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Chats disabled. Enable in Settings.')),
          );
        }
      });
    }
  }

  // ---------- Name/Email resolution ----------
  Future<String> _nameFor(String uid) async {
    final fs = FirebaseFirestore.instance;

    // Try 'users'
    try {
      final u = await fs.collection('users').doc(uid).get();
      final d = u.data();
      if (d != null) {
        final n = (d['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) return n;
        final e = (d['email'] as String?)?.trim();
        if (e != null && e.isNotEmpty) return e;
      }
    } catch (_) {}

    // Fallback to 'Users'
    try {
      final u = await fs.collection('Users').doc(uid).get();
      final d = u.data();
      if (d != null) {
        final n = (d['name'] as String?)?.trim();
        if (n != null && n.isNotEmpty) return n;
        final e = (d['email'] as String?)?.trim();
        if (e != null && e.isNotEmpty) return e;
      }
    } catch (_) {}

    // For candidates: JobSeekersProfiles
    try {
      final p = await fs.collection('JobSeekersProfiles').doc(uid).get();
      final pd = p.data();
      final pn = (pd?['name'] as String?)?.trim();
      if (pn != null && pn.isNotEmpty) return pn;
    } catch (_) {}

    // Self fallback
    final me = _auth.currentUser;
    if (me != null && me.uid == uid) {
      return me.displayName ?? me.email ?? 'User';
    }

    return 'User';
  }

  Future<void> _refreshPeerName() async {
    final refreshedName = await _nameFor(widget.peerId);
    if (mounted && refreshedName != _currentPeerName) {
      setState(() => _currentPeerName = refreshedName);
    }
  }

  Future<void> _ensureChatDoc() async {
    final ref = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    final myId = _auth.currentUser!.uid;

    final meName = await _nameFor(myId);
    final peerName = await _nameFor(widget.peerId);

    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [myId, widget.peerId],
        'updatedAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'userA': {'id': myId, 'name': meName},
        'userB': {'id': widget.peerId, 'name': peerName},
      });
    } else {
      // Refresh names on open
      await ref.set({
        'participants': FieldValue.arrayUnion([myId, widget.peerId]),
        'userA': {'id': myId, 'name': meName},
        'userB': {'id': widget.peerId, 'name': peerName},
      }, SetOptions(merge: true));
    }
  }

  // ---------- Clear All Messages from My View ----------
  Future<void> _clearAllMessagesFromMyView() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Messages'),
        content: const Text(
            'Are you sure you want to clear all messages from your view in this chat? This will remove all messages (yours and received) from your view only and cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _performClearAllMessagesFromMyView();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearAllMessagesFromMyView() async {
    final myId = _auth.currentUser!.uid;
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages');
    final querySnapshot = await messagesRef.get();

    if (querySnapshot.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No messages to clear.')),
        );
      }
      return;
    }

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {
        'deletedFor': FieldValue.arrayUnion([myId]),
      });
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('All messages have been cleared from your view.')),
      );
    }

    // Scroll to bottom after clearing
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // ---------- Send Message ----------
  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final myId = _auth.currentUser!.uid;
    final myEnabled = await _isChatEnabledForUser(myId);
    final peerEnabled = await _isChatEnabledForUser(widget.peerId);

    if (!myEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You have disabled chats. Enable in Settings.')),
        );
      }
      return;
    }
    if (!peerEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('This user has disabled chats. Cannot send message.')),
        );
      }
      return;
    }

    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc();

    await msgRef.set({
      'id': msgRef.id,
      'chatId': _chatId,
      'text': trimmed,
      'senderId': myId,
      'receiverId': widget.peerId,
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': <String>[],
    });

    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'lastMessage': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _textCtrl.clear();

    // Scroll to bottom
    _scrollCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(date);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEE HH:mm').format(date);
    } else {
      return DateFormat('MMM dd, HH:mm').format(date);
    }
  }

  Widget _buildMessagesStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          );
        }
        final docs = snap.data!.docs;
        final myId = _auth.currentUser!.uid;
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final deletedFor = data['deletedFor'] as List<dynamic>? ?? [];
          return !deletedFor.contains(myId);
        }).toList();

        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Start the conversation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Send your first message below',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollCtrl,
          reverse: true,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, i) {
            final doc = filteredDocs[i];
            final data = doc.data() as Map<String, dynamic>;
            final isMe = data['senderId'] == myId;
            final text = (data['text'] ?? '') as String;
            final timestamp = data['createdAt'] as Timestamp?;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accentColor, accentColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _currentPeerName.isNotEmpty
                              ? _currentPeerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.7,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isMe ? null : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            text,
                            style: TextStyle(
                              fontSize: 15,
                              color: isMe ? Colors.white : Colors.grey[900],
                              height: 1.4,
                            ),
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: isMe
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(bool peerEnabled) {
    if (!peerEnabled) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This user has disabled chats',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Normal input
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _textCtrl,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _sendMessage(_textCtrl.text),
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _currentPeerName.isNotEmpty
                      ? _currentPeerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _currentPeerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _clearAllMessagesFromMyView,
            tooltip: 'Clear all messages from my view',
          ),
        ],
      ),
      body: FutureBuilder<bool>(
        future: _isChatEnabledForUser(widget.peerId),
        builder: (context, peerSnap) {
          if (peerSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }
          final peerEnabled = peerSnap.data ?? true;

          return Column(
            children: [
              Expanded(
                child: _buildMessagesStream(),
              ),
              _buildInputArea(peerEnabled),
            ],
          );
        },
      ),
    );
  }
}