import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  int offersSent = 0;
  int offersAccepted = 0;
  int offersRejected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F9FF),
      appBar: AppBar(
        title: Text(
          'Job Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFF0EA5E9),
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.analytics,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Track Your Jobs',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Monitor performance & insights',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Job Selection Card
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0EA5E9).withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.work_outline,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Select Job Position',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('JobsPosted')
                          .orderBy('postedDate', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF0EA5E9)),
                              ),
                            ),
                          );
                        }

                        final jobs = snapshot.data!.docs;

                        if (jobs.isEmpty) {
                          return Container(
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Color(0xFF0EA5E9).withOpacity(0.2),
                              ),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.work_off_outlined,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No jobs posted yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Container(
                          decoration: BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Color(0xFF0EA5E9).withOpacity(0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedJobId,
                              hint: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Choose a job to view metrics',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              icon: Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF0EA5E9),
                                ),
                              ),
                              items: jobs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      data['jobTitle'] ?? 'Untitled Job',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1E293B),
                                      ),
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
          ),

          SizedBox(height: 24),

          // Metrics Display
          if (isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading metrics...',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (selectedJobData != null)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Job Info Card
                    _buildJobInfoCard(),
                    SizedBox(height: 20),

                    // Metrics Grid
                    _buildMetricsGrid(),
                    SizedBox(height: 24),
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
                        color: Color(0xFFF0F9FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 64,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Select a job to view metrics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Track applications, interviews & offers',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
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
    final postedDate = selectedJobData!['postedDate'] as Timestamp?;
    final lastDate = selectedJobData!['lastDateToApply'] as Timestamp?;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.business_center,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    selectedJobData!['jobTitle'] ?? 'Job Title',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.3), height: 1),
            SizedBox(height: 20),
            _buildJobInfoRow(
              Icons.calendar_today,
              'Posted Date',
              postedDate != null
                  ? DateFormat('dd MMM yyyy').format(postedDate.toDate())
                  : 'N/A',
            ),
            SizedBox(height: 16),
            _buildJobInfoRow(
              Icons.event_busy,
              'Last Date to Apply',
              lastDate != null
                  ? DateFormat('dd MMM yyyy').format(lastDate.toDate())
                  : 'N/A',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Total Applications',
                totalApplications.toString(),
                Icons.person_search,
                Color(0xFF0EA5E9),
                Color(0xFFE0F2FE),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Interviews',
                scheduledInterviews.toString(),
                Icons.event_available,
                Color(0xFF8B5CF6),
                Color(0xFFF3E8FF),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Offers Sent',
                offersSent.toString(),
                Icons.mail_outline,
                Color(0xFFF59E0B),
                Color(0xFFFEF3C7),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                'Accepted',
                offersAccepted.toString(),
                Icons.check_circle_outline,
                Color(0xFF10B981),
                Color(0xFFD1FAE5),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildFullWidthMetricCard(
          'Offers Rejected',
          offersRejected.toString(),
          Icons.cancel_outlined,
          Color(0xFFEF4444),
          Color(0xFFFEE2E2),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon,
      Color iconColor, Color bgColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthMetricCard(String title, String value, IconData icon,
      Color iconColor, Color bgColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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

      // Count offers sent, accepted, and rejected
      final offersSnapshot = await FirebaseFirestore.instance
          .collection('OfferLetters')
          .where('jobId', isEqualTo: jobId)
          .get();

      offersSent = offersSnapshot.docs.length;
      offersAccepted = offersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'accepted')
          .length;
      offersRejected = offersSnapshot.docs
          .where((doc) => doc.data()['status'] == 'rejected')
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
        ),
      );
    }
  }
}
