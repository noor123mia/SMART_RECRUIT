import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

class JobSeekerOffersScreen extends StatefulWidget {
  const JobSeekerOffersScreen({Key? key}) : super(key: key);

  @override
  _JobSeekerOffersScreenState createState() => _JobSeekerOffersScreenState();
}

class _JobSeekerOffersScreenState extends State<JobSeekerOffersScreen> {
  String? candidateId;

  @override
  void initState() {
    super.initState();
    _initializeCandidateId();
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
        }).catchError((e) {
          developer.log('Error updating expired offer: $e');
        });
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
                    });
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
