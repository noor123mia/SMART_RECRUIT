import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

class CandidateMatchDetailScreen extends StatelessWidget {
  final Map<String, dynamic> candidate;
  final Map<String, dynamic> job;

  const CandidateMatchDetailScreen({
    Key? key,
    required this.candidate,
    required this.job,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Properly handle match score
    final rawMatchScore = candidate['match_score'];
    final double matchScore = rawMatchScore is num
        ? (rawMatchScore > 1 ? rawMatchScore / 100 : rawMatchScore.toDouble())
        : 0.0;

    // Handle category scores properly
    final categoryScores =
        candidate['category_scores'] as Map<String, dynamic>? ?? {};

    // Normalize category scores to ensure they're in the 0-1 range
    double normalizeScore(dynamic score) {
      if (score == null) return 0.0;
      double numScore = score is num ? score.toDouble() : 0.0;
      return numScore > 1 ? numScore / 100 : numScore;
    }

    final skillsScore = normalizeScore(categoryScores['required_skills']);
    final experienceScore = normalizeScore(categoryScores['work_experience']);
    final educationScore = normalizeScore(categoryScores['qualification']);
    final techScore = normalizeScore(categoryScores['tech_stack']);

    // Get candidate data
    final candidateData = candidate['candidate'] as Map<String, dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Candidate Match Details",
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Candidate basic info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: candidateData['profilePicUrl'] != null
                          ? NetworkImage(candidateData['profilePicUrl'])
                          : null,
                      child: candidateData['profilePicUrl'] == null
                          ? const Icon(Icons.person,
                              size: 40, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidateData['name'] ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (candidateData['email'] != null)
                            Row(
                              children: [
                                const Icon(Icons.email,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  candidateData['email'],
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          if (candidateData['phone'] != null)
                            Row(
                              children: [
                                const Icon(Icons.phone,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  candidateData['phone'],
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          if (candidateData['location'] != null)
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  candidateData['location'],
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Match score
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overall Match Score',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: CircularPercentIndicator(
                        radius: 60.0,
                        lineWidth: 10.0,
                        percent: matchScore,
                        center: Text(
                          '${(matchScore * 100).round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        progressColor: matchScore >= 0.7
                            ? Colors.green
                            : matchScore >= 0.5
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Match Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildScoreItem(context, 'Skills', skillsScore, 0.5),
                    _buildScoreItem(
                        context, 'Experience', experienceScore, 0.3),
                    _buildScoreItem(context, 'Education', educationScore, 0.2),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Skills
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Technical Skills',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (candidateData['technicalSkills']
                                      as List<dynamic>?)
                                  ?.isEmpty ??
                              true
                          ? [
                              Chip(
                                label: const Text('No technical skills'),
                                backgroundColor: Colors.grey[200],
                              ),
                            ]
                          : (candidateData['technicalSkills'] as List<dynamic>)
                              .map((skill) => Chip(
                                    label: Text(skill.toString()),
                                    backgroundColor:
                                        (candidate['matching_skills']
                                                        as List<dynamic>?)
                                                    ?.contains(skill) ??
                                                false
                                            ? Colors.green[100]
                                            : Colors.blue[50],
                                  ))
                              .toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Soft Skills',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (candidateData['softSkills'] as List<dynamic>?)
                                  ?.isEmpty ??
                              true
                          ? [
                              Chip(
                                label: const Text('No soft skills'),
                                backgroundColor: Colors.grey[200],
                              ),
                            ]
                          : (candidateData['softSkills'] as List<dynamic>)
                              .map((skill) => Chip(
                                    label: Text(skill.toString()),
                                    backgroundColor: Colors.purple[50],
                                  ))
                              .toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Experience
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Work Experience',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    (candidateData['workExperiences'] as List<dynamic>?)
                                ?.isEmpty ??
                            true
                        ? const Text('No work experience')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: (candidateData['workExperiences']
                                    as List<dynamic>)
                                .length,
                            itemBuilder: (context, index) {
                              final exp = (candidateData['workExperiences']
                                  as List<dynamic>)[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      exp['title'] ?? 'No Title',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      exp['company'] ?? 'No Company',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    Text(
                                      '${exp['startDate'] ?? 'N/A'} - ${exp['endDate'] ?? 'N/A'}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                    if (exp['description'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(exp['description']),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Education
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Education',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    (candidateData['educations'] as List<dynamic>?)?.isEmpty ??
                            true
                        ? const Text('No education information')
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount:
                                (candidateData['educations'] as List<dynamic>)
                                    .length,
                            itemBuilder: (context, index) {
                              final edu = (candidateData['educations']
                                  as List<dynamic>)[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      edu['school'] ?? 'No School',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${edu['degree'] ?? 'No Degree'}, ${edu['field'] ?? 'No Field'}',
                                      style: TextStyle(color: Colors.grey[700]),
                                    ),
                                    Text(
                                      '${edu['startDate'] ?? 'N/A'} - ${edu['endDate'] ?? 'N/A'}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Resume
            if (candidateData['resumeUrl'] != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resume',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Resume viewing not implemented')),
                          );
                        },
                        icon: const Icon(Icons.description),
                        label: const Text('View Resume'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Contact functionality not implemented')),
                      );
                    },
                    icon: const Icon(Icons.email),
                    label: const Text('Contact Candidate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Interview scheduling not implemented')),
                      );
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Schedule Interview'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(
      BuildContext context, String title, double score, double weight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Text(
                '${(score * 100).round()}% (Weight: ${(weight * 100).round()}%)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearPercentIndicator(
            percent: score,
            lineHeight: 10,
            progressColor: score >= 0.7
                ? Colors.green
                : score >= 0.5
                    ? Colors.orange
                    : Colors.red,
            backgroundColor: Colors.grey[200],
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
