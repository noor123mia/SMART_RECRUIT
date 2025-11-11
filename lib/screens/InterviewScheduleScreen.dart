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

  String _prettyDate(dynamic v) {
    final dt = _parseDate(v);
    return DateFormat('EEE, MMM d, yyyy').format(dt);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    final title = 'My Interviews'; // Always for candidate
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : _items.isEmpty
                  ? _EmptyState(
                      isRecruiter: false) // Always candidate empty state
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _InterviewCard(
                          data: _items[i],
                          isRecruiter: false, // Always candidate view
                          onJoin: _join,
                        ),
                      ),
                    ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isRecruiter; // Ignored now, but kept for compatibility
  final Future<void> Function(Map<String, dynamic>) onJoin;

  const _InterviewCard({
    Key? key,
    required this.data,
    required this.isRecruiter,
    required this.onJoin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? 'Scheduled').toString();
    final statusColor = _statusColor(status);
    final meetingLink = (data['meetingLink'] ?? '').toString();
    final platform = (data['platform'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(.25), width: 1.3),
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: recruiter name + status chip (candidate view)
            Row(
              children: [
                Expanded(
                  child: Text(
                    (data['recruiterName'] ??
                        'Recruiter'), // Show recruiter for candidate
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(.25)),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Detail rows
            _InfoRow(
                icon: Icons.work_outline,
                label: 'Position',
                value: data['position'] ?? ''),
            _InfoRow(
                icon: Icons.forum_outlined,
                label: 'Type',
                value: data['interviewType'] ?? ''),
            _InfoRow(
                icon: Icons.person_outline,
                label: 'Interviewer',
                value: data['interviewer'] ?? ''),
            _InfoRow(
                icon: Icons.event_outlined,
                label: 'Date',
                value: _prettyDate(data['date'])),
            _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Time',
                value: '${data['time'] ?? ''} (${data['duration'] ?? ''}m)'),
            _InfoRow(
                icon: Icons.video_call_outlined,
                label: 'Platform',
                value: data['platform'] ?? ''),
            if (meetingLink.isNotEmpty)
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Opening: $meetingLink')));
                },
                child: _InfoRow(
                    icon: Icons.link,
                    label: 'Meeting',
                    value: meetingLink,
                    isLink: true),
              ),

            const SizedBox(height: 12),

            // Actions - Candidate can only join if scheduled/invited/confirmed
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (meetingLink.isNotEmpty &&
                    platform.toLowerCase() != 'platform' &&
                    (status.toLowerCase() == 'scheduled' ||
                        status.toLowerCase() == 'invited' ||
                        status.toLowerCase() == 'confirmed'))
                  ElevatedButton.icon(
                    onPressed: () => onJoin(data),
                    icon: const Icon(Icons.video_call),
                    label: const Text('Join Interview'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'invited':
        return Colors.indigo;
      case 'confirmed':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
        return Colors.orange;
      default:
        return Colors.grey;
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLink;
  const _InfoRow(
      {Key? key,
      required this.icon,
      required this.label,
      required this.value,
      this.isLink = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text('$label: ', style: style?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: style?.copyWith(
                color: isLink ? Colors.indigo : Colors.black87,
                decoration:
                    isLink ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isRecruiter;
  const _EmptyState({Key? key, required this.isRecruiter}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = 'No interviews assigned to you'; // Candidate-specific
    final sub = 'When a recruiter invites you, it will show here.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
