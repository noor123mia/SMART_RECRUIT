import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class JobMetricsScreen extends StatefulWidget {
  @override
  _JobMetricsScreenState createState() => _JobMetricsScreenState();
}

class _JobMetricsScreenState extends State<JobMetricsScreen> {
  String? selectedJobId;
  Map<String, dynamic>? selectedJobData;
  bool isLoading = false;
  int totalApplications = 0;
  int scheduledInterviews = 0;
  int conductedInterviews = 0;
  int hiredCandidates = 0;
  int offersSent = 0;

  @override
  Widget build(BuildContext context) {
    final String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Job Analytics',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Color(0xFF3B82F6),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Section with Gradient
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Performance Insights',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Monitor recruitment metrics',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // Job Dropdown
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('JobsPosted')
                        .where('recruiterId', isEqualTo: recruiterId)
                        .orderBy('posted_on', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3B82F6)),
                              ),
                            ),
                          ),
                        );
                      }

                      final jobs = snapshot.data!.docs;

                      if (jobs.isEmpty) {
                        return Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Color(0xFF3B82F6), size: 20),
                              SizedBox(width: 10),
                              Text(
                                'No jobs posted yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: selectedJobId,
                            hint: Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.search,
                                      color: Color(0xFF64748B), size: 18),
                                  SizedBox(width: 10),
                                  Text(
                                    'Select job position',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            icon: Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            items: jobs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final title = data['title'] ?? 'Untitled Job';
                              final location =
                                  data['location'] ?? 'Not specified';
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Text(
                                    '$title ($location)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                _loadJobMetrics(value);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Metrics Display
          if (isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading analytics...',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (selectedJobData != null)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Job Info Card
                    _buildJobInfoCard(),
                    SizedBox(height: 20),

                    // Section Header
                    Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 16),
                      child: Text(
                        'Recruitment Pipeline',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),

                    // Metrics Grid
                    _buildMetricsGrid(),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.analytics_outlined,
                        size: 60,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No Job Selected',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Select a position to view analytics',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard() {
    final postedDate = selectedJobData!['posted_on'] as Timestamp?;
    final lastDate = selectedJobData!['last_date_to_apply'] as Timestamp?;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0D9488).withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0D9488).withOpacity(0.25),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.work_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedJobData!['title'] ?? 'Job Title',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.white.withOpacity(0.9),
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              selectedJobData!['location'] ?? 'Not specified',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete Button
                IconButton(
                  onPressed: () => _showDeleteConfirmationDialog(),
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white.withOpacity(0.8),
                    size: 24,
                  ),
                  tooltip: 'Delete Job',
                  padding: EdgeInsets.all(4),
                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      Colors.red.withOpacity(0.2),
                    ),
                    shape: MaterialStateProperty.all(
                      const CircleBorder(side: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
            Container(
              height: 1,
              color: Colors.white,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateInfo(
                    'Posted',
                    postedDate != null
                        ? DateFormat('dd MMM yyyy').format(postedDate.toDate())
                        : 'N/A',
                    Icons.calendar_today_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 45,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildDateInfo(
                    'Deadline',
                    lastDate != null
                        ? DateFormat('dd MMM yyyy').format(lastDate.toDate())
                        : 'N/A',
                    Icons.event_busy_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Delete Job?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Text(
            'This will permanently delete the job "${selectedJobData!['title'] ?? 'Job'}" from JobsPosted and all scheduled interviews for this job. This action cannot be undone.',
            style: TextStyle(
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteJob();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Delete',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteJob() async {
    if (selectedJobId == null) return;

    // Save old values for rollback on error
    final String oldJobId = selectedJobId!;
    final Map<String, dynamic>? oldJobData = selectedJobData;

    setState(() {
      isLoading = true;
      selectedJobId =
          null; // Null immediately to avoid DropdownButton assert during stream update
      // Keep selectedJobData intact for now
    });

    try {
      // Create a batch for atomic operations
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // Delete the job from JobsPosted
      batch.delete(
        FirebaseFirestore.instance.collection('JobsPosted').doc(oldJobId),
      );

      // Fetch all scheduled interviews for this job
      final interviewsSnapshot = await FirebaseFirestore.instance
          .collection('ScheduledInterviews')
          .where('jobId', isEqualTo: oldJobId)
          .get();

      // Add deletions for each interview to the batch
      for (var doc in interviewsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit the batch
      await batch.commit();

      // On success: null data and reset metrics
      setState(() {
        selectedJobData = null;
        isLoading = false;
        // Reset metrics
        totalApplications = 0;
        scheduledInterviews = 0;
        conductedInterviews = 0;
        hiredCandidates = 0;
        offersSent = 0;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Job & scheduled interviews deleted successfully.'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // On error: rollback to old state (nothing was deleted due to batch)
      setState(() {
        selectedJobId = oldJobId;
        selectedJobData = oldJobData;
        isLoading = false;
        // Metrics remain as they were (no reset)
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting job: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildDateInfo(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        _buildMetricCard(
          'Total Applications',
          totalApplications.toString(),
          Icons.people_outline_rounded,
          Color(0xFF3B82F6),
          'Candidates applied',
        ),
        SizedBox(height: 12),
        _buildMetricCard(
          'Scheduled Interviews',
          scheduledInterviews.toString(),
          Icons.calendar_month_rounded,
          Color(0xFF1D4ED8),
          'Interviews scheduled',
        ),
        SizedBox(height: 12),
        _buildMetricCard(
          'Conducted Interviews',
          conductedInterviews.toString(),
          Icons.task_alt_rounded,
          Color(0xFF0D9488),
          'Interviews completed',
        ),
        SizedBox(height: 12),
        _buildMetricCard(
          'Job Offers Sent',
          offersSent.toString(),
          Icons.mail_outline_rounded,
          Color(0xFF6366F1),
          'Offers issued',
        ),
        SizedBox(height: 12),
        _buildMetricCard(
          'Hired Candidates',
          hiredCandidates.toString(),
          Icons.verified_rounded,
          Color(0xFF059669),
          'Successfully hired',
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadJobMetrics(String jobId) async {
    setState(() {
      isLoading = true;
      selectedJobId = jobId;
    });

    try {
      // Fetch job data
      final jobDoc = await FirebaseFirestore.instance
          .collection('JobsPosted')
          .doc(jobId)
          .get();

      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      selectedJobData = jobDoc.data();
      selectedJobData!['id'] = jobDoc.id;

      // Count total applications
      final applicationsSnapshot = await FirebaseFirestore.instance
          .collection('AppliedCandidates')
          .where('jobId', isEqualTo: jobId)
          .get();
      totalApplications = applicationsSnapshot.docs.length;

      // Count scheduled interviews
      final interviewsSnapshot = await FirebaseFirestore.instance
          .collection('ScheduledInterviews')
          .where('jobId', isEqualTo: jobId)
          .get();
      scheduledInterviews = interviewsSnapshot.docs.length;

      // Count conducted interviews (those with non-empty status)
      conductedInterviews = interviewsSnapshot.docs.where((doc) {
        final status = doc.data()['status'];
        return status != null && status.toString().trim().isNotEmpty;
      }).length;

      // Count offers
      final offersSnapshot = await FirebaseFirestore.instance
          .collection('OfferLetters')
          .where('jobId', isEqualTo: jobId)
          .get();

      offersSent = offersSnapshot.docs.length;

      // Hired candidates are those who accepted offers
      hiredCandidates = offersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'accepted')
          .length;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading metrics: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
