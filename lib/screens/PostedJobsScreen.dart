import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PostedJobsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Job Listings",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: Colors.white),
            onPressed: () {
              // TODO: Implement job filtering
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF1E3A8A)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('JobsPosted')
                  .where('recruiterId', isEqualTo: recruiterId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_dissatisfied_outlined,
                            size: 100, color: Colors.grey[400]),
                        SizedBox(height: 20),
                        Text(
                          "No Jobs Posted Yet",
                          style: TextStyle(
                              fontSize: 22,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var job = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    var jobId = snapshot.data!.docs[index].id;

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
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? 'No Title',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(context, jobId),
                ),
              ],
            ),
            SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.business_rounded,
              text: job['company_name'] ?? 'Unknown Company',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.location_on_rounded,
              text: job['location'] ?? 'Location Not Specified',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.location_on_rounded,
              text: job['job_type'] ?? 'Not Specified',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.article_rounded,
              text: job['contract_type'] ?? 'Not Specified',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.money_rounded,
              text: job['salary_range'] ?? 'Salary Not Defined',
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _showJobDetailsModal(context, job);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'View Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showJobDetailsModal(BuildContext context, Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Ensures the sheet can expand fully
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize:
              0.7, // Adjust to show a reasonable portion of the sheet initially
          minChildSize: 0.5,
          maxChildSize: 0.9, // Ensures it doesn't take the full screen
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Job Title: ${job['title']}",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text("Company: ${job['company_name']}"),
                    SizedBox(height: 10),
                    Text("Description: ${job['description']}"),
                    SizedBox(height: 10),
                    // Add more details here
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Widget _buildDetailRow({required IconData icon, required String text}) {
  return Row(
    children: [
      Icon(icon, color: const Color.fromARGB(255, 60, 102, 215), size: 20),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 16,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

String _formatDate(dynamic dateValue) {
  if (dateValue == null) return 'Not Specified';

  try {
    if (dateValue is Timestamp) {
      return DateFormat('dd MMM yyyy').format(dateValue.toDate());
    }

    if (dateValue is String) {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateValue));
    }

    return 'Invalid Date';
  } catch (e) {
    return 'Invalid Date';
  }
}

void _showDeleteConfirmation(BuildContext context, String jobId) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Delete Job', style: TextStyle(color: Color(0xFF1E3A8A))),
        content: Text('Are you sure you want to delete this job posting?'),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Delete'),
            onPressed: () {
              _deleteJob(context, jobId);
              Navigator.of(context).pop();
            },
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Job deleted successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed to delete job: ${e.toString()}"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
/*
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PostedJobsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    String recruiterId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          "Job Listings",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: Colors.white),
            onPressed: () {
              // TODO: Implement job filtering
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF1E3A8A)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('JobsPosted')
                  .where('recruiterId', isEqualTo: recruiterId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF1E3A8A)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_dissatisfied_outlined,
                            size: 100, color: Colors.grey[400]),
                        SizedBox(height: 20),
                        Text(
                          "No Jobs Posted Yet",
                          style: TextStyle(
                              fontSize: 22,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var job = snapshot.data!.docs[index].data()
                        as Map<String, dynamic>;
                    var jobId = snapshot.data!.docs[index].id;

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
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    job['title'] ?? 'No Title',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A8A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red[400]),
                  onPressed: () => _showDeleteConfirmation(context, jobId),
                ),
              ],
            ),
            SizedBox(height: 10),
            _buildDetailRow(
              icon: Icons.business_rounded,
              label: "Company",
              text: job['company_name'] ?? 'Unknown Company',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.location_on_rounded,
              label: "Location",
              text: job['location'] ?? 'Location Not Specified',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.work_outline_rounded,
              label: "Job Type",
              text: job['job_type'] ?? 'Not Specified',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.article_rounded,
              label: "Contract",
              text: job['contract_type'] ?? 'Not Specified',
            ),
            SizedBox(height: 8),
            _buildDetailRow(
              icon: Icons.attach_money_rounded,
              label: "Salary",
              text: job['salary_range'] ?? 'Salary Not Defined',
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _showJobDetailsModal(context, job);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1E3A8A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'View Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showJobDetailsModal(BuildContext context, Map<String, dynamic> job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFF9FAFB)],
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildDetailSection(
                        "Job Position",
                        job['title'] ?? 'N/A',
                        TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A))),
                    Divider(height: 30),
                    _buildDetailSection(
                        "Company", job['company_name'] ?? 'N/A'),
                    _buildDetailSection("Location", job['location'] ?? 'N/A'),
                    _buildDetailSection("Job Type", job['job_type'] ?? 'N/A'),
                    _buildDetailSection(
                        "Contract", job['contract_type'] ?? 'N/A'),
                    _buildDetailSection("Salary", job['salary_range'] ?? 'N/A'),
                    Divider(height: 30),
                    _buildDetailSection(
                        "Description",
                        job['description'] ?? 'No description provided.',
                        TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Color(0xFF1F2937))),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0D9488),
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Close',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

Widget _buildDetailRow(
    {required IconData icon, required String text, required String label}) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Color(0xFF3151A6), size: 20),
      ),
      SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              text,
              style: TextStyle(
                color: Color(0xFF1F2937),
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

Widget _buildDetailSection(String title, String content,
    [TextStyle? contentStyle]) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3151A6),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          content,
          style:
              contentStyle ?? TextStyle(fontSize: 16, color: Color(0xFF1F2937)),
        ),
      ],
    ),
  );
}

String _formatDate(dynamic dateValue) {
  if (dateValue == null) return 'Not Specified';

  try {
    if (dateValue is Timestamp) {
      return DateFormat('dd MMM yyyy').format(dateValue.toDate());
    }

    if (dateValue is String) {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateValue));
    }

    return 'Invalid Date';
  } catch (e) {
    return 'Invalid Date';
  }
}

void _showDeleteConfirmation(BuildContext context, String jobId) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(                 backgroundColor: Color(0xFF0D9488),
        title: Text('Delete Job', style: TextStyle(color: Color(0xFF1E3A8A))),
        content: Text('Are you sure you want to delete this job posting?'),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Delete'),
            onPressed: () {
              _deleteJob(context, jobId);
              Navigator.of(context).pop();
            },
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Job deleted successfully!"),
        backgroundColor: Color(0xFF0D9488),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed to delete job: ${e.toString()}"),
        backgroundColor: Colors.red[400],
      ),
    );
  }
}
*/
