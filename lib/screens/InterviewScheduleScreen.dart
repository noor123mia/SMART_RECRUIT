import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class InterviewScheduleScreen extends StatefulWidget {
  const InterviewScheduleScreen({Key? key}) : super(key: key);

  @override
  State<InterviewScheduleScreen> createState() =>
      _InterviewScheduleScreenState();
}

class _InterviewScheduleScreenState extends State<InterviewScheduleScreen> {
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  User? get _me => _auth.currentUser;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (_me == null) {
      setState(() {
        _loading = false;
        _error = 'User not logged in';
      });
      return;
    }
    try {
      await _load();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load: $e';
      });
    }
  }

  Future<void> _load() async {
    if (_me == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      Query query = _fs.collection('ScheduledInterviews');

      // Always load as candidate
      query = query.where('candidateId', isEqualTo: _me!.uid);

      // Try to get data without ordering first (as fallback)
      QuerySnapshot snap;
      try {
        // First attempt: with ordering (if index exists)
        query = query.orderBy('date').orderBy('time');
        snap = await query.get();
      } catch (e) {
        // Fallback: without ordering if index doesn't exist
        query = _fs
            .collection('ScheduledInterviews')
            .where('candidateId', isEqualTo: _me!.uid);
        snap = await query.get();
      }

      final list = snap.docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        return {
          'id': d.id,
          'recruiterId': m['recruiterId'] ?? '',
          'recruiterName': m['recruiterName'] ?? 'Recruiter',
          'candidateId': m['candidateId'] ?? '',
          'candidateName': m['candidateName'] ?? 'Candidate',
          'position': m['position'] ?? 'Position',
          'interviewType': m['interviewType'] ?? 'Interview',
          'interviewer': m['interviewer'] ?? 'Interviewer',
          'date': m['date'], // allow String or Timestamp
          'time': m['time'] ?? '',
          'duration': (m['duration']?.toString() ?? '0'),
          'platform': m['platform'] ?? 'Platform',
          'meetingLink': m['meetingLink'] ?? '',
          'status': m['status'] ?? 'Scheduled',
          'sentToCandidateAt': m['sentToCandidateAt'],
          'updatedAt': m['updatedAt'],
        };
      }).toList();

      // Client-side safe sort (by date then time) regardless of data types
      list.sort((a, b) {
        final da = _parseDate(a['date']);
        final db = _parseDate(b['date']);
        final dateCompare = da.compareTo(db);
        if (dateCompare != 0) return dateCompare;

        // If same date, sort by time
        final timeA = (a['time'] ?? '').toString();
        final timeB = (b['time'] ?? '').toString();
        return timeA.compareTo(timeB);
      });

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load interviews: $e';
      });
    }
  }

  // ---- Actions ----

  Future<void> _join(Map<String, dynamic> it) async {
    final link = (it['meetingLink'] ?? '').toString().trim();
    final platform = (it['platform'] ?? 'Smart Recruit Meet').toString();

    if (link.isEmpty) {
      _toast('No meeting link available.');
      return;
    }

    // Sanitize intent:// links (common for Google Meet on Android)
    String sanitizedLink = link;
    if (link.startsWith('intent://')) {
      final idx = link.indexOf('link=');
      if (idx != -1) {
        final enc = link.substring(idx + 5);
        final cut =
            enc.contains('&') ? enc.substring(0, enc.indexOf('&')) : enc;
        try {
          sanitizedLink = Uri.decodeFull(cut);
        } catch (_) {
          sanitizedLink = cut;
        }
      }
    }

    // Helper to try launching a URL (with mode)
    Future<bool> _tryLaunch(String url,
        {LaunchMode mode = LaunchMode.externalApplication}) async {
      try {
        final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    // 1. If it's a full HTTP link (e.g., Jitsi or pasted), try it directly
    if (sanitizedLink.startsWith('http')) {
      if (await _tryLaunch(sanitizedLink)) {
        _toast('Opening meeting...');
        return;
      }
    }

    // 2. Platform-specific fallbacks (Teams removed)
    switch (platform) {
      case 'Google Meet':
        // Try web URLs with external first, then in-app
        final webUrls = [
          'https://meet.google.com/new?pli=1',
          'https://meet.google.com/?hs=197',
          'https://meet.google.com/'
        ];
        for (final u in webUrls) {
          if (await _tryLaunch(u, mode: LaunchMode.externalApplication)) {
            _toast('Opening Google Meet...');
            return;
          }
        }
        for (final u in webUrls) {
          if (await _tryLaunch(u, mode: LaunchMode.inAppWebView)) {
            _toast('Opening in app...');
            return;
          }
        }
        break;

      case 'Zoom':
        // App deep-link first, then web
        if (await _tryLaunch('zoomus://zoom.us/start')) {
          _toast('Opening Zoom...');
          return;
        }
        if (await _tryLaunch('https://zoom.us/start/videomeeting')) {
          _toast('Opening Zoom...');
          return;
        }
        break;

      case 'Smart Recruit Meet':
      default:
        // Already tried direct link above; fallback to in-app if needed
        if (await _tryLaunch(sanitizedLink, mode: LaunchMode.inAppWebView)) {
          _toast('Opening in app...');
          return;
        }
        break;
    }

    // Final fallback toast
    _toast(
        'Cannot open $platform. Ensure the app is installed or check the link.');
  }

  // ---- Helpers & UI ----

  DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is Timestamp) return v.toDate();
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    final title = 'My Interviews'; // Always for candidate
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red[600], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _refresh, // Retry
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                        ),
                        child: const Text('Retry',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? _EmptyState() // Candidate empty state
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: const Color(0xFF3B82F6),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _InterviewCard(
                          data: _items[i],
                          onJoin: _join,
                        ),
                      ),
                    ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function(Map<String, dynamic>) onJoin;

  const _InterviewCard({
    Key? key,
    required this.data,
    required this.onJoin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'Scheduled').toString();
    final statusInfo = _getStatusInfo(status);
    final meetingLink = (data['meetingLink'] ?? '').toString();
    final platform = (data['platform'] ?? '').toString();
    final canJoin = meetingLink.isNotEmpty &&
        platform.toLowerCase() != 'platform' &&
        (status.toLowerCase() == 'scheduled' ||
            status.toLowerCase() == 'invited' ||
            status.toLowerCase() == 'confirmed');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + recruiter name + status chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.video_call,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['recruiterName'] ?? 'Recruiter',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['position'] ?? 'Position',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusInfo['bgColor'],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusInfo['icon'],
                          size: 16, color: statusInfo['color']),
                      const SizedBox(width: 6),
                      Text(
                        statusInfo['text'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusInfo['color'],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey[200]),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.forum_outlined,
              'Interview Type',
              data['interviewType'] ?? '',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.person_outline,
              'Interviewer',
              data['interviewer'] ?? '',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.event_outlined,
              'Date',
              _prettyDate(data['date']),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.schedule_outlined,
              'Time',
              '${data['time'] ?? ''} (${data['duration'] ?? ''}m)',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.video_call_outlined,
              'Platform',
              data['platform'] ?? '',
            ),
            const SizedBox(height: 20),
            // Action Button
            Center(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: canJoin
                      ? const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  color: canJoin ? null : Colors.grey[100],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: canJoin ? () => onJoin(data) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            canJoin ? Icons.video_call : Icons.info_outline,
                            color: canJoin ? Colors.white : Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            canJoin ? 'Join Interview' : 'Join Interview',
                            style: TextStyle(
                              color: canJoin ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF3B82F6)),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  static Map<String, dynamic> _getStatusInfo(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return {
          'color': const Color(0xFF3B82F6),
          'bgColor': const Color(0xFFE0F2FE),
          'icon': Icons.schedule,
          'text': 'Scheduled',
        };
      case 'invited':
        return {
          'color': const Color(0xFF6366F1),
          'bgColor': const Color(0xFFEEF2FF),
          'icon': Icons.mail_outline,
          'text': 'Invited',
        };
      case 'confirmed':
        return {
          'color': const Color(0xFF10B981),
          'bgColor': const Color(0xFFD1FAE5),
          'icon': Icons.check_circle,
          'text': 'Confirmed',
        };
      case 'completed':
        return {
          'color': const Color(0xFF10B981),
          'bgColor': const Color(0xFFD1FAE5),
          'icon': Icons.check_circle,
          'text': 'Completed',
        };
      case 'cancelled':
        return {
          'color': const Color(0xFFEF4444),
          'bgColor': const Color(0xFFFEE2E2),
          'icon': Icons.cancel,
          'text': 'Cancelled',
        };
      case 'rescheduled':
        return {
          'color': const Color(0xFFF59E0B),
          'bgColor': const Color(0xFFFEF3C7),
          'icon': Icons.schedule,
          'text': 'Rescheduled',
        };
      default:
        return {
          'color': Colors.grey,
          'bgColor': Colors.grey[100]!,
          'icon': Icons.help_outline,
          'text': status,
        };
    }
  }

  static String _prettyDate(dynamic v) {
    DateTime dt;
    if (v is Timestamp)
      dt = v.toDate();
    else if (v is String) {
      try {
        dt = DateTime.parse(v);
      } catch (_) {
        return v;
      }
    } else {
      return '';
    }
    return DateFormat('EEE, MMM d, yyyy').format(dt);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "No Interviews Scheduled",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Upcoming interviews will appear here",
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
