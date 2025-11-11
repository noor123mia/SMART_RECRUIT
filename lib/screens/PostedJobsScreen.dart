import 'dart:convert'; // Added for JSON parsing
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/screens/JobDescriptionScreen.dart'; // Assuming this is for posting new jobs
import 'package:intl/intl.dart';

class PostedJobsScreen extends StatefulWidget {
  @override
  _PostedJobsScreenState createState() => _PostedJobsScreenState();
}

class _PostedJobsScreenState extends State<PostedJobsScreen> {
  String? searchQuery;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.toLowerCase().trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString().trim();
  }

  bool _isExpired(dynamic lastDate) {
    if (lastDate == null) return false;
    try {
      DateTime expiryDate;
      if (lastDate is Timestamp) {
        expiryDate = lastDate.toDate();
      } else if (lastDate is String) {
        expiryDate = DateTime.parse(lastDate);
      } else {
        return false;
      }
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Job Posted",
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0D9488),
        elevation: 4,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    JobDescriptionScreen()), // Fixed: Added const if applicable
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by title, company, location...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF3B82F6)),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  filled: true,
                  fillColor: Colors.transparent,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('JobsPosted')
                  .where('recruiterId', isEqualTo: recruiterId)
                  .orderBy('posted_on',
                      descending:
                          true) // Added: Sort by posted date, newest first
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text("Error loading jobs: ${snapshot.error}",
                            style: const TextStyle(
                                color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Refresh
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.work_off_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "No Jobs Posted Yet",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your job listings will appear here once you post them",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Improved filter: Search in title, company, location, job_type
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var job = doc.data() as Map<String, dynamic>;
                  if (searchQuery == null || searchQuery!.isEmpty) return true;

                  String title = _getString(job['title']).toLowerCase();
                  String company =
                      _getString(job['company_name']).toLowerCase();
                  String location = _getString(job['location']).toLowerCase();
                  String jobType = _getString(job['job_type']).toLowerCase();

                  return title.contains(searchQuery!) ||
                      company.contains(searchQuery!) ||
                      location.contains(searchQuery!) ||
                      jobType.contains(searchQuery!);
                }).toList();

                if (filteredDocs.isEmpty &&
                    searchQuery != null &&
                    searchQuery!.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          "No jobs found matching '$searchQuery'",
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Try adjusting your search terms",
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var job =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    var jobId = filteredDocs[index].id;

                    return _buildJobCard(context, job, jobId);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(
      BuildContext context, Map<String, dynamic> job, String jobId) {
    bool isExpired = _isExpired(job['last_date_to_apply']);
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
                builder: (context) => JobDetailsScreen(job: job),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title, Company, Expiry
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              Icons.work_outline_rounded,
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
                                  _getString(job['title'],
                                      defaultValue: 'No Title'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getString(job['company_name'],
                                      defaultValue: 'Unknown Company'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (isExpired)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.schedule,
                                              size: 14,
                                              color: Color(0xFFEF4444)),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Expired',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFEF4444),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFEF4444), size: 25),
                      onPressed: () => _showDeleteConfirmation(context, jobId),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Added: More details in card (Location, Job Type, Salary)
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              color: Colors.grey[600], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getString(job['location'],
                                  defaultValue: 'Location not specified'),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.work_outline,
                              color: Colors.grey[600], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getString(job['job_type'],
                                  defaultValue: 'Job type not specified'),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.attach_money_outlined,
                              color: Colors.grey[600], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getString(job['salary_range'],
                                  defaultValue: 'Salary not specified'),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatDate(job['last_date_to_apply']),
                            style: TextStyle(
                                fontSize: 12,
                                color: isExpired
                                    ? const Color(0xFFEF4444)
                                    : Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // View Details Button
                Center(
                  child: Container(
                    width: 140,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => JobDetailsScreen(job: job),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.open_in_new,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'View Details',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
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

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Not Specified';

    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Invalid Date';
      }
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  void _showDeleteConfirmation(BuildContext context, String jobId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 12),
              const Text('Delete Job?',
                  style: TextStyle(color: Color(0xFF1E293B))),
            ],
          ),
          content: const Text(
              'Are you sure you want to delete this job posting? This action cannot be undone.'),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _deleteJob(context, jobId);
                    Navigator.of(context).pop();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _deleteJob(BuildContext context, String jobId) async {
    try {
      await FirebaseFirestore.instance
          .collection('JobsPosted')
          .doc(jobId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Text("Job deleted successfully!"),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete job: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class JobDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const JobDetailsScreen({Key? key, required this.job}) : super(key: key);

  String _getString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString().trim();
  }

  dynamic _getDescriptionValue(dynamic descValue) {
    // Handle if description is already a Map (structured)
    if (descValue is Map<String, dynamic>) {
      return descValue;
    }
    // Handle if it's a JSON string
    String rawDesc = _getString(descValue);
    if (rawDesc.isNotEmpty &&
        rawDesc.startsWith('{') &&
        rawDesc.endsWith('}')) {
      try {
        return json.decode(rawDesc);
      } catch (e) {
        // Fallback to string
        return rawDesc;
      }
    }
    // Otherwise, treat as plain string
    return rawDesc;
  }

  bool _isExpired(dynamic lastDate) {
    if (lastDate == null) return false;
    try {
      DateTime expiryDate;
      if (lastDate is Timestamp) {
        expiryDate = lastDate.toDate();
      } else if (lastDate is String) {
        expiryDate = DateTime.parse(lastDate);
      } else {
        return false;
      }
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      return false;
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'Not Specified';

    try {
      DateTime date;
      if (dateValue is Timestamp) {
        date = dateValue.toDate();
      } else if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else {
        return 'Invalid Date';
      }
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isExpired = _isExpired(job['last_date_to_apply']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _getString(job['title'], defaultValue: 'Job Details'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.white,
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
          if (isExpired)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 6),
                    const Text(
                      'Expired',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.business,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getString(job['company_name'],
                                  defaultValue: 'Unknown Company'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _getString(job['location'],
                                  defaultValue: 'Not Specified'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
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
            const SizedBox(height: 24),
            _buildDetailSection('Job Details', [
              _buildDetailItem('Job Type',
                  _getString(job['job_type'], defaultValue: 'Not Specified')),
              _buildDetailItem(
                  'Contract Type',
                  _getString(job['contract_type'],
                      defaultValue: 'Not Specified')),
              _buildDetailItem('Salary Range',
                  _getString(job['salary_range'], defaultValue: 'Not Defined')),
              _buildDetailItem('Posted Date', _formatDate(job['posted_on'])),
              _buildDetailItem(
                  'Last Date to Apply', _formatDate(job['last_date_to_apply'])),
            ]),
            const SizedBox(height: 24),
            _buildDetailSection('Job Description', [
              _buildDescriptionSection(),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    dynamic descValue = _getDescriptionValue(job['description']);
    List<Widget> sections = [];

    if (descValue is Map<String, dynamic>) {
      // If structured as Map/JSON object, create sections from keys
      descValue.forEach((key, value) {
        String sectionTitle = key.toString().replaceAll('_', ' ').toUpperCase();
        String sectionContent = _getString(value);
        sections.add(_buildSubSection(sectionTitle, sectionContent));
      });
    } else {
      // Fallback to plain text parsing
      String description = descValue.toString();
      if (description.isEmpty) {
        description = 'No Description Available';
      }
      // Improved parsing: Split into sections based on common keywords, handle multiple lines better
      List<String> lines = description.split('\n');
      String currentSection = 'Overview';
      List<String> currentContent = [];

      for (String line in lines) {
        line = line.trim();
        if (line.isEmpty) {
          if (currentContent.isNotEmpty) {
            sections.add(
                _buildSubSection(currentSection, currentContent.join('\n')));
            currentContent.clear();
          }
          continue;
        }

        // Detect section headers (case-insensitive, more flexible)
        RegExp sectionRegex = RegExp(
            r'^(summary|overview|position summary|responsibilities|duties|requirements|qualifications|benefits|perks|key responsibilities|essential skills):?\s*',
            caseSensitive: false);
        if (sectionRegex.hasMatch(line)) {
          if (currentContent.isNotEmpty) {
            sections.add(
                _buildSubSection(currentSection, currentContent.join('\n')));
            currentContent.clear();
          }
          // Extract title
          Match? match = sectionRegex.firstMatch(line);
          if (match != null) {
            currentSection =
                match.group(0)!.toUpperCase().replaceAll(':', '').trim();
          } else {
            currentSection = line.split(':')[0].trim().toUpperCase();
          }
          // Add content after header
          String contentPart = line.substring(line.indexOf(':') + 1).trim();
          if (contentPart.isNotEmpty) {
            currentContent.add(contentPart);
          }
        } else if (line.toLowerCase().startsWith('- ') ||
            line.toLowerCase().startsWith('* ') ||
            line.startsWith('• ')) {
          // Treat as bullet point, add to current section
          currentContent.add(line);
        } else {
          currentContent.add(line);
        }
      }

      // Add last section
      if (currentContent.isNotEmpty) {
        sections
            .add(_buildSubSection(currentSection, currentContent.join('\n')));
      }

      // If no sections detected, treat as single overview
      if (sections.isEmpty) {
        sections.add(_buildSubSection('Overview', description));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _buildSubSection(String title, String content) {
    // Check for bullets or numbered lists and format accordingly
    List<String> contentLines =
        content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    List<Widget> formattedContent = [];
    for (String line in contentLines) {
      if (line.startsWith('- ') ||
          line.startsWith('* ') ||
          line.startsWith('• ')) {
        // Bullet point
        formattedContent.add(Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Expanded(
                  child: Text(line.substring(2).trim(),
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Color(0xFF1E293B)))),
            ],
          ),
        ));
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        // Numbered list
        formattedContent.add(Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.substring(0, line.indexOf('.') + 1),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              Expanded(
                  child: Text(line.substring(line.indexOf('.') + 1).trim(),
                      style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Color(0xFF1E293B)))),
            ],
          ),
        ));
      } else {
        formattedContent.add(Text(line,
            style: const TextStyle(
                fontSize: 14, height: 1.6, color: Color(0xFF1E293B))));
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          ...formattedContent,
        ],
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
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ),
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
}
