
// lib/screens/InterviewManagementScreen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http; // For Zoom API
// NEW: Google Meet Imports
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:googleapis/gmail/v1.dart' as g; // For email

// NEW: Zoom Constants (Replace with your values; use env in production)
const String zoomAccountId =
    'dqZnFr_rT325_yqL4xTvBw'; // e.g., 'aBcDeFgHiJkLmNoP'
const String zoomClientId = 'MLcZrfN4TPKnbTL1h2qtSA'; // From App Credentials
const String zoomClientSecret =
    'm1QmL0cXIsiPUKNZRdv3tcVdJNuoGtNS'; // From App Credentials

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}

class InterviewManagementScreen extends StatefulWidget {
  const InterviewManagementScreen({Key? key}) : super(key: key);
  @override
  State<InterviewManagementScreen> createState() =>
      _InterviewManagementScreenState();
}

class _InterviewManagementScreenState extends State<InterviewManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _loading = true;
  String? _error;
  String? _recruiterId;
  String? _recruiterName = '';
  List<Map<String, String>> _accepted = [];
  List<Map<String, dynamic>> _scheduledInterviews = [];
  List<Map<String, String>> _jobs = [];
  List<Map<String, String>> _filteredCandidates = [];
  final _formKey = GlobalKey<FormState>();
  final _positionCtrl = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');
  final _meetingLinkCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCandidateId;
  String? _selectedJobId;
  String? _selectedJobTitle;
  String? _selectedPlatform;
  bool _autoGenerateLink = true;
  bool _addToCalendar = true;

  /// First item is our free fallback that can be truly auto-generated (Jitsi).
  final List<String> _platforms = const [
    'Smart Recruit Meet', // Jitsi (free) – shareable link without backend
    'Google Meet', // NEW: Shared event with API
    'Zoom', // opens app/web "start meeting"
  ];
  // NEW: Google Sign-In Helper (Account-specific for recruiter)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/calendar.events', // For calendar
      'https://www.googleapis.com/auth/gmail.send', // For email
    ],
  );
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _positionCtrl.dispose();
    _startTimeCtrl.dispose();
    _durationCtrl.dispose();
    _meetingLinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in.';
          _loading = false;
        });
        return;
      }
      _recruiterId = user.uid;
      // Recruiter name (from Firebase or Auth)
      String name = user.displayName ?? '';
      if (name.isEmpty) {
        final u = await _fs.collection('Users').doc(_recruiterId).get();
        final d = u.data();
        name = (d?['name'] ??
                d?['fullName'] ??
                d?['displayName'] ??
                user.email ??
                'Recruiter')
            .toString();
      }
      _recruiterName = name;
      await _loadAcceptedCandidates();
      await _loadScheduledInterviews();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadAcceptedCandidates() async {
    final jobsSnap = await _fs
        .collection('JobsPosted')
        .where('recruiterId', isEqualTo: _recruiterId)
        .get();
    final List<Map<String, String>> tempJobs = [];
    final List<Map<String, String>> tempAccepted = [];
    if (jobsSnap.docs.isNotEmpty) {
      for (final d in jobsSnap.docs) {
        final jobId = d.id;
        final jobTitle = (d.data()['title'] ?? 'Job').toString();
        tempJobs.add({
          'id': jobId,
          'title': jobTitle,
        });
      }
      final jobIds = tempJobs.map((j) => j['id']!).toList();
      for (int i = 0; i < jobIds.length; i += 10) {
        final chunk = jobIds.sublist(
            i, (i + 10 > jobIds.length) ? jobIds.length : i + 10);
        final appsSnap = await _fs
            .collection('AppliedCandidates')
            .where('status', isEqualTo: 'shortlisted')
            .where('jobId', whereIn: chunk)
            .get();
        for (final app in appsSnap.docs) {
          final data = app.data();
          final candidateId = (data['candidateId'] ?? '').toString();
          final jobId = (data['jobId'] ?? '').toString();
          if (candidateId.isEmpty || jobId.isEmpty) continue;
          String candidateName =
              (data['name'] ?? data['applicantName'] ?? '').toString();
          if (candidateName.isEmpty) {
            final prof = await _fs
                .collection('JobSeekersProfiles')
                .doc(candidateId)
                .get();
            final p = prof.data();
            candidateName = (p?['name'] ??
                    p?['fullName'] ??
                    p?['displayName'] ??
                    'Unnamed Candidate')
                .toString();
          }
          tempAccepted.add({
            'applicationId': app.id,
            'candidateId': candidateId,
            'candidateName': candidateName,
            'jobId': jobId,
            'jobTitle':
                tempJobs.firstWhere((j) => j['id'] == jobId)['title'] ?? 'Job',
          });
        }
      }
    }
    tempAccepted.sort((a, b) =>
        (a['candidateName'] ?? '').compareTo(b['candidateName'] ?? ''));
    tempJobs.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
    setState(() {
      _jobs = tempJobs;
      _accepted = tempAccepted;
      _filteredCandidates = [];
    });
  }

  Future<void> _loadScheduledInterviews() async {
    try {
      final querySnapshot = await _fs
          .collection('ScheduledInterviews')
          .where('recruiterId', isEqualTo: _recruiterId)
          .orderBy('date')
          .orderBy('time')
          .get();
      final interviews = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'candidateId': data['candidateId'] ?? '',
          'candidateName': data['candidateName'] ?? 'Candidate',
          'position': data['position'] ?? 'Position',
          'interviewer': data['interviewer'] ?? 'Interviewer',
          'date': data['date'] ?? '',
          'time': data['time'] ?? '',
          'duration': data['duration']?.toString() ?? '0',
          'platform': data['platform'] ?? 'Platform',
          'meetingLink': data['meetingLink'] ?? '',
          'status': data['status'] ?? 'Scheduled',
          'candidateEmail': data['candidateEmail'] ?? '',
          'calendarEventId': data['calendarEventId'] ?? '',
          'jobId': data['jobId'] ?? '',
        };
      }).toList();
      setState(() => _scheduledInterviews = interviews);
    } catch (_) {}
  }

  // =========================
  // MEETING LINK HELPERS
  // =========================
  // NEW: Google API Helper (Account-specific for recruiter)
  Future<gcal.CalendarApi?> _getCalendarApi() async {
    try {
      // Sign in with recruiter's account (prompt if needed)
      final account =
          await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
      if (account == null) return null;
      final authHeaders = await account.authHeaders;
      final authenticatedClient = GoogleAuthClient(authHeaders);
      return gcal.CalendarApi(authenticatedClient);
    } catch (e) {
      print('Google Auth Error: $e');
      return null;
    }
  }

  // UPDATED: Send Email only to Candidate from Recruiter's Account (No Self-Email)
  Future<void> _sendEmailInvitation({
    required String recruiterEmail,
    required String candidateEmail,
    required String meetLink,
    required String title,
    required DateTime startTime,
    required int durationMins,
    required String platform, // NEW: Include platform in email
  }) async {
    // Check if candidate email is valid (not empty)
    if (candidateEmail.isEmpty) {
      print(
          'Skipping email—candidate email missing. Update AppliedCandidates profile.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Candidate email missing—update AppliedCandidates profile to send invite'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    final gmailApi = await _getGmailApi();
    if (gmailApi == null) return;
    final subject = 'Interview Invitation: $title';
    final formattedTime = DateFormat('h:mm a').format(startTime);
    final body = '''
Hi,
You have an interview scheduled with $_recruiterName for $title.
Date: ${DateFormat('EEEE, MMM d, yyyy').format(startTime)}
Time: $formattedTime
Duration: $durationMins minutes
Platform: $platform
Join here: $meetLink
Best,
$_recruiterName
  ''';
    try {
      final message = g.Message()
        ..raw = _encodeEmail(recruiterEmail, candidateEmail, subject,
            body); // From recruiter to candidate only
      await gmailApi.users.messages
          .send(message, 'me'); // 'me' = recruiter's account, to candidate only
      print(
          'Email sent from $recruiterEmail to $candidateEmail (No email to recruiter)');
    } catch (e) {
      print('Email sending error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper for Gmail API (Recruiter's token)
  Future<g.GmailApi?> _getGmailApi() async {
    try {
      // Try silent sign-in first
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      // If no silent session, prompt user to sign in
      if (account == null) {
        account = await _googleSignIn.signIn();
      }
      // If user cancelled sign-in
      if (account == null) {
        print('User cancelled Gmail sign-in');
        return null;
      }
      // Get authentication headers
      final authHeaders = await account.authHeaders;
      // Create authenticated HTTP client
      final authenticatedClient = GoogleAuthClient(authHeaders);
      return g.GmailApi(authenticatedClient);
    } catch (e) {
      print('Gmail Auth Error: $e');
      return null;
    }
  }

  // Email Encode Helper
  String _encodeEmail(String from, String to, String subject, String body) {
    final message = 'From: $from\r\nTo: $to\r\nSubject: $subject\r\n\r\n$body';
    final bytes = utf8.encode(message);
    final encoded =
        base64Url.encode(bytes).replaceAll('+', '-').replaceAll('/', '_');
    return encoded;
  }

  // UPDATED: Generic Calendar Event Creator (Complete Event with Guest on Schedule, No Notifications)
  // Returns Map with 'eventId' and 'meetLink' (for Google Meet)
  Future<Map<String, dynamic>?> createCalendarEvent({
    required String recruiterEmail,
    required String candidateEmail,
    required DateTime startTime,
    required String title,
    required int durationMins,
    required String platform,
    String? meetingLink,
    bool forcePlain = false,
  }) async {
    final api = await _getCalendarApi();
    if (api == null) {
      print('API null—check sign-in');
      return null;
    }
    // CRITICAL FIX: RFC3339 format with +05:00 offset (Pakistan Time)
    String formatWithOffset(DateTime dt) {
      final year = dt.year.toString().padLeft(4, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      return '$year-$month-${day}T$hour:$minute:$second+05:00';
    }

    final localStartTime = startTime;
    final localEndTime = localStartTime.add(Duration(minutes: durationMins));
    final startTimeStr = formatWithOffset(localStartTime);
    final endTimeStr = formatWithOffset(localEndTime);
    print(
        'Creating Complete Calendar event for $platform (with guest, no notifications):');
    print('Start: $startTimeStr (PKT)');
    print('End: $endTimeStr (PKT)');
    print('Organizer: $recruiterEmail');
    print('Guest: $candidateEmail');
    // Base Event (always in recruiter's calendar, with candidate as guest)
    final event = gcal.Event()
      ..summary = title
      ..description =
          'Interview: $title\nCandidate: $candidateEmail\nRecruiter: $recruiterEmail\n\n'
      ..organizer = (gcal.EventOrganizer()..email = recruiterEmail)
      ..attendees = [
        gcal.EventAttendee()
          ..email = candidateEmail
          ..responseStatus =
              'needsAction', // Guest added, but no invite sent yet
      ];
    event
      ..start = (gcal.EventDateTime()
        ..dateTime = DateTime.parse(startTimeStr)
        ..timeZone = 'Asia/Karachi')
      ..end = (gcal.EventDateTime()
        ..dateTime = DateTime.parse(endTimeStr)
        ..timeZone = 'Asia/Karachi');
    final bool isMeet = platform == 'Google Meet' && !forcePlain;
    String? meetLinkResult;
    int? conferenceVersion;
    if (isMeet) {
      event.conferenceData = (gcal.ConferenceData()
        ..createRequest = (gcal.CreateConferenceRequest()
          ..requestId = 'interview-${DateTime.now().millisecondsSinceEpoch}'
          ..conferenceSolutionKey =
              (gcal.ConferenceSolutionKey()..type = 'hangoutsMeet')));
      conferenceVersion = 1;
    } else {
      // Null-Safe Description Building
      String desc = event.description ?? ''; // Ensure non-null base
      if (meetingLink != null && meetingLink.isNotEmpty) {
        desc += 'Join $platform: $meetingLink\n';
      }
      desc += 'Platform: $platform';
      event.description = desc;
    }
    try {
      final createdEvent = await api.events.insert(
        event,
        'primary',
        conferenceDataVersion: conferenceVersion,
        sendUpdates: 'all', // Send invitation to attendee upon creation
      );
      meetLinkResult = isMeet ? createdEvent.hangoutLink : null;
      print(
          '✅ Calendar Event Created (with guest): Event ID ${createdEvent.id}');
      if (isMeet) {
        print('Meet Link: $meetLinkResult');
      } else {
        print('Description includes: $platform link - $meetingLink');
      }
      return {
        'eventId': createdEvent.id,
        'meetLink': meetLinkResult,
      };
    } catch (e) {
      print('Error creating calendar event: $e');
      if (isMeet) {
        // Fallback retry with email (recruiterEmail as calendar)
        try {
          final retryEvent = await api.events.insert(
            event,
            recruiterEmail,
            conferenceDataVersion: 1,
            sendUpdates: 'all',
          );
          meetLinkResult = retryEvent.hangoutLink;
          print('Retry successful: ${retryEvent.hangoutLink}');
          return {
            'eventId': retryEvent.id,
            'meetLink': meetLinkResult,
          };
        } catch (retryError) {
          print('Retry failed: $retryError');
          return null;
        }
      }
      return null;
    }
  }

  // NEW: Zoom Access Token Generator (Server-to-Server OAuth)
  // Updated function (BasicAuth hata diya)
  Future<String> _generateZoomAccessToken() async {
    // Manual Basic Auth: username:password ko base64 mein encode
    final credentials =
        base64Encode(utf8.encode('$zoomClientId:$zoomClientSecret'));
    final authHeader = 'Basic $credentials';
    final response = await http.post(
      Uri.parse('https://zoom.us/oauth/token'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': authHeader, // Manual header yahan add
      },
      body: {
        'grant_type': 'account_credentials',
        'account_id': zoomAccountId,
      }
          .entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&'),
      // auth: http.BasicAuth(...) // <-- Yeh line hata do
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      print('Zoom Token Error: ${response.body}');
      throw Exception('Failed to get Zoom access token. Check credentials.');
    }
  }

  // NEW: Create Shared Zoom Meeting
  Future<String?> _createZoomMeeting({
    required String topic,
    required DateTime startTime,
    required int durationMins,
    String? candidateEmail,
  }) async {
    final token = await _generateZoomAccessToken();
    final apiUrl = 'https://api.zoom.us/v2/users/me/meetings';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'topic': topic,
        'type': 2, // Scheduled meeting
        'start_time': startTime.toUtc().toIso8601String(),
        'duration': durationMins,
        'timezone': 'UTC',
        'settings': {
          'host_video': true,
          'participant_video': true,
          'join_before_host': true, // <-- UPDATED: Allow early join
          'approval_type': 0, // Open to all
          'waiting_room':
              false, // <-- NEW: Disable waiting room for quick start
          'password': 'interview123', // <-- OPTIONAL: Add password for security
        },
      }),
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final joinUrl = data['join_url']; // Shared link
      print('Zoom Meeting Created: $joinUrl (Password: interview123 if set)');
      if (candidateEmail != null) {
        await _addZoomRegistrant(
            meetingId: data['id'].toString(),
            email: candidateEmail,
            token: token);
      }
      return joinUrl;
    } else {
      print('Zoom Error: ${response.body}');
      return null;
    }
  }

  // NEW: Helper to Add Registrant (Optional)
  Future<void> _addZoomRegistrant({
    required String meetingId,
    required String email,
    required String token,
  }) async {
    final url = 'https://api.zoom.us/v2/meetings/$meetingId/registrants';
    await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'email': email}),
    );
  }

  // real auto-link only for Jitsi (no backend)
  String _generateJitsiLink({
    required String recruiterId,
    required String candidateId,
    required DateTime start,
  }) {
    final raw =
        '$recruiterId|$candidateId|${start.toUtc().millisecondsSinceEpoch}';
    final slug = base64UrlEncode(utf8.encode(raw))
        .replaceAll('=', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .toLowerCase()
        .substring(0, 12);
    return 'https://meet.jit.si/smartrecruit-$slug';
  }

  /// Optional helper (not required by the new opener but kept for clarity)
  (String app, String web) _platformStartUrls(String platform) {
    switch (platform) {
      case 'Google Meet':
        return ('https://meet.google.com/new', 'https://meet.google.com/new');
      case 'Zoom':
        return ('zoomus://zoom.us/start', 'https://zoom.us/start/videomeeting');
      default:
        return ('', '');
    }
  }

  /// OPENER with Google Meet intent:// fix + robust fallbacks
  Future<void> _openPlatformStart(String platform, String? savedLink) async {
    String _sanitizeMeetIntent(String url) {
      // Example: intent://meet.app.goo.gl/?link=https://meet.google.com/new&apn=...
      if (url.startsWith('intent://')) {
        final idx = url.indexOf('link=');
        if (idx != -1) {
          final enc = url.substring(idx + 5);
          final cut =
              enc.contains('&') ? enc.substring(0, enc.indexOf('&')) : enc;
          try {
            return Uri.decodeFull(cut);
          } catch (_) {
            return cut;
          }
        }
      }
      return url;
    }

    Future<bool> _tryLaunch(
      String url, {
      LaunchMode mode = LaunchMode.externalApplication,
    }) async {
      try {
        final uri = Uri.parse(url);
        return await launchUrl(uri, mode: mode);
      } catch (_) {
        return false;
      }
    }

    // 1) If we have a concrete link already (Jitsi or pasted), open it first
    String link = (savedLink ?? '').trim();
    if (link.startsWith('intent://')) {
      link = _sanitizeMeetIntent(link);
    }
    if (link.startsWith('http')) {
      if (await _tryLaunch(link)) return;
    }
    // 2) Resolve platform → we use multiple fallbacks for Google Meet
    (String app, List<String> webList) urls(String p) {
      switch (p) {
        case 'Google Meet':
          return (
            '',
            <String>[
              'https://meet.google.com/new?pli=1',
              'https://meet.google.com/?hs=197',
              'https://meet.google.com/'
            ]
          );
        case 'Zoom':
          return (
            'zoomus://zoom.us/start',
            <String>['https://zoom.us/start/videomeeting']
          );
        default:
          return ('', <String>[]);
      }
    }

    final (app, webList) = urls(platform);
    // 3) Google Meet → external browser/app first; then in-app as last resort
    if (platform == 'Google Meet') {
      for (final u in webList) {
        if (await _tryLaunch(u, mode: LaunchMode.externalApplication)) return;
      }
      for (final u in webList) {
        if (await _tryLaunch(u, mode: LaunchMode.inAppWebView)) return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open Google Meet')),
        );
      }
      return;
    }
    // 4) Others: app deep-link → web fallback
    if (app.isNotEmpty) {
      if (await _tryLaunch(app)) return;
    }
    for (final u in webList) {
      if (await _tryLaunch(u)) return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot open $platform')),
      );
    }
  }

  // =========================
  // SCHEDULE INTERVIEW
  // =========================
  Future<void> _scheduleInterview() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      setState(() => _loading = true);
      final selectedCandidate = _filteredCandidates.firstWhere(
        (e) => e['candidateId'] == _selectedCandidateId,
        orElse: () => {},
      );
      // Fetch candidate email from profile
      // UPDATED: Fetch candidate email from AppliedCandidates 'applicantEmail' field (Query by candidateId and jobId)
      String candidateEmail = '';
      if (_selectedCandidateId != null && _selectedJobId != null) {
        final querySnapshot = await _fs
            .collection('AppliedCandidates')
            .where('candidateId', isEqualTo: _selectedCandidateId)
            .where('jobId', isEqualTo: _selectedJobId)
            .limit(1) // Only one matching doc needed
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          final appData = querySnapshot.docs.first.data();
          candidateEmail = (appData['applicantEmail'] ?? '').toString();
        }
        if (candidateEmail.isEmpty) {
          throw Exception('Candidate Email missing. Update profile first.');
        }
      }
      // Combine date + time for startTime (Fixed AM/PM)
      final timeParts = _startTimeCtrl.text.split(' ');
      final time24 = timeParts[0]; // e.g., '11:33'
      final amPm = timeParts.length > 1 ? timeParts[1] : 'AM'; // 'AM' or 'PM'
      int hour = int.parse(time24.split(':')[0]);
      final minute = int.parse(time24.split(':')[1]);
      if (amPm.toUpperCase() == 'PM' && hour != 12) hour += 12;
      if (amPm.toUpperCase() == 'AM' && hour == 12) hour = 0;
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
        minute,
      );
      // Decide meetingLink
      String link = _meetingLinkCtrl.text.trim();
      String? calendarEventId;
      final chosenPlatform = _selectedPlatform ?? 'Smart Recruit Meet';
      final interviewTitle = 'Interview: ${_selectedJobTitle ?? 'Position'}';
      final durationMins = int.tryParse(_durationCtrl.text) ?? 45;
      if (_autoGenerateLink) {
        switch (chosenPlatform) {
          case 'Smart Recruit Meet':
            link = _generateJitsiLink(
              recruiterId: _recruiterId ?? 'rec',
              candidateId: _selectedCandidateId ?? 'cand',
              start: startTime,
            );
            break;
          case 'Zoom':
            link = await _createZoomMeeting(
                  topic: interviewTitle,
                  startTime: startTime,
                  durationMins: durationMins,
                  candidateEmail:
                      candidateEmail.isNotEmpty ? candidateEmail : null,
                ) ??
                '';
            if (link.isEmpty) {
              throw Exception(
                  'Failed to create Zoom meeting. Check console for errors.');
            }
            break;
          case 'Google Meet':
            final result = await createCalendarEvent(
              recruiterEmail: _auth.currentUser?.email ?? '',
              candidateEmail: candidateEmail,
              startTime: startTime,
              title: interviewTitle,
              durationMins: durationMins,
              platform: chosenPlatform,
            );
            if (result == null) {
              throw Exception(
                  'Failed to create Google Meet—check console logs.');
            }
            link = result['meetLink'] ?? '';
            calendarEventId = result['eventId'];
            break;
        }
      }
      // Create calendar event for recruiter if _addToCalendar or already created for Meet
      if (_addToCalendar && calendarEventId == null) {
        final bool forcePlainEvent =
            (chosenPlatform == 'Google Meet' && !_autoGenerateLink);
        final result = await createCalendarEvent(
          recruiterEmail: _auth.currentUser?.email ?? '',
          candidateEmail: candidateEmail,
          startTime: startTime,
          title: '$interviewTitle ($chosenPlatform)',
          durationMins: durationMins,
          platform: chosenPlatform,
          forcePlain: forcePlainEvent,
          meetingLink: link,
        );
        if (result != null) {
          calendarEventId = result['eventId'];
        }
        print(
            'Complete calendar event created in recruiter\'s calendar (with guest, no notifications)');
      }
      // Automatic invite: Send email and calendar invite
      await _sendEmailInvitation(
        recruiterEmail: _auth.currentUser?.email ?? '',
        candidateEmail: candidateEmail,
        meetLink: link,
        title: interviewTitle,
        startTime: startTime,
        durationMins: durationMins,
        platform: chosenPlatform,
      );
      // NO EMAIL ON SCHEDULE! -> Now automatic
      final docRef = await _fs.collection('ScheduledInterviews').add({
        'candidateId': _selectedCandidateId,
        'candidateName': selectedCandidate['candidateName'] ?? 'Candidate',
        'jobId': _selectedJobId,
        'position': _selectedJobTitle,
        'interviewer': _recruiterName,
        'date': DateFormat('yyyy-MM-dd').format(startTime),
        'time': _startTimeCtrl.text,
        'duration': durationMins,
        'platform': chosenPlatform,
        'meetingLink': link,
        'autoGenerated': _autoGenerateLink,
        'status': 'Scheduled',
        'recruiterId': _recruiterId,
        'candidateEmail':
            candidateEmail, // NEW: Save for easy access in sendInvite
        'calendarEventId': calendarEventId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (selectedCandidate['applicationId'] != null) {
        await _fs
            .collection('AppliedCandidates')
            .doc(selectedCandidate['applicationId']!)
            .update({'status': 'interview_scheduled'});
      }
      // Update status to 'Invited'
      await _fs.collection('ScheduledInterviews').doc(docRef.id).update({
        'status': 'Invited',
        'sentToCandidateAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interview scheduled and invite sent to candidate!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadAcceptedCandidates();
      await _loadScheduledInterviews();
      _tabController.animateTo(1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> interview) async {
    final interviewId = interview['id'] as String?;
    final candidateId = interview['candidateId'] as String?;
    final jobId = interview['jobId'] as String?;
    if (interviewId == null || candidateId == null || jobId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing required data.')),
        );
      }
      return;
    }
    String? newStatus;
    await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        // Wrap in StatefulBuilder for local state
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Interview Status'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Interviewed'),
                  leading: Radio<String>(
                    value: 'interviewed',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setDialogState(
                          () => newStatus = value); // Use setDialogState
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Accepted'),
                  leading: Radio<String>(
                    value: 'accepted',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setDialogState(
                          () => newStatus = value); // Use setDialogState
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Rejected'),
                  leading: Radio<String>(
                    value: 'rejected',
                    groupValue: newStatus,
                    onChanged: (value) {
                      setDialogState(
                          () => newStatus = value); // Use setDialogState
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: newStatus != null
                  ? () => Navigator.pop(context, newStatus)
                  : null,
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    ).then((value) {
      newStatus = value;
    });
    if (newStatus == null) return;
    try {
      // Update ScheduledInterviews
      await _fs.collection('ScheduledInterviews').doc(interviewId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Update AppliedCandidates
      final appQuery = await _fs
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: candidateId)
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();
      if (appQuery.docs.isNotEmpty) {
        await _fs
            .collection('AppliedCandidates')
            .doc(appQuery.docs.first.id)
            .update({'status': newStatus});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadScheduledInterviews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _loading = true);
    await _loadData();
  }

  // ---------------- UI ---------------- (Same as original, removed Interview Type)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview Management'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Schedule Interview'),
            Tab(text: 'Scheduled Interviews'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildScheduleInterviewTab(context),
                    _buildScheduledInterviewsTab(),
                  ],
                ),
    );
  }

  Widget _buildScheduleInterviewTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // ---------- Job ----------
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BlockTitle('Select Job'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Job',
                        prefixIcon: Icon(Icons.work, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: _selectedJobId,
                      items: _jobs.map((j) {
                        final label = j['title'] ?? 'Job';
                        return DropdownMenuItem(
                          value: j['id'],
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Select a job' : null,
                      onChanged: (val) {
                        setState(() {
                          _selectedJobId = val;
                          _selectedJobTitle = _jobs.firstWhere(
                            (j) => j['id'] == val,
                            orElse: () => {'title': ''},
                          )['title'];
                          _positionCtrl.text = _selectedJobTitle ?? '';
                          _selectedCandidateId = null;
                          _filteredCandidates = _accepted
                              .where((c) => c['jobId'] == val)
                              .toList();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ---------- Candidate ----------
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BlockTitle('Candidate Information'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Candidate',
                        prefixIcon: Icon(Icons.person, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: _selectedCandidateId,
                      items: _filteredCandidates.map((c) {
                        final label = '${c['candidateName']}';
                        return DropdownMenuItem(
                          value: c['candidateId'],
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Select a candidate'
                          : null,
                      onChanged: (val) {
                        setState(() {
                          _selectedCandidateId = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ---------- Interview details ---------- (REMOVED Interview Type)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BlockTitle('Interview Details'),
                    const SizedBox(height: 16),
                    // REMOVED: Interview Type dropdown
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Interviewer',
                        prefixIcon: Icon(Icons.people, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      controller:
                          TextEditingController(text: _recruiterName ?? ''),
                      readOnly: true,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 120)),
                        );
                        if (picked != null)
                          setState(() => _selectedDate = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Interview Date',
                          prefixIcon: Icon(Icons.calendar_today,
                              color: Colors.blue[800]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        child: Text(DateFormat('EEEE, MMM d, yyyy')
                            .format(_selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startTimeCtrl,
                            readOnly: true, // Prevent manual keyboard input
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              prefixIcon: Icon(Icons.access_time,
                                  color: Colors.blue[800]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? 'Enter time' : null,
                            onTap: () async {
                              // Calculate initial time based on selected date
                              TimeOfDay initialTime;
                              final now = DateTime.now();
                              final isToday = _selectedDate.year == now.year &&
                                  _selectedDate.month == now.month &&
                                  _selectedDate.day == now.day;
                              if (isToday) {
                                initialTime = TimeOfDay.fromDateTime(
                                    now); // Start from current time if today
                              } else {
                                initialTime = const TimeOfDay(
                                    hour: 9,
                                    minute:
                                        0); // Default 9:00 AM for future dates
                              }

                              // Add time picker on tap
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: initialTime,
                              );
                              if (picked != null && mounted) {
                                // Validate: If today, ensure picked time is not in the past
                                if (isToday) {
                                  final currentTime =
                                      TimeOfDay.fromDateTime(now);
                                  if (picked.hour < currentTime.hour ||
                                      (picked.hour == currentTime.hour &&
                                          picked.minute < currentTime.minute)) {
                                    // Show error if past time selected for today
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Cannot select a past time for today. Please choose a future time.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return; // Don't update the controller
                                  }
                                }
                                setState(() {
                                  _startTimeCtrl.text = picked.format(
                                      context); // Formats as "h:mm a" (e.g., "10:00 AM")
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _durationCtrl,
                            decoration: InputDecoration(
                              labelText: 'Duration (min)',
                              prefixIcon:
                                  Icon(Icons.timer, color: Colors.blue[800]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (v) => (v == null || v.isEmpty)
                                ? 'Enter minutes'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ---------- Meeting platform ---------- (Same)
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BlockTitle('Meeting Platform'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Platform',
                        prefixIcon:
                            Icon(Icons.video_call, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: _selectedPlatform,
                      items: _platforms
                          .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Select platform' : null,
                      onChanged: (v) => setState(() => _selectedPlatform = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _meetingLinkCtrl,
                      decoration: InputDecoration(
                        labelText: 'Meeting Link (optional)',
                        helperText: 'Leave empty or enable Auto-generate',
                        prefixIcon: Icon(Icons.link, color: Colors.blue[800]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-generate meeting link'),
                      value: _autoGenerateLink,
                      onChanged: (v) => setState(() => _autoGenerateLink = v),
                      activeColor: Colors.blue[800],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Add to calendar'),
                      value: _addToCalendar,
                      onChanged: (v) => setState(() => _addToCalendar = v),
                      activeColor: Colors.blue[800],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _jobs.isEmpty || _filteredCandidates.isEmpty
                            ? null
                            : _scheduleInterview,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Schedule Interview',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_jobs.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _InfoChip(
                  icon: Icons.info_outline,
                  text: 'No jobs found. Post a job first.',
                ),
              ),
            if (_selectedJobId != null && _filteredCandidates.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: _InfoChip(
                  icon: Icons.info_outline,
                  text:
                      'No shortlisted candidates found for this job. Update status to shortlisted first.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledInterviewsTab() {
    if (_scheduledInterviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No interviews scheduled yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Schedule an interview to see it here',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _loadScheduledInterviews,
                child: const Text('Refresh')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadScheduledInterviews,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _scheduledInterviews.length,
        itemBuilder: (context, index) {
          final interview = _scheduledInterviews[index];
          return _buildInterviewCard(interview);
        },
      ),
    );
  }

  Widget _buildInterviewCard(Map<String, dynamic> interview) {
    final status = (interview['status'] ?? 'Scheduled').toString();
    final meetingLink = (interview['meetingLink'] ?? '').toString();
    final isUpdatable = status == 'Invited';
    Color statusColor = Colors.blue[800]!;
    if (status == 'interviewed')
      statusColor = Colors.orange[800]!;
    else if (status == 'accepted')
      statusColor = Colors.green[800]!;
    else if (status == 'rejected') statusColor = Colors.red[800]!;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue[50], shape: BoxShape.circle),
                  child:
                      Icon(Icons.videocam, color: Colors.blue[800], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(interview['candidateName'] ?? 'Candidate',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        '${interview['position']} Interview',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${interview['date']} at ${interview['time']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: status == 'Invited'
                        ? Colors.green[50]
                        : (status == 'interviewed'
                            ? Colors.orange[50]
                            : (status == 'accepted'
                                ? Colors.green[50]
                                : Colors.red[50])),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(isUpdatable ? Icons.update : Icons.info),
                    label:
                        Text(isUpdatable ? 'Update Status' : 'Update Status'),
                    onPressed:
                        isUpdatable ? () => _updateStatus(interview) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[800],
                      side: BorderSide(color: Colors.blue[800]!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_call),
                    label: const Text('Join Meeting'),
                    onPressed: meetingLink.isNotEmpty
                        ? () => _openPlatformStart(
                              interview['platform'] ?? 'Smart Recruit Meet',
                              interview['meetingLink'] ?? '',
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- little helpers ---------- (Same)
class _BlockTitle extends StatelessWidget {
  final String text;
  const _BlockTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[800]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: const TextStyle(color: Colors.orange))),
      ],
    );
  }
}
