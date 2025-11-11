import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class AppliedJobsScreen extends StatefulWidget {
  const AppliedJobsScreen({Key? key}) : super(key: key);

  @override
  State<AppliedJobsScreen> createState() => _AppliedJobsScreenState();
}

class _AppliedJobsScreenState extends State<AppliedJobsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    String? currentUserId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Applied Jobs',
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
      body: currentUserId == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Please log in to view your applied jobs',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
          : _buildAppliedJobsList(currentUserId),
    );
  }

  Widget _buildAppliedJobsList(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: currentUserId)
          .orderBy('appliedAt', descending: true)
          .snapshots(),
      builder: (context, appliedSnapshot) {
        if (appliedSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          );
        }

        if (appliedSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading applied jobs: ${appliedSnapshot.error}',
                  style: TextStyle(color: Colors.red[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!appliedSnapshot.hasData || appliedSnapshot.data!.docs.isEmpty) {
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
                    Icons.assignment_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "No Applied Jobs Yet",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 97, 97, 97),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your applied jobs will appear here",
                  style: TextStyle(
                    fontSize: 15,
                    color: Color.fromARGB(255, 97, 97, 97),
                  ),
                ),
              ],
            ),
          );
        }

        // Create a list of Future for each job
        List<Future<Map<String, dynamic>>> jobFutures = [];
        Map<String, String> jobStatusMap = {};

        for (var doc in appliedSnapshot.data!.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String jobId = data['jobId'] ?? '';
          String status = data['status'] ?? 'pending';

          if (jobId.isNotEmpty) {
            jobStatusMap[jobId] = status;
            jobFutures.add(_firestore
                .collection('JobsPosted')
                .doc(jobId)
                .get()
                .then((jobDoc) {
              if (jobDoc.exists) {
                Map<String, dynamic> jobData =
                    jobDoc.data() as Map<String, dynamic>;
                jobData['id'] = jobDoc.id;
                return jobData;
              }
              return <String, dynamic>{};
            }));
          }
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Future.wait(jobFutures),
          builder: (context, jobsSnapshot) {
            if (jobsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                ),
              );
            }

            if (jobsSnapshot.hasError) {
              return Center(child: Text('Error: ${jobsSnapshot.error}'));
            }

            List<Map<String, dynamic>> jobs =
                jobsSnapshot.data!.where((job) => job.isNotEmpty).toList();

            if (jobs.isEmpty) {
              return const Center(child: Text('No job details found.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> job = jobs[index];
                String jobId = job['id'] ?? '';
                String status = jobStatusMap[jobId] ?? 'pending';

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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JobDetailsScreen(
                              job: job,
                              status: status,
                            ),
                          ),
                        );
                      },
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
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.assignment,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job['title'] ?? 'Unknown Position',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        job['company_name'] ??
                                            'Unknown Company',
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
                                    color: _getStatusBgColor(status),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getStatusIcon(status),
                                          size: 16,
                                          color: _getStatusColor(status)),
                                      const SizedBox(width: 6),
                                      Text(
                                        _capitalizeStatus(status),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getStatusColor(status),
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
                              Icons.location_on_outlined,
                              'Location',
                              job['location'] ?? 'Remote',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.work_outline,
                              'Job Type',
                              job['job_type'] ?? 'Full-time',
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.attach_money_outlined,
                              'Salary',
                              job['salary_range'] ?? 'Negotiable',
                            ),
                            if (job['last_date_to_apply'] != null) ...[
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                Icons.calendar_today_outlined,
                                'Apply Before',
                                _formatTimestamp(job['last_date_to_apply']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF1D4ED8), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'hired':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'interviewed':
      case 'shortlisted':
        return Icons.trending_up;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'hired':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'interviewed':
      case 'shortlisted':
        return const Color(0xFFF59E0B);
      case 'pending':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'hired':
        return const Color(0xFFD1FAE5);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      case 'interviewed':
      case 'shortlisted':
        return const Color(0xFFFEF3C7);
      case 'pending':
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  String _capitalizeStatus(String status) {
    return status
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return timestamp;
      }
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}

class JobDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  final String status;

  const JobDetailsScreen({
    Key? key,
    required this.job,
    required this.status,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Improved parsing for description to handle various formats more robustly
    dynamic rawDescription = job['description'];
    Map<String, dynamic> descriptionMap = _parseDescription(rawDescription);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          job['title'] ?? 'Job Details',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 18,
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
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _getStatusBgColor(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getStatusIcon(status),
                    size: 16, color: _getStatusColor(status)),
                const SizedBox(width: 6),
                Text(
                  _capitalizeStatus(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['title'] ?? 'Unknown Position',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            job['company_name'] ?? 'Unknown Company',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 24),

                // Job info chips
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      Icons.location_on_outlined,
                      job['location'] ?? 'Remote',
                    ),
                    _buildInfoChip(
                      Icons.work_outline,
                      job['job_type'] ?? 'Full-time',
                    ),
                    _buildInfoChip(
                      Icons.business_center_outlined,
                      job['contract_type'] ?? 'Permanent',
                    ),
                    _buildInfoChip(
                      Icons.attach_money_outlined,
                      job['salary_range'] ?? 'Negotiable',
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                _buildDateInfo(),

                const Divider(height: 32),

                // Sections
                if (descriptionMap.containsKey('position_summary') &&
                    descriptionMap['position_summary'] != null &&
                    descriptionMap['position_summary'].toString().isNotEmpty)
                  _buildDetailSection(
                    'Position Summary',
                    descriptionMap['position_summary'].toString(),
                  ),

                if (descriptionMap.containsKey('responsibilities') &&
                    descriptionMap['responsibilities'] != null &&
                    (descriptionMap['responsibilities'] as dynamic)
                        .toString()
                        .isNotEmpty)
                  _buildListSection(
                    'Responsibilities',
                    descriptionMap['responsibilities'],
                  ),

                if (descriptionMap.containsKey('required_skills') &&
                    descriptionMap['required_skills'] != null &&
                    (descriptionMap['required_skills'] as dynamic)
                        .toString()
                        .isNotEmpty)
                  _buildListSection(
                    'Required Skills',
                    descriptionMap['required_skills'],
                  ),

                if (descriptionMap.containsKey('preferred_skills') &&
                    descriptionMap['preferred_skills'] != null &&
                    (descriptionMap['preferred_skills'] as dynamic)
                        .toString()
                        .isNotEmpty)
                  _buildListSection(
                    'Preferred Skills',
                    descriptionMap['preferred_skills'],
                  ),

                if (descriptionMap.containsKey('technical_skills') &&
                    descriptionMap['technical_skills'] != null)
                  _buildTechnicalSkills(descriptionMap['technical_skills']),

                if (descriptionMap.containsKey('what_we_offer') &&
                    descriptionMap['what_we_offer'] != null &&
                    (descriptionMap['what_we_offer'] as dynamic)
                        .toString()
                        .isNotEmpty)
                  _buildListSection(
                    'What We Offer',
                    descriptionMap['what_we_offer'],
                  ),

                const SizedBox(height: 24),

                // Close button
                Center(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.pop(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Close',
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
  }

  /// Improved description parser to handle String, JSON String, Map, and nested structures
  Map<String, dynamic> _parseDescription(dynamic rawDescription) {
    Map<String, dynamic> descriptionMap = {};

    if (rawDescription == null) {
      return descriptionMap;
    }

    dynamic parsed = rawDescription;

    // If it's a String, try to decode as JSON
    if (parsed is String) {
      parsed = parsed.tryJsonDecode();
    }

    // Now parsed could be Map, List, String, etc.
    if (parsed is Map<String, dynamic>) {
      // Check for nested 'description' key
      if (parsed.containsKey('description')) {
        dynamic nested = parsed['description'];
        if (nested is Map<String, dynamic>) {
          descriptionMap = Map<String, dynamic>.from(nested);
        } else if (nested != null) {
          // If nested is not Map, treat as position_summary
          descriptionMap = {'position_summary': nested.toString()};
        }
      } else {
        // Use the map directly
        descriptionMap = Map<String, dynamic>.from(parsed);
      }
    } else {
      // Fallback: treat everything else as position_summary
      descriptionMap = {'position_summary': parsed.toString()};
    }

    // Ensure all values are properly typed (e.g., lists for responsibilities)
    descriptionMap.forEach((key, value) {
      if (key != 'position_summary' && value is! List && value != null) {
        descriptionMap[key] = [value.toString()];
      }
    });

    return descriptionMap;
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateInfo() {
    final postedDate = job['posted_on'] != null
        ? _formatTimestamp(job['posted_on'])
        : 'Unknown';

    final lastDate = job['last_date_to_apply'] != null
        ? _formatTimestamp(job['last_date_to_apply'])
        : 'Unknown';

    return Row(
      children: [
        Expanded(
          child: _buildInfoItem(
            'Posted On',
            postedDate,
            Icons.calendar_today_outlined,
          ),
        ),
        Expanded(
          child: _buildInfoItem(
            'Apply Before',
            lastDate,
            Icons.alarm_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF1D4ED8)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, String content) {
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
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1E293B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildListSection(String title, dynamic items) {
    List<dynamic> itemsList = [];

    if (items is List) {
      itemsList = items;
    } else if (items != null) {
      itemsList = [items.toString()];
    }

    if (itemsList.isEmpty) return const SizedBox.shrink();

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
        const SizedBox(height: 12),
        ...itemsList.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.only(right: 8),
                    child: const Text(
                      '•',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.toString(),
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTechnicalSkills(dynamic techSkillsRaw) {
    // Safely handle if not a Map
    if (techSkillsRaw is! Map) {
      return _buildListSection('Technical Skills', techSkillsRaw);
    }

    Map<String, dynamic> techSkills = Map<String, dynamic>.from(techSkillsRaw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Technical Skills',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...techSkills.entries.map((entry) {
          String category = entry.key;
          dynamic skillsRaw = entry.value;
          List<dynamic> skills = [];

          if (skillsRaw is List) {
            skills = skillsRaw;
          } else if (skillsRaw != null) {
            skills = [skillsRaw];
          }

          if (skills.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills
                    .map((skill) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            skill.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ],
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'hired':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'interviewed':
      case 'shortlisted':
        return Icons.trending_up;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'hired':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'interviewed':
      case 'shortlisted':
        return const Color(0xFFF59E0B);
      case 'pending':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'hired':
        return const Color(0xFFD1FAE5);
      case 'rejected':
        return const Color(0xFFFEE2E2);
      case 'interviewed':
      case 'shortlisted':
        return const Color(0xFFFEF3C7);
      case 'pending':
      default:
        return const Color(0xFFDBEAFE);
    }
  }

  String _capitalizeStatus(String status) {
    return status
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return timestamp;
      }
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy').format(dateTime);
  }
}

// Helper extension to parse JSON safely
extension StringExtension on String {
  dynamic tryJsonDecode() {
    try {
      return jsonDecode(this);
    } catch (e) {
      return this;
    }
  }
}
