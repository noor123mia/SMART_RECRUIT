import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/screens/CandidateMatchDetailScreen.dart';
import 'package:flutter_application_2/services/matching_service.dart';
import 'package:percent_indicator/percent_indicator.dart';

class CandidateMatchingScreen extends StatefulWidget {
  final String? jobId;

  const CandidateMatchingScreen({Key? key, this.jobId}) : super(key: key);

  @override
  State<CandidateMatchingScreen> createState() =>
      _CandidateMatchingScreenState();
}

class _CandidateMatchingScreenState extends State<CandidateMatchingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final MatchingService _matchingService;

  Map<String, dynamic>? _selectedJob;
  List<Map<String, dynamic>> _matchedCandidates = [];
  bool _isLoading = true;
  bool _isMatching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _matchingService = MatchingService();
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) {
        _loadData();
      },
    );
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.jobId != null) {
        final jobDoc =
            await _firestore.collection('JobsPosted').doc(widget.jobId).get();

        if (jobDoc.exists) {
          _selectedJob = _sanitizeDocument(jobDoc.data() ?? {});
          _selectedJob!['id'] = jobDoc.id;
        } else {
          _errorMessage = 'Job not found';
        }
      } else {
        final jobsQuery = await _firestore
            .collection('JobsPosted')
            .where('recruiterId', isEqualTo: _auth.currentUser!.uid)
            .limit(1)
            .get();

        if (jobsQuery.docs.isNotEmpty) {
          _selectedJob = _sanitizeDocument(jobsQuery.docs.first.data());
          _selectedJob!['id'] = jobsQuery.docs.first.id;
        } else {
          _errorMessage = 'No jobs found for this recruiter';
        }
      }

      if (_selectedJob != null) {
        await _matchCandidates();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _matchCandidates() async {
    print('Starting _matchCandidates...');
    setState(() {
      _isMatching = true;
      _errorMessage = null;
    });

    try {
      print('Fetching candidates from Firestore...');
      final candidatesQuery =
          await _firestore.collection('JobSeekersProfiles').get();

      print(
          'Candidates query completed. Found ${candidatesQuery.docs.length} candidates.');
      if (candidatesQuery.docs.isEmpty) {
        print('No candidates found in Firestore.');
        setState(() {
          _matchedCandidates = [];
          _errorMessage = 'No candidates found';
        });
        return;
      }

      print('Sanitizing candidate data...');
      List<Map<String, dynamic>> candidates = [];
      for (var doc in candidatesQuery.docs) {
        Map<String, dynamic> data = _sanitizeDocument(doc.data());
        data['id'] = doc.id;
        candidates.add(data);
      }
      print(
          'Sanitized ${candidates.length} candidates. Sample candidate: ${candidates.isNotEmpty ? candidates.first['name'] : 'None'}');

      print(
          'Calling batchMatchCandidates with job ID: ${_selectedJob!['id']} and ${candidates.length} candidates...');
      final response = await _matchingService.batchMatchCandidates(
          _selectedJob!, candidates);
      print('[DEBUG] Selected Job being sent to matching service:');
      print(_selectedJob);
      print(
          '[DEBUG] Candidates being sent to matching service (first 3 items):');
      print(candidates.take(3).toList());
      print(
          'Received response from batchMatchCandidates. Type: ${response.runtimeType}');
      // Print second half of raw response
      final rawResponse =
          response['rawResponse'] ?? 'No raw response available';
      print('Raw Response Body Length: ${rawResponse.length}');
      final midpoint = rawResponse.length ~/ 2;
      print(
          'Raw Response Body [Second Half, from index $midpoint]: ${rawResponse.substring(midpoint)}');
      print('Parsed Response Content: ${response['matches']}');

      if (response is Map<String, dynamic> &&
          response.containsKey('matches') &&
          response['matches'] is List) {
        print('Processing matches from response...');
        _matchedCandidates =
            (response['matches'] as List).cast<Map<String, dynamic>>().toList();
        print(
            'Successfully processed ${_matchedCandidates.length} matched candidates.');
      } else {
        print(
            'Unexpected response format. Expected Map with "matches" key, got: ${response.runtimeType}');
        setState(() {
          _errorMessage = 'Unexpected response format from matching service';
        });
        return;
      }

      if (_matchedCandidates.isNotEmpty) {
        print(
            'Sorting ${_matchedCandidates.length} matched candidates by match_score...');
        _matchedCandidates.sort((a, b) {
          final scoreA = (a['match_score'] as num?)?.toDouble() ?? 0.0;
          final scoreB = (b['match_score'] as num?)?.toDouble() ?? 0.0;
          return scoreB.compareTo(scoreA);
        });
        print(
            'Sorting complete. Top candidate: ${_matchedCandidates.first['candidate']['name']} with score: ${_matchedCandidates.first['match_score']}');
      } else {
        print('No matched candidates after processing.');
      }
    } catch (e) {
      print('Error in _matchCandidates: $e');
      setState(() {
        _errorMessage = 'Error matching candidates: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error matching candidates: $e')),
      );
    } finally {
      print('Finished _matchCandidates. isMatching: false');
      setState(() {
        _isMatching = false;
      });
    }
  }

  Future<void> _selectJob() async {
    try {
      final jobsQuery = await _firestore
          .collection('JobsPosted')
          .where('recruiterId', isEqualTo: _auth.currentUser!.uid)
          .get();

      if (jobsQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No jobs found')),
        );
        return;
      }

      List<Map<String, dynamic>> jobs = [];
      for (var doc in jobsQuery.docs) {
        Map<String, dynamic> data = _sanitizeDocument(doc.data());
        data['id'] = doc.id;
        jobs.add(data);
      }

      final job = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Job'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return ListTile(
                  title: Text(job['title'] ?? 'No Title'),
                  subtitle: Text(job['company_name'] ?? 'Unknown Company'),
                  onTap: () {
                    Navigator.pop(context, job);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );

      if (job != null) {
        setState(() {
          _selectedJob = job;
          _matchedCandidates = [];
        });
        await _matchCandidates();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting job: $e')),
      );
    }
  }

  void _viewCandidateDetails(Map<String, dynamic> match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CandidateMatchDetailScreen(
          candidate: match,
          job: _selectedJob!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Candidate Screening",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _selectedJob == null
                  ? _buildNoJobSelectedState()
                  : _buildMatchingContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoJobSelectedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No job selected',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _selectJob,
            icon: const Icon(Icons.search),
            label: const Text('Select a Job'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingContent() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _selectedJob!['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.swap_horiz),
                      onPressed: _selectJob,
                      tooltip: 'Change Job',
                    ),
                  ],
                ),
                Text(
                  _selectedJob!['company_name'] ?? 'Unknown Company',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _selectedJob!['location'] ?? 'Location not specified',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.work, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _selectedJob!['job_type'] ?? 'Job type not specified',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Matched Candidates: ${_matchedCandidates.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_isMatching)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: _matchCandidates,
                ),
            ],
          ),
        ),
        Expanded(
          child: _isMatching && _matchedCandidates.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Matching candidates...'),
                    ],
                  ),
                )
              : _matchedCandidates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No matching candidates found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildCandidateList(),
        ),
      ],
    );
  }

  Widget _buildCandidateList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matchedCandidates.length,
      itemBuilder: (context, index) {
        final match = _matchedCandidates[index];
        final candidate = match['candidate'] as Map<String, dynamic>? ?? {};

        final rawMatchScore = match['match_score'] as num? ?? 0.0;
        final double matchScore = rawMatchScore > 1
            ? rawMatchScore / 100.0
            : rawMatchScore.toDouble();

        final categoryScores =
            match['category_scores'] as Map<String, dynamic>? ?? {};

        final matchingSkills = match['matching_skills'] != null
            ? List<String>.from(match['matching_skills'] as List)
            : <String>[];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: candidate['profilePicUrl']?.isNotEmpty ??
                              false
                          ? NetworkImage(candidate['profilePicUrl'] as String)
                          : null,
                      child: candidate['profilePicUrl']?.isNotEmpty ?? false
                          ? null
                          : const Icon(Icons.person,
                              size: 30, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate['name'] ?? 'Unknown Candidate',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (candidate['location']?.isNotEmpty ?? false)
                            Text(
                              candidate['location'] as String,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          if (candidate['summary']?.isNotEmpty ?? false)
                            Text(
                              candidate['summary'] as String,
                              style: TextStyle(color: Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        CircularPercentIndicator(
                          radius: 25.0,
                          lineWidth: 5.0,
                          percent: matchScore.clamp(0.0, 1.0),
                          center: Text(
                            '${(matchScore * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          progressColor: matchScore >= 0.7
                              ? Colors.green
                              : matchScore >= 0.5
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Match',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (categoryScores.isNotEmpty) ...[
                  const Text(
                    'Score Breakdown:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoryScores.entries.map((entry) {
                      final scoreName = entry.key
                          .split('_')
                          .map((word) => word.isNotEmpty
                              ? '${word[0].toUpperCase()}${word.substring(1)}'
                              : '')
                          .join(' ');
                      final scoreValue =
                          (entry.value as num?)?.toDouble() ?? 0.0;
                      final scorePercent =
                          scoreValue > 1 ? scoreValue : scoreValue * 100;

                      return Chip(
                        label: Text('$scoreName: ${scorePercent.round()}%'),
                        backgroundColor: scorePercent >= 70
                            ? Colors.green[100]
                            : scorePercent >= 50
                                ? Colors.orange[100]
                                : Colors.red[100],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Matching Skills:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: matchingSkills.isEmpty
                      ? [
                          Chip(
                            label: const Text('No matching skills'),
                            backgroundColor: Colors.grey[200],
                          ),
                        ]
                      : matchingSkills
                          .take(5)
                          .map((skill) => Chip(
                                label: Text(skill),
                                backgroundColor: Colors.blue[50],
                              ))
                          .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Contact functionality not implemented')),
                        );
                      },
                      child: const Text('Contact'),
                    ),
                    ElevatedButton(
                      onPressed: () => _viewCandidateDetails(match),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                      ),
                      child: const Text('View Profile'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
