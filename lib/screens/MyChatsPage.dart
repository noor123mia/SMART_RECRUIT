// lib/screens/my_chats_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/screens/In_App_Chat_Screen.dart';

/// Role-aware My Chats page with beautiful, professional UI
class MyChatsPage extends StatelessWidget {
  final bool isRecruiter;
  const MyChatsPage({Key? key, required this.isRecruiter}) : super(key: key);

  // Color Theme
  static const Color primaryColor = Color(0xFF3B82F6);
  static const Color secondaryColor = Color(0xFF1D4ED8);
  static const Color accentColor = Color(0xFF0D9488);

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

  /// Resolve user info: name and email
  Future<Map<String, String>> _getUserInfo(String uid) async {
    final fs = FirebaseFirestore.instance;
    Map<String, String> info = {'name': '', 'email': ''};

    // Try 'users' (lowercase)
    final docLower = await fs.collection('users').doc(uid).get();
    if (docLower.exists) {
      final data = docLower.data()!;
      info['name'] = (data['name'] as String?)?.trim() ?? '';
      info['email'] = (data['email'] as String?)?.trim() ?? '';
      if (info['name']!.isNotEmpty || info['email']!.isNotEmpty) {
        return info;
      }
    }

    // Fallback to 'Users' (uppercase)
    final docUpper = await fs.collection('Users').doc(uid).get();
    if (docUpper.exists) {
      final data = docUpper.data()!;
      info['name'] = (data['name'] as String?)?.trim() ?? '';
      info['email'] = (data['email'] as String?)?.trim() ?? '';
      if (info['name']!.isNotEmpty || info['email']!.isNotEmpty) {
        return info;
      }
    }

    // Try 'JobSeekersProfiles' for name (for candidates)
    final profileDoc = await fs.collection('JobSeekersProfiles').doc(uid).get();
    if (profileDoc.exists) {
      final data = profileDoc.data()!;
      info['name'] = (data['name'] as String?)?.trim() ?? '';
      if (info['name']!.isNotEmpty) {
        return info;
      }
    }

    // Last resort: for self, use Auth
    final me = FirebaseAuth.instance.currentUser;
    if (me != null && me.uid == uid) {
      info['name'] = me.displayName ?? '';
      info['email'] = me.email ?? '';
    }

    return info;
  }

  // -------- Recruiter view: candidates who applied to my jobs --------
  Future<List<String>> _fetchCandidateIdsForRecruiter(String meUid) async {
    final fs = FirebaseFirestore.instance;

    final jobsSnap = await fs
        .collection('JobsPosted')
        .where('recruiterId', isEqualTo: meUid)
        .get();
    final jobIds = jobsSnap.docs.map((d) => d.id).toList();
    if (jobIds.isEmpty) return [];

    final candidateIds = <String>{};

    Future<void> readAppsChunk(List<String> chunk) async {
      final apps = await fs
          .collection('AppliedCandidates')
          .where('jobId', whereIn: chunk)
          .get();
      for (final a in apps.docs) {
        final cid = a.data()['candidateId'] as String?;
        if (cid != null && cid.isNotEmpty && cid != meUid) {
          candidateIds.add(cid);
        }
      }
    }

    const maxIn = 10;
    for (var i = 0; i < jobIds.length; i += maxIn) {
      final end = (i + maxIn > jobIds.length) ? jobIds.length : i + maxIn;
      await readAppsChunk(jobIds.sublist(i, end));
    }

    return candidateIds.toList()..sort();
  }

  // -------- Candidate view: recruiters who sent offer letters OR initiated chats --------
  Future<List<String>> _fetchRecruiterIdsForCandidate(String meUid) async {
    final fs = FirebaseFirestore.instance;
    final recruiterIds = <String>{};

    // Fetch from OfferLetters
    final offersSnap = await fs
        .collection('OfferLetters')
        .where('candidateId', isEqualTo: meUid)
        .get();
    for (final o in offersSnap.docs) {
      final rid = o.data()['recruiterId'] as String?;
      if (rid != null && rid.isNotEmpty && rid != meUid) {
        recruiterIds.add(rid);
      }
    }

    // Fetch from chats: recruiters who have a chat with this candidate
    final chatsSnap = await fs
        .collection('chats')
        .where('participants', arrayContains: meUid)
        .get();
    for (final c in chatsSnap.docs) {
      final parts = c.data()['participants'] as List<dynamic>? ?? [];
      for (final p in parts) {
        final pid = p as String?;
        if (pid != null && pid.isNotEmpty && pid != meUid) {
          recruiterIds.add(pid);
        }
      }
    }

    return recruiterIds.toList()..sort();
  }

  Widget _buildDisabledState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .chat_bubble_outline, // Replaced with a valid icon for disabled chat
                size: 64,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Chats Disabled',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Enable chats in Settings to send and receive messages.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    final meUid = me.uid;
    final title = isRecruiter ? 'My Applicants' : 'Recruiters';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: FutureBuilder<bool>(
        future: _isChatEnabledForUser(meUid),
        builder: (context, enabledSnap) {
          if (enabledSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            );
          }
          final isEnabled = enabledSnap.data ?? true;
          if (!isEnabled) {
            return _buildDisabledState(context);
          }

          // Chat is enabled - show the role-specific content
          return isRecruiter
              ? FutureBuilder<List<String>>(
                  future: _fetchCandidateIdsForRecruiter(meUid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      );
                    }
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.inbox_outlined,
                        message: 'No applicants yet',
                        subtitle: 'Applicants will appear here once they apply',
                      );
                    }
                    final peers = snap.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: peers.length,
                      itemBuilder: (context, i) {
                        final peerId = peers[i];
                        return _buildChatItem(context, peerId);
                      },
                    );
                  },
                )
              : FutureBuilder<List<String>>(
                  future: _fetchRecruiterIdsForCandidate(meUid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      );
                    }
                    if (!snap.hasData || snap.data!.isEmpty) {
                      return _buildEmptyState(
                        icon: Icons.work_outline,
                        message: 'No recruiters yet',
                        subtitle:
                            'Recruiters who send you offers or start chats will appear here',
                      );
                    }
                    final peers = snap.data!;

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: peers.length,
                      itemBuilder: (context, i) {
                        final peerId = peers[i];
                        return _buildChatItem(context, peerId);
                      },
                    );
                  },
                );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(BuildContext context, String peerId) {
    return FutureBuilder<Map<String, String>>(
      future: _getUserInfo(peerId),
      builder: (context, infoSnap) {
        if (infoSnap.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final info = infoSnap.data ?? {'name': '', 'email': ''};
        final displayName = info['name']!.isNotEmpty
            ? info['name']!
            : (info['email']!.isNotEmpty ? info['email']! : 'User');
        final subtitleText = info['email']!.isNotEmpty
            ? info['email']!
            : (info['name']!.isNotEmpty ? 'No email' : 'Tap to chat');

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      peerId: peerId,
                      peerName: displayName,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[900],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
