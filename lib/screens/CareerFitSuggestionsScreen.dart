import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/screens/JobDetailsViewScreen.dart';
import 'package:flutter_application_2/services/matching_service.dart';
import 'package:flutter_application_2/services/messaging_service.dart';
import 'package:flutter_application_2/services/job_notification_service.dart';

class CareerFitSuggestionsScreen extends StatefulWidget {
  const CareerFitSuggestionsScreen({Key? key}) : super(key: key);

  @override
  State<CareerFitSuggestionsScreen> createState() =>
      _CareerFitSuggestionsScreenState();
}

class _CareerFitSuggestionsScreenState
    extends State<CareerFitSuggestionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final MatchingService _matchingService;
  late final MessagingService _messagingService;
  late final JobNotificationService _jobNotificationService;

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _matchedJobs = [];
  Map<String, dynamic>? _userProfile;
  Map<String, String> _applicationStatus = {};
  List<String> _dismissedJobIds = [];

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService();
    _messagingService = MessagingService();
    _jobNotificationService = JobNotificationService();

    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {
        _messagingService.initialize(context);
        _loadUserProfile();
        _setupFirebaseListeners();
      },
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfileSnapshot = await _firestore
          .collection('JobSeekersProfiles')
          .doc(_auth.currentUser!.uid)
          .get();

      if (!userProfileSnapshot.exists) {
        setState(() {
          _errorMessage =
              'No career fit suggestions available. Profile not set.';
          _isLoading = false;
        });
        return;
      }

      _userProfile = _sanitizeDocument(userProfileSnapshot.data()!);
      _userProfile!['id'] = userProfileSnapshot.id;

      // Load dismissed and applied before matching
      await _loadDismissedJobs();
      await _checkAppliedJobs();

      // Now match with jobs
      await _matchUserWithJobs();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading profile: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDismissedJobs() async {
    try {
      final dismissedQuery = await _firestore
          .collection('DismissedJobs')
          .where('candidateId', isEqualTo: _auth.currentUser!.uid)
          .get();

      List<String> dismissedIds = [];
      for (var doc in dismissedQuery.docs) {
        final data = doc.data();
        if (data.containsKey('jobId')) {
          dismissedIds.add(data['jobId']);
        }
      }

      setState(() {
        _dismissedJobIds = dismissedIds;
      });
    } catch (e) {
      print('Error loading dismissed jobs: $e');
    }
  }

  Future<void> _checkAppliedJobs() async {
    try {
      final appliedJobsQuery = await _firestore
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: _auth.currentUser!.uid)
          .get();

      Map<String, String> newStatus = {};
      for (var doc in appliedJobsQuery.docs) {
        final data = doc.data();
        if (data.containsKey('jobId')) {
          newStatus[data['jobId']] = 'applied';
        }
      }

      setState(() {
        _applicationStatus = newStatus;
      });
    } catch (e) {
      print('Error checking applied jobs: $e');
    }
  }

  Map<String, dynamic> _sanitizeDocument(Map<String, dynamic> doc) {
    final result = <String, dynamic>{};
    doc.forEach((key, value) {
      if (value is Timestamp) {
        result[key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        result[key] = _sanitizeDocument(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) {
          if (item is Map) {
            return _sanitizeDocument(Map<String, dynamic>.from(item));
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          } else {
            return item;
          }
        }).toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  Future<void> _matchUserWithJobs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _matchedJobs = [];
    });

    try {
      if (_userProfile == null) {
        setState(() {
          _errorMessage = 'User profile not loaded';
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic> candidate = _userProfile!;

      // Get all jobs
      final jobsQuery = await _firestore.collection('JobsPosted').get();

      if (jobsQuery.docs.isEmpty) {
        setState(() {
          _errorMessage = 'No jobs found';
          _isLoading = false;
        });
        return;
      }

      // Track processed job IDs to avoid duplicates
      final Set<String> processedJobIds = {};

      // Match user with each job
      for (var jobDoc in jobsQuery.docs) {
        Map<String, dynamic> job = _sanitizeDocument(jobDoc.data());
        job['id'] = jobDoc.id;

        // Skip if job already processed
        if (processedJobIds.contains(job['id'])) continue;

        // Skip if dismissed or applied
        if (_dismissedJobIds.contains(job['id']) ||
            _applicationStatus.containsKey(job['id'])) {
          continue;
        }

        try {
          final response =
              await _matchingService.matchCandidate(job, candidate);

          if (response is Map<String, dynamic> &&
              response.containsKey('match_score')) {
            final rawMatchScore = response['match_score'] as num? ?? 0.0;
            final double matchScore = rawMatchScore > 1
                ? rawMatchScore / 100.0
                : rawMatchScore.toDouble();

            if (matchScore > 0.4) {
              // Check if notification already exists
              final existingNotifs = await _firestore
                  .collection('Notifications')
                  .where('jobId', isEqualTo: job['id'])
                  .where('candidateId', isEqualTo: candidate['id'])
                  .limit(1)
                  .get();

              String notificationId;
              if (existingNotifs.docs.isEmpty) {
                // Save new notification
                notificationId =
                    await _saveNotification(job, candidate, matchScore);

                // Send push notification
                await _jobNotificationService.sendJobMatchNotification(
                  candidateId: candidate['id'],
                  job: job,
                  matchScore: matchScore,
                );
              } else {
                notificationId = existingNotifs.docs.first.id;
              }

              // Only add to matched jobs if not already present
              if (!_matchedJobs.any((m) => m['job']['id'] == job['id'])) {
                _matchedJobs.add({
                  'notificationId': notificationId,
                  'job': job,
                  'matchScore': matchScore,
                });
                processedJobIds.add(job['id']);
              }
            }
          }
        } catch (e) {
          print('Error matching job ${job['title']}: $e');
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing jobs: $e';
        _isLoading = false;
      });
    }
  }

  Future<String> _saveNotification(Map<String, dynamic> job,
      Map<String, dynamic> candidate, double matchScore) async {
    try {
      final docRef = await _firestore.collection('Notifications').add({
        'candidateId': candidate['id'],
        'jobId': job['id'],
        'jobTitle': job['title'],
        'companyName': job['company_name'],
        'matchScore': matchScore,
        'message':
            'This job is a great career fit for you based on your profile. Consider applying!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'recruiterId': job['recruiterId'] ?? '',
      });

      await _jobNotificationService.saveNotificationToFirestore(
        userId: candidate['id'],
        title: 'AI Career Fit Suggestion',
        body:
            'A job at ${job['company_name']} matches your skills with a ${(matchScore * 100).round()}% fit score.',
        type: 'career_fit',
        data: {
          'jobId': job['id'],
          'jobTitle': job['title'],
          'companyName': job['company_name'],
          'matchScore': matchScore,
        },
      );

      return docRef.id;
    } catch (e) {
      print('Failed to save notification: $e');
      return '';
    }
  }

  Future<void> _dismissJob(String jobId, int index) async {
    try {
      // Add to dismissed collection
      await _firestore.collection('DismissedJobs').add({
        'candidateId': _auth.currentUser!.uid,
        'jobId': jobId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Delete associated notifications
      final notifsQuery = await _firestore
          .collection('Notifications')
          .where('jobId', isEqualTo: jobId)
          .where('candidateId', isEqualTo: _auth.currentUser!.uid)
          .get();

      for (var doc in notifsQuery.docs) {
        await doc.reference.delete();
      }

      setState(() {
        _matchedJobs.removeAt(index);
        _dismissedJobIds.add(jobId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.close, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Job dismissed from suggestions'),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      print('Error dismissing job: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to dismiss job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _applyForJob(Map<String, dynamic> job, int index) async {
    if (_applicationStatus[job['id']] == 'applied') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You have already applied for this job')),
      );
      return;
    }

    try {
      setState(() {
        // Show loading state on the button
        _applicationStatus[job['id']] = 'loading'; // loading state
      });

      final user = _auth.currentUser;
      if (user == null || _userProfile == null) {
        throw Exception('User not authenticated or profile not loaded');
      }

      // Check if already applied (double-check)
      final existingApplication = await _firestore
          .collection('AppliedCandidates')
          .where('candidateId', isEqualTo: user.uid)
          .where('jobId', isEqualTo: job['id'])
          .limit(1)
          .get();

      if (existingApplication.docs.isNotEmpty) {
        setState(() {
          _applicationStatus[job['id']] = 'applied';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You have already applied for this job')),
        );
        return;
      }

      // Extract required fields from user profile
      final userProfile = _userProfile!;

      // Create application document
      await _firestore.collection('AppliedCandidates').add({
        'applicantEmail': user.email ?? '',
        'applicantName': userProfile['name'] ?? '',
        'applicantPhone': userProfile['phone'] ?? '',
        'applicantProfileUrl': userProfile['profilePicUrl'] ?? '',
        'applicantResumeUrl': userProfile['resumeUrl'] ?? '',
        'appliedAt': FieldValue.serverTimestamp(),
        'candidateId': user.uid,
        'companyName': job['company_name'] ?? '',
        'educations': userProfile['educations'] ?? [],
        'jobId': job['id'],
        'jobTitle': job['title'] ?? '',
        'languages': userProfile['languages'] ?? [],
        'softSkills': userProfile['softSkills'] ?? [],
        'status': 'pending',
        'technicalSkills': userProfile['technicalSkills'] ?? [],
      });

      setState(() {
        _applicationStatus[job['id']] = 'applied';
        _matchedJobs.removeAt(index); // Remove from suggestions after apply
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Successfully applied for the job!'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      print('Error applying for job: $e');
      setState(() {
        _applicationStatus.remove(job['id']); // Reset loading
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply for job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _setupFirebaseListeners() {
    // Listen for new jobs
    _firestore.collection('JobsPosted').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _processNewJob(change.doc);
        }
      }
    });
  }

  Future<void> _processNewJob(DocumentSnapshot jobDoc) async {
    try {
      Map<String, dynamic> job =
          _sanitizeDocument(jobDoc.data() as Map<String, dynamic>);
      job['id'] = jobDoc.id;

      // Skip if job already in matched jobs
      if (_matchedJobs.any((m) => m['job']['id'] == job['id'])) return;

      // Skip if dismissed or applied
      if (_dismissedJobIds.contains(job['id']) ||
          _applicationStatus.containsKey(job['id'])) return;

      // Skip if user profile not loaded
      if (_userProfile == null) return;

      Map<String, dynamic> candidate = _userProfile!;

      // Match with new job
      final response = await _matchingService.matchCandidate(job, candidate);

      if (response is Map<String, dynamic> &&
          response.containsKey('match_score')) {
        final rawMatchScore = response['match_score'] as num? ?? 0.0;
        final double matchScore = rawMatchScore > 1
            ? rawMatchScore / 100.0
            : rawMatchScore.toDouble();

        if (matchScore > 0.4) {
          final existingNotifs = await _firestore
              .collection('Notifications')
              .where('jobId', isEqualTo: job['id'])
              .where('candidateId', isEqualTo: candidate['id'])
              .limit(1)
              .get();

          String notificationId;
          if (existingNotifs.docs.isEmpty) {
            notificationId =
                await _saveNotification(job, candidate, matchScore);

            await _jobNotificationService.sendJobMatchNotification(
              candidateId: candidate['id'],
              job: job,
              matchScore: matchScore,
            );
          } else {
            notificationId = existingNotifs.docs.first.id;
          }

          // Only add if not already present
          if (!_matchedJobs.any((m) => m['job']['id'] == job['id'])) {
            setState(() {
              _matchedJobs.add({
                'notificationId': notificationId,
                'job': job,
                'matchScore': matchScore,
              });
            });
          }
        }
      }
    } catch (e) {
      print('Error processing new job: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'AI-Powered Career Fit Suggestions',
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[600], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _loadUserProfile(), // Retry
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildSuggestionsView(),
    );
  }

  Widget _buildSuggestionsView() {
    return _matchedJobs.isEmpty
        ? Center(
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
                    Icons.work_outline,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "No Career Fit Suggestions",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Your AI-powered suggestions will appear here",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _matchedJobs.length,
            itemBuilder: (context, index) {
              final match = _matchedJobs[index];
              final job = match['job'] as Map<String, dynamic>;
              final matchScore = match['matchScore'] as double;
              final notificationId = match['notificationId'] as String;
              final bool alreadyApplied =
                  _applicationStatus[job['id']] == 'applied';
              final bool isLoading = _applicationStatus[job['id']] == 'loading';
              final jobId = job['id'];

              // Handle description properly
              dynamic rawDesc = job['description'];
              String displayDesc = '';
              if (rawDesc != null) {
                if (rawDesc is String) {
                  displayDesc = rawDesc;
                } else if (rawDesc is Map<String, dynamic>) {
                  // Try to extract position_summary or join some fields
                  displayDesc = rawDesc['position_summary']?.toString() ??
                      (rawDesc['responsibilities'] as List<dynamic>? ?? [])
                          .join(', ') ??
                      rawDesc.toString();
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
                                    job['title'] ?? 'Untitled Job',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
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
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.thumb_up,
                                      size: 16, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${(matchScore * 100).round()}% Fit',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (displayDesc.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Divider(color: Colors.grey[200]),
                          const SizedBox(height: 16),
                          Text(
                            displayDesc,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: isLoading || alreadyApplied
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      decoration: BoxDecoration(
                                        color: alreadyApplied
                                            ? Colors.grey[100]
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: alreadyApplied
                                              ? Colors.grey
                                              : const Color(0xFF10B981),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (isLoading)
                                            const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Color(0xFF10B981)),
                                              ),
                                            )
                                          else
                                            const Icon(Icons.check,
                                                color: Color(0xFF10B981)),
                                          if (!isLoading) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              alreadyApplied
                                                  ? 'Applied'
                                                  : 'Apply Now',
                                              style: TextStyle(
                                                color: alreadyApplied
                                                    ? Colors.grey[600]
                                                    : const Color(0xFF10B981),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669)
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: () => _applyForJob(job, index),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 14),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.thumb_up,
                                                    color: Colors.white,
                                                    size: 20),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Apply Now',
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
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF1D4ED8)
                                    ],
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
                                          builder: (context) =>
                                              JobDetailsViewScreen(
                                                  jobId: jobId),
                                        ),
                                      );
                                    },
                                    child: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 14),
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                size: 20, color: Colors.grey),
                            onPressed: () => _dismissJob(jobId, index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }
}
