import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:googleapis/gmail/v1.dart' as g;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

// Custom HTTP client for Google APIs authentication
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(String accessToken)
      : _headers = {
          'Authorization': 'Bearer $accessToken',
          'X-Goog-AuthUser': '0',
        };
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
  }
}

class JobSeekerOffersScreen extends StatefulWidget {
  const JobSeekerOffersScreen({Key? key}) : super(key: key);

  @override
  _JobSeekerOffersScreenState createState() => _JobSeekerOffersScreenState();
}

class _JobSeekerOffersScreenState extends State<JobSeekerOffersScreen> {
  String? candidateId;
  final GoogleSignIn _googleSignIn =
      GoogleSignIn(scopes: ['https://www.googleapis.com/auth/gmail.send']);
  g.GmailApi? _gmailApi;

  @override
  void initState() {
    super.initState();
    _initializeCandidateId();
    _initializeGmail();
  }

  void _initializeCandidateId() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      candidateId = user.uid;
    } else {
      // Handle unauthenticated user, e.g., redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view offers')),
        );
        // Optionally: Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  Future<void> _initializeGmail() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) {
        // Don't force sign-in here, wait until actually sending email
        return;
      }
      final authentication = await account.authentication;
      final httpClient = GoogleAuthClient(authentication.accessToken!);
      _gmailApi = g.GmailApi(httpClient);
    } catch (e) {
      developer.log('Gmail init error: $e');
    }
  }

  Future<String> _getCandidateEmail(String candidateId) async {
    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('JobSeekersProfiles')
          .doc(candidateId)
          .get();
      return profileDoc.data()?['email'] ?? '';
    } catch (e) {
      developer.log('Error fetching candidate email: $e');
      return '';
    }
  }

  String _encodeEmail(String from, String to, String subject, String body) {
    const charset = 'UTF-8';
    final fromEncoded = '=?$charset?B?${base64Encode(utf8.encode(from))}?=';
    final subjectEncoded =
        '=?$charset?B?${base64Encode(utf8.encode(subject))}?=';
    final message = 'From: $fromEncoded\r\n'
        'To: $to\r\n'
        'Subject: $subjectEncoded\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: text/html; charset="$charset"\r\n'
        '\r\n'
        '$body';
    return base64
        .encode(utf8.encode(message))
        .replaceAll('+', '-')
        .replaceAll('/', '_')
        .replaceAll('=', '');
  }

  Future<String> _getRecruiterEmail(String recruiterId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recruiterId)
          .get();
      return userDoc.data()?['email'] ?? '';
    } catch (e) {
      developer.log('Error fetching recruiter email: $e');
      return '';
    }
  }

  Future<void> _notifyRecruiter({
    required String recruiterEmail,
    required String candidateName,
    required String candidateEmail,
    required String jobTitle,
    required String action, // 'rejected' or 'expired'
    required String offerId,
  }) async {
    if (recruiterEmail.isEmpty) {
      developer.log('Skipping notification—recruiter email missing.');
      return;
    }
    // Sign in if not already signed in
    if (_gmailApi == null) {
      try {
        final account = await _googleSignIn.signIn();
        if (account != null) {
          final authentication = await account.authentication;
          final httpClient = GoogleAuthClient(authentication.accessToken!);
          _gmailApi = g.GmailApi(httpClient);
        }
      } catch (e) {
        developer.log('Gmail sign-in error: $e');
        return;
      }
    }
    if (_gmailApi == null) {
      developer.log('Gmail API not initialized.');
      return;
    }
    String subject;
    String body;
    if (action == 'rejected') {
      subject = 'Candidate Rejected Offer: $jobTitle';
      body = '''
<p>Dear Recruiter,</p>
<p>The candidate <strong>$candidateName</strong> ($candidateEmail) has rejected the offer for <strong>$jobTitle</strong> (Offer ID: $offerId).</p>
<p><strong>Suggestions:</strong></p>
<ul>
  <li>Choose the next pending candidate from the Candidate Pool.</li>
  <li>Start an In-App Chat with $candidateName to discuss further.</li>
</ul>
<p>Best regards,<br>Smart Recruit App</p>
      ''';
    } else {
      // expired
      subject = 'Offer Expired for $jobTitle';
      body = '''
<p>Dear Recruiter,</p>
<p>The offer for <strong>$candidateName</strong> ($candidateEmail) for <strong>$jobTitle</strong> (Offer ID: $offerId) has expired without response.</p>
<p><strong>Suggestions:</strong></p>
<ul>
  <li>Choose the next pending candidate from the Candidate Pool.</li>
  <li>Start an In-App Chat with $candidateName to discuss further.</li>
</ul>
<p>Best regards,<br>Smart Recruit App</p>
      ''';
    }
    try {
      final message = g.Message()
        ..raw = _encodeEmail('Smart Recruit App <no-reply@smartrecruit.com>',
            recruiterEmail, subject, body);
      await _gmailApi!.users.messages.send(message, 'me');
      developer.log('Notification email sent to $recruiterEmail');
    } catch (e) {
      developer.log('Notification email sending error: $e');
    }
  }

  Future<void> _updateAppliedCandidatesStatus(String offerId, String action) async {
    try {
      final offerDoc = await FirebaseFirestore.instance
          .collection('OfferLetters')
          .doc(offerId)
          .get();
      if (!offerDoc.exists) return;
      final offer = offerDoc.data()!;
      final candidateId = offer['candidateId'];
      final jobId = offer['jobId'];
      final status = action == 'accepted' ? 'OfferAccepted' : 'OfferRejected';

      final appliedQuery = await FirebaseFirestore.instance
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: candidateId)
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();

      if (appliedQuery.docs.isNotEmpty) {
        await appliedQuery.docs.first.reference.update({'status': status});
        developer.log('Updated AppliedCandidates status to $status for candidate $candidateId, job $jobId');
      }
    } catch (e) {
      developer.log('Error updating AppliedCandidates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (candidateId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Offer Letters',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF1D4ED8)
              ], // Changed to blue gradient
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('OfferLetters')
            .where('candidateId', isEqualTo: candidateId)
            .orderBy('sentAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading offers: ${snapshot.error}',
                    style: TextStyle(color: Colors.red[600], fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}), // Retry
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)), // Blue
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1), // Blue
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "No Offer Letters Yet",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your offer letters will appear here",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          var offers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              var offer = offers[index].data() as Map<String, dynamic>;
              var offerId = offers[index].id;
              String status = offer['status'] ?? 'sent';

              // Check for expiration and auto-update if necessary
              dynamic deadlineRaw = offer['acceptanceDeadline'];
              DateTime? deadline;
              bool isExpired = false;
              if (deadlineRaw != null && status == 'sent') {
                deadline = _parseDate(deadlineRaw);
                if (deadline != null &&
                    DateTime.now()
                        .isAfter(deadline.add(const Duration(days: 1)))) {
                  isExpired = true;
                  // Auto-update status to rejected
                  FirebaseFirestore.instance
                      .collection('OfferLetters')
                      .doc(offerId)
                      .update({
                    'status': 'rejected',
                    'respondedAt': FieldValue.serverTimestamp(),
                    'notificationSent':
                        true, // Flag to avoid duplicate notifications
                  }).then((_) async {
                    // Update AppliedCandidates for expired (treat as rejected)
                    await _updateAppliedCandidatesStatus(offerId, 'rejected');
                    // Send notification after update
                    final candidateEmail = await _getCandidateEmail(offer['candidateId']);
                    final recruiterEmail =
                        await _getRecruiterEmail(offer['recruiterId']);
                    await _notifyRecruiter(
                      recruiterEmail: recruiterEmail,
                      candidateName: offer['candidateName'],
                      candidateEmail: candidateEmail,
                      jobTitle: offer['jobTitle'],
                      action: 'expired',
                      offerId: offerId,
                    );
                  }).catchError((e) {
                    developer.log('Error updating expired offer: $e');
                  });
                  status = 'rejected';
                }
              }

              Color statusColor;
              Color statusBgColor;
              IconData statusIcon;
              String statusText;

              if (status == 'rejected' &&
                  deadline != null &&
                  DateTime.now()
                      .isAfter(deadline.add(const Duration(days: 1)))) {
                // Treat as expired for display
                statusColor = const Color(0xFFEF4444);
                statusBgColor = const Color(0xFFFEE2E2);
                statusIcon = Icons.access_time;
                statusText = 'Expired';
              } else {
                switch (status) {
                  case 'accepted':
                    statusColor = const Color(0xFF10B981);
                    statusBgColor = const Color(0xFFD1FAE5);
                    statusIcon = Icons.check_circle;
                    statusText = 'Accepted';
                    break;
                  case 'rejected':
                    statusColor = const Color(0xFFEF4444);
                    statusBgColor = const Color(0xFFFEE2E2);
                    statusIcon = Icons.cancel;
                    statusText = 'Rejected';
                    break;
                  default:
                    statusColor = const Color(0xFFF59E0B);
                    statusBgColor = const Color(0xFFFEF3C7);
                    statusIcon = Icons.schedule;
                    statusText = 'Pending';
                }
              }

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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () =>
                        _showOfferDetails(context, offer, offerId, status),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF1D4ED8)
                                    ], // Blue
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.business_center,
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
                                      offer['companyName'] ?? 'Company',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      offer['jobTitle'] ?? 'Position',
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
                                  color: statusBgColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon,
                                        size: 16, color: statusColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
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
                            Icons.calendar_today_outlined,
                            'Start Date',
                            offer['startDate'] ?? 'N/A',
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            Icons.access_time_outlined,
                            'Received',
                            _formatDate(offer['sentAt']),
                          ),
                          if (deadlineRaw != null) ...[
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.alarm_outlined,
                              'Deadline',
                              _formatDate(deadlineRaw),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Center(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF3B82F6),
                                    Color(0xFF1D4ED8)
                                  ], // Blue
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _showOfferDetails(
                                      context, offer, offerId, status),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.open_in_new,
                                            color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'View Details',
                                          style: TextStyle(
                                            color: Colors.white,
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
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF3B82F6)), // Blue
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

  DateTime? _parseDate(dynamic dateRaw) {
    if (dateRaw == null) return null;
    try {
      if (dateRaw is Timestamp) {
        return dateRaw.toDate();
      } else if (dateRaw is String) {
        // Parse string in format like "November 24, 2025"
        final parser = DateFormat('MMMM dd, yyyy', 'en_US');
        return parser.parse(dateRaw);
      }
      return null;
    } catch (e) {
      developer.log('Error parsing date: $e, raw: $dateRaw');
      return null;
    }
  }

  String _formatDate(dynamic dateRaw) {
    final parsed = _parseDate(dateRaw);
    if (parsed == null) return 'N/A';
    try {
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _openPDF(String? pdfUrl) async {
    if (pdfUrl == null || pdfUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      developer.log('Public URL: $pdfUrl'); // Log URL for debugging
      final uri = Uri.parse(pdfUrl);
      // Directly launch without canLaunchUrl check
      await launchUrl(
        uri,
        mode: LaunchMode
            .externalApplication, // Or try LaunchMode.platformDefault if needed
      );
    } on PlatformException catch (e) {
      // Specific exception catch for url_launcher
      developer.log('Failed to open PDF: $e');
      // Copy URL to clipboard as fallback
      await Clipboard.setData(ClipboardData(text: pdfUrl));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot open PDF. Please ensure a browser or PDF viewer is installed. URL copied to clipboard.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOfferDetails(BuildContext context, Map<String, dynamic> offer,
      String offerId, String currentStatus) async {
    // Check for expiration and auto-update if necessary
    dynamic deadlineRaw = offer['acceptanceDeadline'];
    bool isExpired = false;
    DateTime? deadline = _parseDate(deadlineRaw);
    if (deadline != null && currentStatus == 'sent') {
      if (DateTime.now().isAfter(deadline.add(const Duration(days: 1)))) {
        isExpired = true;
        // Auto-update status to rejected
        await FirebaseFirestore.instance
            .collection('OfferLetters')
            .doc(offerId)
            .update({
          'status': 'rejected',
          'respondedAt': FieldValue.serverTimestamp(),
          'notificationSent': true, // Flag to avoid duplicate notifications
        });
        // Update AppliedCandidates for expired (treat as rejected)
        await _updateAppliedCandidatesStatus(offerId, 'rejected');
        // Send notification after update
        final candidateEmail = await _getCandidateEmail(offer['candidateId']);
        final recruiterEmail = await _getRecruiterEmail(offer['recruiterId']);
        await _notifyRecruiter(
          recruiterEmail: recruiterEmail,
          candidateName: offer['candidateName'],
          candidateEmail: candidateEmail,
          jobTitle: offer['jobTitle'],
          action: 'expired',
          offerId: offerId,
        );
        currentStatus = 'rejected';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], // Blue
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.description,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer['companyName'] ?? 'Company',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          offer['jobTitle'] ?? 'Position',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(bottomSheetContext),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailSection('Position Details', [
                      _buildDetailItem('Job Title', offer['jobTitle'] ?? 'N/A'),
                      _buildDetailItem('Location', offer['location'] ?? 'N/A'),
                      _buildDetailItem(
                          'Start Date', offer['startDate'] ?? 'N/A'),
                      if (deadlineRaw != null)
                        _buildDetailItem(
                            'Acceptance Deadline', _formatDate(deadlineRaw)),
                    ]),
                    const SizedBox(height: 24),
                    _buildDetailSection('Compensation', [
                      _buildDetailItem(
                          'Salary Package', offer['salary'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 24),
                    if (offer['probationPeriod'] != null &&
                        offer['probationPeriod'].toString().isNotEmpty)
                      Column(
                        children: [
                          _buildDetailSection('Employment Terms', [
                            _buildDetailItem('Probation Period',
                                offer['probationPeriod'] ?? 'N/A'),
                            if (offer['noticePeriod'] != null &&
                                offer['noticePeriod'].toString().isNotEmpty)
                              _buildDetailItem('Notice Period',
                                  offer['noticePeriod'] ?? 'N/A'),
                          ]),
                          const SizedBox(height: 24),
                        ],
                      ),
                    _buildDetailSection('Document', [
                      InkWell(
                        onTap: () => _openPDF(offer['pdfUrl']),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6)
                                .withOpacity(0.1), // Blue
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF3B82F6)
                                  .withOpacity(0.3), // Blue
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6), // Blue
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Offer Letter PDF',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tap to open',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF3B82F6), // Blue
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 18,
                                color: Color(0xFF3B82F6), // Blue
                              ),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // Action Buttons or Status Message
            if (currentStatus == 'sent' && !isExpired)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleOfferResponse(
                            bottomSheetContext, offerId, 'rejected'),
                        icon: const Icon(Icons.cancel_outlined, size: 20),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(
                              color: Color(0xFFEF4444), width: 2),
                          foregroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _handleOfferResponse(
                                bottomSheetContext, offerId, 'accepted'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline,
                                      color: Colors.white, size: 22),
                                  SizedBox(width: 10),
                                  Text(
                                    'Accept Offer',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
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
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: currentStatus == 'accepted'
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        currentStatus == 'accepted'
                            ? Icons.check_circle
                            : (isExpired ? Icons.access_time : Icons.cancel),
                        color: currentStatus == 'accepted'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentStatus == 'accepted'
                              ? 'You have accepted this offer'
                              : (isExpired
                                  ? 'Offer has expired'
                                  : 'You have rejected this offer'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: currentStatus == 'accepted'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFEF4444),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleOfferResponse(
      BuildContext bottomSheetContext, String offerId, String action) {
    String actionText = action == 'accepted' ? 'Accept' : 'Reject';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              action == 'accepted' ? Icons.check_circle : Icons.cancel,
              color: action == 'accepted'
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 12),
            Text('$actionText Offer?'),
          ],
        ),
        content: Text(
          'Are you sure you want to $actionText this offer letter?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: action == 'accepted'
                    ? [const Color(0xFF10B981), const Color(0xFF059669)]
                    : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  Navigator.pop(dialogContext); // Close dialog
                  try {
                    await FirebaseFirestore.instance
                        .collection('OfferLetters')
                        .doc(offerId)
                        .update({
                      'status': action,
                      'respondedAt': FieldValue.serverTimestamp(),
                      if (action == 'rejected') 'notificationSent': true,
                    });
                    // Update AppliedCandidates
                    await _updateAppliedCandidatesStatus(offerId, action);
                    // Send notification for rejection
                    if (action == 'rejected') {
                      // Fetch offer data again to get details
                      final updatedOfferDoc = await FirebaseFirestore.instance
                          .collection('OfferLetters')
                          .doc(offerId)
                          .get();
                      if (updatedOfferDoc.exists) {
                        final updatedOffer = updatedOfferDoc.data()!;
                        final candidateEmail = await _getCandidateEmail(updatedOffer['candidateId']);
                        final recruiterEmail = await _getRecruiterEmail(
                            updatedOffer['recruiterId']);
                        await _notifyRecruiter(
                          recruiterEmail: recruiterEmail,
                          candidateName: updatedOffer['candidateName'],
                          candidateEmail: candidateEmail,
                          jobTitle: updatedOffer['jobTitle'],
                          action: 'rejected',
                          offerId: offerId,
                        );
                      }
                    }
                    Navigator.pop(bottomSheetContext); // Close bottom sheet
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(
                              action == 'accepted'
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Text(
                                'Offer ${action == 'accepted' ? 'accepted' : 'rejected'} successfully!'),
                          ],
                        ),
                        backgroundColor: action == 'accepted'
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}