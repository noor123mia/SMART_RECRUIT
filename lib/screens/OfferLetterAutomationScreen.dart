import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:googleapis/gmail/v1.dart' as g;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
class OfferLetterAutomationScreen extends StatefulWidget {
  const OfferLetterAutomationScreen({Key? key}) : super(key: key);
  @override
  _OfferLetterAutomationScreenState createState() =>
      _OfferLetterAutomationScreenState();
}
class _OfferLetterAutomationScreenState
    extends State<OfferLetterAutomationScreen> {
  String? selectedJobId;
  String? selectedJobTitle;
  List<String> selectedCandidates = []; // stores candidate IDs
  String recruiterId = FirebaseAuth.instance.currentUser!.uid;
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? jobData;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Offer Letter Automation",
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
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Job Selection Card
          Container(
            margin: const EdgeInsets.all(20),
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('JobsPosted')
                  .where('recruiterId', isEqualTo: recruiterId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                var jobs = snapshot.data!.docs;
                if (jobs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("No jobs posted yet"),
                  );
                }
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Row(
                        children: [
                          Icon(Icons.work_outline, color: Color(0xFF3B82F6)),
                          SizedBox(width: 12),
                          Text(
                            "Select Job Position",
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      value: selectedJobId,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Color(0xFF3B82F6), size: 28),
                      items: jobs.map((job) {
                        var data = job.data() as Map<String, dynamic>;
                        return DropdownMenuItem<String>(
                          value: job.id,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF3B82F6).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.business_center,
                                    color: Color(0xFF3B82F6), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  data['title'] ?? 'No Title',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        var selectedJob =
                            jobs.firstWhere((job) => job.id == value);
                        var data = selectedJob.data() as Map<String, dynamic>;
                        setState(() {
                          selectedJobId = value;
                          selectedJobTitle = data['title'];
                          jobData = data;
                          selectedCandidates.clear();
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          // Candidates List
          if (selectedJobId != null)
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('ScheduledInterviews')
                    .where('recruiterId', isEqualTo: recruiterId)
                    .where('jobId', isEqualTo: selectedJobId)
                    .where('status', isEqualTo: 'accepted')
                    .snapshots(),
                builder: (context, interviewSnap) {
                  if (interviewSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  List<QueryDocumentSnapshot> interviews =
                      interviewSnap.data?.docs ?? [];
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('AppliedCandidates')
                        .where('jobId', isEqualTo: selectedJobId)
                        .where('status', isEqualTo: 'accepted')
                        .snapshots(),
                    builder: (context, appliedSnap) {
                      if (appliedSnap.connectionState ==
                              ConnectionState.waiting &&
                          interviews.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      List<QueryDocumentSnapshot> appliedDocs =
                          appliedSnap.hasData ? appliedSnap.data!.docs : [];
                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: _getCombinedCandidates(interviews, appliedDocs),
                        builder: (context, candSnap) {
                          if (candSnap.connectionState ==
                              ConnectionState.waiting) {
                            List<Map<String, dynamic>> tempCands =
                                _buildTempCandidatesFromInterviews(interviews);
                            return _buildColumnWithList(tempCands);
                          }
                          if (!candSnap.hasData || candSnap.data!.isEmpty) {
                            return _buildEmptyState();
                          }
                          return _buildColumnWithList(candSnap.data!);
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
  Future<List<Map<String, dynamic>>> _getCombinedCandidates(
      List<QueryDocumentSnapshot> interviews,
      List<QueryDocumentSnapshot> appliedDocs) async {
    List<Map<String, dynamic>> candidates = <Map<String, dynamic>>[];
    Set<String> existingCids = <String>{};
    // Add from interviews
    for (var doc in interviews) {
      var data = doc.data() as Map<String, dynamic>;
      String cid = data['candidateId'];
      candidates.add({
        'candidateId': cid,
        'candidateName': data['candidateName'] ?? 'Unknown',
        'position': data['position'] ?? selectedJobTitle,
        'date': data['date'],
        'time': data['time'],
        'type': 'interview',
      });
      existingCids.add(cid);
    }
    // Collect new applied candidates
    List<String> newCids = <String>[];
    List<QueryDocumentSnapshot> newAppliedDocs = <QueryDocumentSnapshot>[];
    for (var doc in appliedDocs) {
      var data = doc.data() as Map<String, dynamic>;
      String cid = data['candidateId'];
      if (!existingCids.contains(cid)) {
        newCids.add(cid);
        newAppliedDocs.add(doc);
      }
    }
    // Fetch names for new applied candidates
    if (newCids.isNotEmpty) {
      final fs = FirebaseFirestore.instance;
      final nameSnap = await fs
          .collection('JobSeekersProfiles')
          .where(FieldPath.documentId, whereIn: newCids)
          .get();
      Map<String, String> names = <String, String>{};
      for (var doc in nameSnap.docs) {
        names[doc.id] = doc.data()['name'] as String? ?? 'Unknown';
      }
      for (int i = 0; i < newAppliedDocs.length; i++) {
        String cid = newCids[i];
        candidates.add({
          'candidateId': cid,
          'candidateName': names[cid] ?? 'Unknown',
          'position': selectedJobTitle,
          'date': null,
          'time': null,
          'type': 'applied',
        });
      }
    }
    return candidates;
  }
  List<Map<String, dynamic>> _buildTempCandidatesFromInterviews(
      List<QueryDocumentSnapshot> interviews) {
    List<Map<String, dynamic>> tempCands = <Map<String, dynamic>>[];
    for (var doc in interviews) {
      var data = doc.data() as Map<String, dynamic>;
      String cid = data['candidateId'];
      tempCands.add({
        'candidateId': cid,
        'candidateName': data['candidateName'] ?? 'Unknown',
        'position': data['position'] ?? selectedJobTitle,
        'date': data['date'],
        'time': data['time'],
        'type': 'interview',
      });
    }
    return tempCands;
  }
  Widget _buildColumnWithList(List<Map<String, dynamic>> candidates) {
    return Column(
      children: [
        Expanded(
          child: _buildListViewFromCandidates(candidates),
        ),
        if (selectedCandidates.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _showOfferDetailsForm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.description,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          "Generate Offer Letter (${selectedCandidates.length})",
                          style: const TextStyle(
                            fontSize: 17,
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
    );
  }
  Widget _buildListViewFromCandidates(List<Map<String, dynamic>> candidates) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        var candidate = candidates[index];
        bool isSelected = selectedCandidates.contains(candidate['candidateId']);
        String subtitle = '';
        if (candidate['type'] == 'interview' &&
            candidate['date'] != null &&
            candidate['time'] != null) {
          subtitle =
              'Interviewed on: ${candidate['date']} at ${candidate['time']}';
        } else if (candidate['type'] == 'applied') {
          subtitle = 'Application selected';
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDBEAFE) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[200]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    selectedCandidates.remove(candidate['candidateId']);
                  } else {
                    selectedCandidates.add(candidate['candidateId']);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isSelected
                              ? [
                                  const Color(0xFF3B82F6),
                                  const Color(0xFF1D4ED8)
                                ]
                              : [Colors.grey[300]!, Colors.grey[400]!],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle : Icons.person_outline,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate['candidateName'],
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            candidate['position'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500]),
                            ),
                        ],
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
  }
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_off_outlined,
                size: 80, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            "No Selected or Accepted Candidates",
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              "Candidates with selected applications or accepted interviews will appear here",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _showOfferDetailsForm() {
    final TextEditingController joiningDateController = TextEditingController();
    final TextEditingController acceptanceDeadlineController =
        TextEditingController();
    final TextEditingController probationPeriodController =
        TextEditingController();
    final TextEditingController noticePeriodController =
        TextEditingController();
    DateTime? selectedJoiningDate;
    DateTime? selectedAcceptanceDeadline;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
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
                        child: const Icon(Icons.edit_document,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Offer Details",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Required Information",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Joining Date (Required)
                        GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedJoiningDate ??
                                  DateTime.now().add(const Duration(days: 14)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF3B82F6),
                                      onPrimary: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedJoiningDate = picked;
                                joiningDateController.text =
                                    DateFormat('MMMM dd, yyyy').format(picked);
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: _buildFormField(
                              controller: joiningDateController,
                              label: "Joining Date *",
                              hint: "Select joining date",
                              icon: Icons.calendar_today,
                            ),
                          ),
                        ),
                        // Acceptance Deadline (Required)
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedAcceptanceDeadline ??
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF3B82F6),
                                      onPrimary: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedAcceptanceDeadline = picked;
                                acceptanceDeadlineController.text =
                                    DateFormat('MMMM dd, yyyy').format(picked);
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: _buildFormField(
                              controller: acceptanceDeadlineController,
                              label: "Acceptance Deadline *",
                              hint: "Select deadline for acceptance/rejection",
                              icon: Icons.schedule,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "Optional Information",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Leave blank if not applicable",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildFormField(
                          controller: probationPeriodController,
                          label: "Probation Period",
                          hint: "e.g., 3 months",
                          icon: Icons.timelapse,
                        ),
                        const SizedBox(height: 16),
                        _buildFormField(
                          controller: noticePeriodController,
                          label: "Notice Period",
                          hint: "e.g., 30 days",
                          icon: Icons.event_note,
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          if (joiningDateController.text.isEmpty ||
                              acceptanceDeadlineController.text.isEmpty) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text("Please select both dates"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          // UPDATED: Validate that acceptance deadline is before joining date
                          final joiningDate = DateFormat('MMMM dd, yyyy')
                              .parse(joiningDateController.text);
                          final deadlineDate = DateFormat('MMMM dd, yyyy')
                              .parse(acceptanceDeadlineController.text);
                          if (deadlineDate.isAfter(joiningDate) ||
                              deadlineDate.isAtSameMomentAs(joiningDate)) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Acceptance deadline must be before the joining date"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            this.context,
                            MaterialPageRoute(
                              builder: (context) => OfferLetterEditorScreen(
                                jobData: jobData!,
                                selectedCandidates: selectedCandidates,
                                recruiterId: recruiterId,
                                jobId: selectedJobId!,
                                joiningDate: joiningDateController.text,
                                acceptanceDeadline:
                                    acceptanceDeadlineController.text,
                                probationPeriod: probationPeriodController.text,
                                noticePeriod: noticePeriodController.text,
                                onComplete: () {
                                  setState(() {
                                    selectedCandidates.clear();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text(
                                "Continue to Editor",
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
          ),
        ),
      ),
    );
  }
  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
// Editor Screen with Full Preview and Edit Dialog
class OfferLetterEditorScreen extends StatefulWidget {
  final Map<String, dynamic> jobData;
  final List<String> selectedCandidates;
  final String recruiterId;
  final String jobId;
  final String joiningDate;
  final String acceptanceDeadline;
  final String probationPeriod;
  final String noticePeriod;
  final VoidCallback onComplete;
  const OfferLetterEditorScreen({
    Key? key,
    required this.jobData,
    required this.selectedCandidates,
    required this.recruiterId,
    required this.jobId,
    required this.joiningDate,
    required this.acceptanceDeadline,
    required this.probationPeriod,
    required this.noticePeriod,
    required this.onComplete,
  }) : super(key: key);
  @override
  _OfferLetterEditorScreenState createState() =>
      _OfferLetterEditorScreenState();
}
class _OfferLetterEditorScreenState extends State<OfferLetterEditorScreen> {
  late TextEditingController companyNameController;
  late TextEditingController positionController;
  late TextEditingController locationController;
  late TextEditingController salaryController;
  late TextEditingController joiningDateController;
  late TextEditingController acceptanceDeadlineController;
  late TextEditingController probationController;
  late TextEditingController noticeController;
  late TextEditingController benefitsController;
  late TextEditingController openingParagraphController;
  late TextEditingController closingParagraphController;
  late TextEditingController acceptanceTextController;
  final _supabase = Supabase.instance.client;
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn =
      GoogleSignIn(scopes: ['https://www.googleapis.com/auth/gmail.send']);
  String? _recruiterName;
  g.GmailApi? _gmailApi;
  @override
  void initState() {
    super.initState();
    _initializeGmail();
    companyNameController = TextEditingController(
      text: widget.jobData['company_name'] ?? 'Company Name',
    );
    positionController = TextEditingController(
      text: widget.jobData['title'] ?? 'Position',
    );
    locationController = TextEditingController(
      text: widget.jobData['location'] ?? 'Location',
    );
    salaryController = TextEditingController(
      text: widget.jobData['salary_range'] ?? 'Competitive Package',
    );
    joiningDateController = TextEditingController(text: widget.joiningDate);
    acceptanceDeadlineController =
        TextEditingController(text: widget.acceptanceDeadline);
    probationController = TextEditingController(text: widget.probationPeriod);
    noticeController = TextEditingController(text: widget.noticePeriod);
    benefitsController = TextEditingController(
      text:
          'Health Insurance\nPaid Time Off\nProfessional Development\n401(k) Plan',
    );
    openingParagraphController = TextEditingController(
      text:
          "We are pleased to extend an offer of employment for the position of ${positionController.text} at ${companyNameController.text}. After careful consideration of your qualifications and our discussions, we believe you will be an excellent addition to our team.",
    );
    closingParagraphController = TextEditingController(
      text:
          "This offer is contingent upon successful completion of background verification and reference checks. Please confirm your acceptance by accepting this offer by ${acceptanceDeadlineController.text}. If no response is received by this date, the offer will be automatically considered withdrawn.",
    );
    acceptanceTextController = TextEditingController(
      text:
          "If you accept the terms and conditions outlined in this offer letter, please reply to accept this offer.",
    );
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
      // Fetch recruiter name from Firestore
      final userDoc =
          await _fs.collection('users').doc(widget.recruiterId).get();
      if (userDoc.exists) {
        _recruiterName = userDoc.data()?['name'] ?? 'Recruiter';
      }
    } catch (e) {
      developer.log('Gmail init error: $e');
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
    return base64Url
        .encode(utf8.encode(message))
        .replaceAll('+', '-')
        .replaceAll('/', '_');
  }
  Future<void> _sendOfferEmail({
    required String recruiterEmail,
    required String candidateEmail,
    required String candidateName,
    required String jobTitle,
  }) async {
    if (candidateEmail.isEmpty) {
      developer.log('Skipping email—candidate email missing.');
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
    if (_gmailApi == null || _recruiterName == null) {
      developer.log('Gmail API not initialized.');
      return;
    }
    final subject = 'Job Offer: $jobTitle';
    final body = '''
Hi $candidateName,
Congratulations! You have received a job offer for the position of $jobTitle.
You can view the complete offer letter details in the Smart Recruit app.
Best regards,
$_recruiterName
    ''';
    try {
      final message = g.Message()
        ..raw = _encodeEmail(recruiterEmail, candidateEmail, subject, body);
      await _gmailApi!.users.messages.send(message, 'me');
      developer.log('Offer email sent from $recruiterEmail to $candidateEmail');
    } catch (e) {
      developer.log('Offer email sending error: $e');
    }
  }
  Future<String> _getRecruiterEmail() async {
    try {
      final userDoc =
          await _fs.collection('users').doc(widget.recruiterId).get();
      return userDoc.data()?['email'] ?? '';
    } catch (e) {
      developer.log('Error fetching recruiter email: $e');
      return '';
    }
  }
  @override
  void dispose() {
    companyNameController.dispose();
    positionController.dispose();
    locationController.dispose();
    salaryController.dispose();
    joiningDateController.dispose();
    acceptanceDeadlineController.dispose();
    probationController.dispose();
    noticeController.dispose();
    benefitsController.dispose();
    openingParagraphController.dispose();
    closingParagraphController.dispose();
    acceptanceTextController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Offer Letter Preview",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditDialog,
            tooltip: "Edit Offer Content",
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildPreview(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _sendOfferLetters,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send, color: Colors.white),
                    SizedBox(width: 12),
                    Text(
                      "Send All Offer Letters",
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
    );
  }
  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
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
                      child:
                          const Icon(Icons.edit, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Edit Offer Content",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Modify fields to customize the offer letter template",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Edit any field to customize the offer letter",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      _buildEditField(
                        controller: companyNameController,
                        label: "Company Name",
                        icon: Icons.business,
                      ),
                      _buildEditField(
                        controller: positionController,
                        label: "Position Title",
                        icon: Icons.work,
                      ),
                      _buildEditField(
                        controller: locationController,
                        label: "Location",
                        icon: Icons.location_on,
                      ),
                      _buildEditField(
                        controller: salaryController,
                        label: "Compensation Package",
                        icon: Icons.payments,
                      ),
                      _buildEditField(
                        controller: joiningDateController,
                        label: "Joining Date",
                        icon: Icons.calendar_today,
                      ),
                      _buildEditField(
                        controller: acceptanceDeadlineController,
                        label: "Acceptance Deadline",
                        icon: Icons.schedule,
                      ),
                      _buildEditField(
                        controller: probationController,
                        label: "Probation Period",
                        icon: Icons.timelapse,
                      ),
                      _buildEditField(
                        controller: noticeController,
                        label: "Notice Period",
                        icon: Icons.event_note,
                      ),
                      _buildEditField(
                        controller: benefitsController,
                        label: "Benefits & Perks (one per line)",
                        icon: Icons.card_giftcard,
                        maxLines: 6,
                      ),
                      _buildEditField(
                        controller: openingParagraphController,
                        label: "Opening Paragraph",
                        icon: Icons.format_quote,
                        maxLines: 4,
                      ),
                      _buildEditField(
                        controller: closingParagraphController,
                        label: "Closing Paragraph",
                        icon: Icons.info_outline,
                        maxLines: 4,
                      ),
                      _buildEditField(
                        controller: acceptanceTextController,
                        label: "Acceptance Instructions",
                        icon: Icons.check_circle_outline,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close),
                        label: const Text("Cancel"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {}); // Trigger rebuild for preview
                              Navigator.pop(dialogContext);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    "Save Changes",
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
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPreview() {
    List<String> benefits =
        benefitsController.text.split('\n').where((b) => b.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Center(
          child: Text(
            companyNameController.text.toUpperCase(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: Color(0xFF3B82F6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            locationController.text,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 32),
        const Center(
          child: Text(
            "OFFER OF EMPLOYMENT",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3B82F6),
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Date
        Text(
          "Date: ${DateFormat('MMMM dd, yyyy').format(DateTime.now())}",
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        // Greeting
        const Text(
          "Dear [Candidate Name],",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        // Opening paragraph
        Text(
          openingParagraphController.text,
          style: const TextStyle(fontSize: 14, height: 1.6),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 24),
        // Position Details
        _buildSectionTitle("Position Details"),
        const SizedBox(height: 12),
        _buildDetailRow("Position:", positionController.text),
        _buildDetailRow("Location:", locationController.text),
        _buildDetailRow("Start Date:", joiningDateController.text),
        // UPDATED: Add Interviewed on: placeholder for preview
        _buildDetailRow("Interviewed on:", "[Interview Date]"),
        _buildDetailRow(
            "Employment Type:", widget.jobData['job_type'] ?? 'Full Time'),
        if (probationController.text.isNotEmpty)
          _buildDetailRow("Probation Period:", probationController.text),
        if (noticeController.text.isNotEmpty)
          _buildDetailRow("Notice Period:", noticeController.text),
        const SizedBox(height: 24),
        // Compensation
        _buildSectionTitle("Compensation & Benefits"),
        const SizedBox(height: 12),
        _buildDetailRow("Salary:", salaryController.text),
        const SizedBox(height: 8),
        const Text(
          "Additional Benefits:",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 8),
        ...benefits.map((benefit) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("• ", style: TextStyle(color: Colors.grey[700])),
                  Expanded(
                    child: Text(
                      benefit,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 24),
        // Closing
        Text(
          closingParagraphController.text,
          style: const TextStyle(fontSize: 14, height: 1.6),
          textAlign: TextAlign.justify,
        ),
        const SizedBox(height: 20),
        const Text(
          "We look forward to welcoming you to our team!",
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 32),
        const Text(
          "Sincerely,",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          companyNameController.text,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          "Human Resources Department",
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        const SizedBox(height: 40),
        Divider(color: Colors.grey[300]),
        const SizedBox(height: 20),
        const Text(
          "ACCEPTANCE",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          acceptanceTextController.text,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3B82F6),
      ),
    );
  }
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _sendOfferLetters() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (loadingContext) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Generating & Sending",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please wait...",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final recruiterEmail = await _getRecruiterEmail();
      int successCount = 0;
      for (String candidateId in widget.selectedCandidates) {
        try {
          // Fetch candidate profile for name
          var profileDoc = await _fs.collection('JobSeekersProfiles').doc(candidateId).get();
          if (!profileDoc.exists) continue;
          var profileData = profileDoc.data()!;
          String candidateName = profileData['name'] ?? 'Candidate';

          // Fetch applied doc for email and to update
          String candidateEmail = '';
          String? appliedDocId;
          final appliedQuery = await _fs
              .collection('AppliedCandidates')
              .where('candidateId', isEqualTo: candidateId)
              .where('jobId', isEqualTo: widget.jobId)
              .limit(1)
              .get();
          if (appliedQuery.docs.isNotEmpty) {
            final appData = appliedQuery.docs.first.data();
            candidateEmail = (appData['applicantEmail'] ?? '').toString();
            appliedDocId = appliedQuery.docs.first.id;
          }

          // Check for interview doc for date and to update
          String interviewDate = '[Interview Date]';
          String? interviewDocId;
          final interviewQuery = await _fs
              .collection('ScheduledInterviews')
              .where('candidateId', isEqualTo: candidateId)
              .where('jobId', isEqualTo: widget.jobId)
              .where('status', isEqualTo: 'accepted')
              .limit(1)
              .get();
          if (interviewQuery.docs.isNotEmpty) {
            final intData = interviewQuery.docs.first.data();
            interviewDate = intData['date'] ?? '[Interview Date]';
            interviewDocId = interviewQuery.docs.first.id;
          }

          // Generate PDF
          final pdf = await _generatePDF(candidateName, interviewDate);
          final pdfBytes = await pdf.save();
          String fileName =
              'offer_${candidateName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
          String filePath = 'offerletters/$fileName';
          // Upload to Supabase
          await _supabase.storage
              .from('smartrecruitfiles')
              .uploadBinary(filePath, pdfBytes);
          String publicUrl = _supabase.storage
              .from('smartrecruitfiles')
              .getPublicUrl(filePath);
          // Store in Firestore
          await FirebaseFirestore.instance.collection('OfferLetters').add({
            'candidateId': candidateId,
            'candidateName': candidateName,
            'recruiterId': widget.recruiterId,
            'jobId': widget.jobId,
            'jobTitle': positionController.text,
            'companyName': companyNameController.text,
            'location': locationController.text,
            'salary': salaryController.text,
            'startDate': joiningDateController.text,
            'acceptanceDeadline': acceptanceDeadlineController.text,
            'probationPeriod': probationController.text,
            'noticePeriod': noticeController.text,
            'openingParagraph': openingParagraphController.text,
            'closingParagraph': closingParagraphController.text,
            'acceptanceText': acceptanceTextController.text,
            'pdfUrl': publicUrl,
            'sentAt': FieldValue.serverTimestamp(),
            'status': 'sent',
          });
          // Update the interview status to OfferSent if exists
          if (interviewDocId != null) {
            await FirebaseFirestore.instance
                .collection('ScheduledInterviews')
                .doc(interviewDocId)
                .update({'status': 'OfferSent'});
          }
          // Update status in AppliedCandidates collection if exists
          if (appliedDocId != null) {
            await _fs.collection('AppliedCandidates').doc(appliedDocId).update({'status': 'OfferSent'});
          }
          // Send email if email is available
          if (candidateEmail.isNotEmpty && recruiterEmail.isNotEmpty) {
            await _sendOfferEmail(
              recruiterEmail: recruiterEmail,
              candidateEmail: candidateEmail,
              candidateName: candidateName,
              jobTitle: positionController.text,
            );
          }
          successCount++;
        } catch (e) {
          developer.log('Error for candidate $candidateId: $e');
        }
      }
      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close editor
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                    "✓ $successCount offer letter${successCount > 1 ? 's' : ''} sent successfully!"),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  Future<pw.Document> _generatePDF(
      String candidateName, String interviewDate) async {
    final pdf = pw.Document();
    List<String> benefits =
        benefitsController.text.split('\n').where((b) => b.isNotEmpty).toList();
    String currentDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(50),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Text(
              companyNameController.text.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 2,
                color: PdfColor.fromHex('#3B82F6'),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              locationController.text,
              style: const pw.TextStyle(fontSize: 12),
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Center(
            child: pw.Text(
              "OFFER OF EMPLOYMENT",
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.5,
                color: PdfColor.fromHex('#3B82F6'),
              ),
            ),
          ),
          pw.SizedBox(height: 30),
          pw.Text(
            "Date: $currentDate",
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            "Dear $candidateName,",
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            openingParagraphController.text,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            "POSITION DETAILS",
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#3B82F6'),
            ),
          ),
          pw.SizedBox(height: 10),
          _buildPDFDetailRow("Position:", positionController.text),
          _buildPDFDetailRow("Location:", locationController.text),
          _buildPDFDetailRow("Start Date:", joiningDateController.text),
          // UPDATED: Add Interviewed on: with actual date
          _buildPDFDetailRow("Interviewed on:", interviewDate),
          _buildPDFDetailRow(
              "Employment Type:", widget.jobData['job_type'] ?? 'Full Time'),
          if (probationController.text.isNotEmpty)
            _buildPDFDetailRow("Probation Period:", probationController.text),
          if (noticeController.text.isNotEmpty)
            _buildPDFDetailRow("Notice Period:", noticeController.text),
          pw.SizedBox(height: 20),
          pw.Text(
            "COMPENSATION & BENEFITS",
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#3B82F6'),
            ),
          ),
          pw.SizedBox(height: 10),
          _buildPDFDetailRow("Salary:", salaryController.text),
          pw.SizedBox(height: 8),
          pw.Text(
            "Additional Benefits:",
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          ...benefits.map((benefit) => pw.Padding(
                padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
                child: pw.Text(
                  "• $benefit",
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3),
                ),
              )),
          pw.SizedBox(height: 20),
          pw.Text(
            closingParagraphController.text,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.5),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            "We look forward to welcoming you to our team!",
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            "Sincerely,",
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(companyNameController.text,
              style: const pw.TextStyle(fontSize: 11)),
          pw.Text("Human Resources Department",
              style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 40),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 20),
          pw.Text(
            "ACCEPTANCE",
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1,
              color: PdfColor.fromHex('#3B82F6'),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            acceptanceTextController.text,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
    return pdf;
  }
  pw.Widget _buildPDFDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}