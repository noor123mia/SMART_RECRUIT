import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/screens/JobDetailsViewScreen.dart';
import 'package:flutter_application_2/screens/ApplicationFormScreen.dart';

class CandidateApplicationScreen extends StatefulWidget {
  @override
  _CandidateApplicationScreenState createState() =>
      _CandidateApplicationScreenState();
}

class _CandidateApplicationScreenState
    extends State<CandidateApplicationScreen> {
  String? searchQuery;
  String? sortBy = 'none'; // Default to no filter
  Set<String> appliedJobIds = {};
  Set<String> loadingJobIds = {};

  @override
  void initState() {
    super.initState();
    _loadAppliedJobs();
  }

  Future<void> _loadAppliedJobs() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final String jobSeekerId = currentUser.uid;
    try {
      final appliedSnapshot = await FirebaseFirestore.instance
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: jobSeekerId)
          .get();

      if (mounted) {
        setState(() {
          appliedJobIds =
              appliedSnapshot.docs.map((doc) => doc['jobId'] as String).toSet();
        });
      }
    } catch (e) {
      // Handle error silently or log it
    }
  }

  void _showSearchDialog() {
    final TextEditingController controller = TextEditingController(
      text: searchQuery ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.search,
                color: Color(0xFF3B82F6),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Search Jobs',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(minHeight: 60),
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (value) {
              setState(() {
                searchQuery = value.isEmpty ? null : value.toLowerCase();
              });
              Navigator.pop(context);
            },
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'By Title, Company or Location',
              hintStyle: TextStyle(
                fontSize: 15,
                color: Colors.grey[400],
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(
                Icons.work_outline,
                color: Color(0xFF64748B),
                size: 22,
              ),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                      onPressed: () {
                        controller.clear();
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                searchQuery = controller.text.isEmpty
                    ? null
                    : controller.text.toLowerCase();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Search',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsAlignment: MainAxisAlignment.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Available Jobs",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 1.2,
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
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort, color: Colors.white),
            onPressed: () {
              _showSortOptions();
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Job Listings
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('JobsPosted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(
                      icon: Icons.work_off_rounded,
                      title: "No Jobs Available",
                      message: "Check back later for new opportunities");
                }

                // Filter jobs based on search query only (no expiration filter)
                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var job = doc.data() as Map<String, dynamic>;

                  // Apply search filter
                  bool matchesSearch = searchQuery == null ||
                      job['title']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ==
                          true ||
                      job['company_name']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ==
                          true ||
                      job['location']
                              ?.toString()
                              .toLowerCase()
                              .contains(searchQuery!) ==
                          true;

                  return matchesSearch;
                }).toList();

                // Sort jobs based on selected sort option
                if (sortBy == 'salary') {
                  filteredDocs.sort((a, b) {
                    var jobA = a.data() as Map<String, dynamic>;
                    var jobB = b.data() as Map<String, dynamic>;

                    String salaryA = jobA['salary_range'] ?? '0';
                    String salaryB = jobB['salary_range'] ?? '0';

                    // Extract numeric values from salary strings (assuming format like "$50,000-$70,000")
                    int valueA = _extractHighestSalary(salaryA);
                    int valueB = _extractHighestSalary(salaryB);

                    return valueB
                        .compareTo(valueA); // Sort by highest salary descending
                  });
                } else if (sortBy == 'newest') {
                  // Sort by newest using 'posted_on'
                  filteredDocs.sort((a, b) {
                    var jobA = a.data() as Map<String, dynamic>;
                    var jobB = b.data() as Map<String, dynamic>;

                    dynamic timeA = jobA['posted_on'];
                    dynamic timeB = jobB['posted_on'];

                    DateTime dateA;
                    if (timeA is Timestamp) {
                      dateA = timeA.toDate();
                    } else if (timeA is String) {
                      try {
                        dateA = DateTime.parse(timeA);
                      } catch (e) {
                        dateA = DateTime(1970); // Old date for invalid
                      }
                    } else {
                      dateA = DateTime(1970);
                    }

                    DateTime dateB;
                    if (timeB is Timestamp) {
                      dateB = timeB.toDate();
                    } else if (timeB is String) {
                      try {
                        dateB = DateTime.parse(timeB);
                      } catch (e) {
                        dateB = DateTime(1970);
                      }
                    } else {
                      dateB = DateTime(1970);
                    }

                    return dateB.compareTo(dateA); // Newest first
                  });
                }
                // If sortBy == 'none', no sorting applied

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState(
                      icon: Icons.search_off_rounded,
                      title: "No Matching Jobs Found",
                      message:
                          "Try adjusting your search criteria or check back later for new opportunities.");
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
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

  Widget _buildEmptyState(
      {required IconData icon,
      required String title,
      required String message}) {
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
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  int _extractHighestSalary(String salaryRange) {
    // Handle common salary formats
    if (salaryRange.isEmpty) return 0;

    // Extract all numeric parts from the string
    RegExp regExp = RegExp(r'[0-9,]+');
    var matches = regExp.allMatches(salaryRange);

    if (matches.isEmpty) return 0;

    // Find the highest value in case of a range
    int highestValue = 0;
    for (var match in matches) {
      String numStr = match.group(0)!.replaceAll(',', '');
      int value = int.tryParse(numStr) ?? 0;
      if (value > highestValue) highestValue = value;
    }

    return highestValue;
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sort Jobs By",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSortOption(
                    title: 'No Filter',
                    icon: Icons.filter_none,
                    isSelected: sortBy == 'none',
                    onTap: () {
                      this.setState(() {
                        sortBy = 'none';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildSortOption(
                    title: 'Newest First',
                    icon: Icons.access_time,
                    isSelected: sortBy == 'newest',
                    onTap: () {
                      this.setState(() {
                        sortBy = 'newest';
                      });
                      Navigator.pop(context);
                    },
                  ),
                  _buildSortOption(
                    title: 'Highest Salary',
                    icon: Icons.attach_money,
                    isSelected: sortBy == 'salary',
                    onTap: () {
                      this.setState(() {
                        sortBy = 'salary';
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF1D4ED8),
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? const Color(0xFF1D4ED8) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF1D4ED8), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(
      BuildContext context, Map<String, dynamic> job, String jobId) {
    final bool isApplied = appliedJobIds.contains(jobId);
    final bool isThisLoading = loadingJobIds.contains(jobId);

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
                  builder: (context) => JobDetailsViewScreen(
                        jobId: jobId,
                      )),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Job Title and Company Logo
                Row(
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
                        Icons.work,
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
                            job['title'] ?? 'No Title',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job['company_name'] ?? 'Unknown Company',
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
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getPostedTimeAgo(job['posted_on']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 16),

                // Location row
                _buildInfoRow(
                  Icons.location_on_rounded,
                  'Location',
                  job['location'] ?? 'Location Not Specified',
                ),
                const SizedBox(height: 12),

                // Job Type row
                _buildInfoRow(
                  Icons.work_outline_rounded,
                  'Job Type',
                  job['job_type'] ?? 'Not Specified',
                ),
                const SizedBox(height: 12),

                // Contract Type row
                _buildInfoRow(
                  Icons.description_outlined,
                  'Contract',
                  job['contract_type'] ?? 'Not Specified',
                ),
                const SizedBox(height: 12),

                // Salary row
                _buildInfoRow(
                  Icons.attach_money_rounded,
                  'Salary',
                  job['salary_range'] ?? 'Salary Not Defined',
                ),

                if (job['skills'] != null && (job['skills'] as List).isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        "Required Skills",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 97, 97, 97),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...(job['skills'] as List)
                              .take(3)
                              .map<Widget>((skill) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                skill.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            );
                          }).toList(),
                          if ((job['skills'] as List).length > 3)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                "+${(job['skills'] as List).length - 3} more",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => JobDetailsViewScreen(
                                      jobId: jobId,
                                    )),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                              color: Color(0xFF3B82F6), width: 1),
                          foregroundColor: const Color(0xFF3B82F6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'View Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: isApplied
                            ? () {
                                // Show message when already applied
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'You have already applied for this job',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF10B981),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            : (isThisLoading
                                ? null
                                : () => _handleApplyJob(context, jobId, job)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isApplied
                                  ? [
                                      const Color(0xFF10B981),
                                      const Color(0xFF059669)
                                    ]
                                  : [
                                      const Color(0xFF3B82F6),
                                      const Color(0xFF1D4ED8)
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: isApplied
                                  ? () {
                                      // Show message when already applied
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 12),
                                              const Expanded(
                                                child: Text(
                                                  'You have already applied for this job',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          backgroundColor:
                                              const Color(0xFF10B981),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  : (isThisLoading
                                      ? null
                                      : () =>
                                          _handleApplyJob(context, jobId, job)),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (Widget child,
                                      Animation<double> animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale:
                                            Tween<double>(begin: 0.9, end: 1.0)
                                                .animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: isThisLoading
                                      ? SizedBox(
                                          key: ValueKey('loading_$jobId'),
                                          width: 20,
                                          height: 20,
                                          child:
                                              const CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          key: ValueKey(
                                              isApplied ? 'applied' : 'apply'),
                                          isApplied ? 'Applied' : 'Apply Now',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _handleApplyJob(
      BuildContext context, String jobId, Map<String, dynamic> jobData) async {
    if (appliedJobIds.contains(jobId)) {
      _showInfoDialog('Application Already Submitted',
          'You have already applied for this job. You can check the status in your applications page.');
      return;
    }

    setState(() {
      loadingJobIds.add(jobId);
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        _showErrorDialog('You need to log in to apply for jobs.');
        return;
      }

      final String jobSeekerId = currentUser.uid;
      final String jobTitle = jobData['title'] ?? 'Unknown Job';
      final String companyName = jobData['company_name'] ?? 'Unknown Company';

      // Check if profile exists with required fields
      final profileSnapshot = await FirebaseFirestore.instance
          .collection('JobSeekersProfiles')
          .doc(jobSeekerId)
          .get();

      if (!profileSnapshot.exists) {
        // Profile doesn't exist, show application form
        _navigateToApplicationForm(jobId, jobTitle, companyName);
        return;
      }

      final profileData = profileSnapshot.data() as Map<String, dynamic>;

      // Check for mandatory fields
      final List<String> mandatoryFields = [
        'educations',
        'name',
        'phone',
        'profilePicUrl',
        'resumeUrl',
        'softSkills',
        'technicalSkills',
        'languages',
        'workExperiences',
      ];

      List<String> missingFields = [];

      for (String field in mandatoryFields) {
        if (profileData[field] == null ||
            (profileData[field] is String &&
                (profileData[field] as String).isEmpty) ||
            (profileData[field] is List &&
                (profileData[field] as List).isEmpty)) {
          missingFields.add(field);
        }
      }

      if (missingFields.isNotEmpty) {
        // Missing required profile fields, show application form
        _navigateToApplicationForm(jobId, jobTitle, companyName);
        return;
      }

      // Profile is complete, proceed with application
      await FirebaseFirestore.instance.collection('AppliedCandidates').add({
        'jobId': jobId,
        'candidateId': jobSeekerId,
        'appliedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'jobTitle': jobTitle,
        'companyName': companyName,
        'applicantName': profileData['name'],
        'applicantEmail': currentUser.email,
        'applicantResumeUrl': profileData['resumeUrl'],
        'applicantProfileUrl': profileData['profilePicUrl'],
        'applicantPhone': profileData['phone'],
        'educations': profileData['educations'],
        'languages': profileData['languages'],
        'technicalSkills': profileData['technicalSkills'],
        'softSkills': profileData['softSkills'],
        'workExperiences': profileData['workExperiences'],
      });

      setState(() {
        appliedJobIds.add(jobId);
      });

      _showSuccessDialog('Application Successfully Submitted!',
          'Your application for $jobTitle at $companyName has been submitted. You can check the status in your applications page.');
    } catch (e) {
      _showErrorDialog('Failed to apply: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          loadingJobIds.remove(jobId);
        });
      }
    }
  }

  void _navigateToApplicationForm(
      String jobId, String jobTitle, String companyName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ApplicationFormScreen(
          jobId: jobId,
          jobTitle: jobTitle,
          companyName: companyName,
          onApplicationSubmitted: () {
            if (mounted) {
              setState(() {
                appliedJobIds.add(jobId);
                loadingJobIds.remove(jobId);
              });
              _showSuccessDialog('Application Successfully Submitted!',
                  'Your application for $jobTitle at $companyName has been submitted. You can check the status in your applications page.');
            }
          },
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF10B981), size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  minimumSize: const Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  minimumSize: const Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF3B82F6), size: 48),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  minimumSize: const Size(200, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

String _getPostedTimeAgo(dynamic timestamp) {
  if (timestamp == null) return 'Recently';

  DateTime postedDate;

  if (timestamp is Timestamp) {
    postedDate = timestamp.toDate();
  } else if (timestamp is String) {
    try {
      postedDate = DateTime.parse(timestamp);
    } catch (e) {
      return 'Recently';
    }
  } else {
    return 'Recently';
  }

  final difference = DateTime.now().difference(postedDate);

  if (difference.inDays > 30) {
    return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
  } else if (difference.inDays > 0) {
    return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  } else {
    return 'Just now';
  }
}
