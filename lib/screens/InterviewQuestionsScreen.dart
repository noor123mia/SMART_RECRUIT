import 'package:flutter/material.dart';

class AIInterviewQuestionsScreen extends StatefulWidget {
  const AIInterviewQuestionsScreen({Key? key}) : super(key: key);

  @override
  State<AIInterviewQuestionsScreen> createState() =>
      _AIInterviewQuestionsScreenState();
}

class _AIInterviewQuestionsScreenState
    extends State<AIInterviewQuestionsScreen> {
  bool _isGenerating = false;
  final TextEditingController _jobDescriptionController =
      TextEditingController();
  final List<String> _generatedQuestions = [];

  @override
  void dispose() {
    _jobDescriptionController.dispose();
    super.dispose();
  }

  void _generateQuestions() {
    // This would connect to the AI service in a real implementation
    setState(() {
      _isGenerating = true;
    });

    // Simulate API call delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isGenerating = false;
        _generatedQuestions.clear();
        if (_jobDescriptionController.text.isNotEmpty) {
          _generatedQuestions.addAll([
            "Generated question would appear here",
            "Another generated question would appear here",
            "Technical questions based on job description would appear here",
          ]);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Interview Questions'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Interview Questions',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Paste job description below or select a job posting:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _jobDescriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter job description here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateQuestions,
                    icon: _isGenerating
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(
                        _isGenerating ? 'Generating...' : 'Generate Questions'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Import from Job Post'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _generatedQuestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.question_answer_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Questions will appear here',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Generate questions based on job description',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _generatedQuestions.length,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text('${index + 1}'),
                            ),
                            title: Text(_generatedQuestions[index]),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () {},
                                  tooltip: 'Edit Question',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {},
                                  tooltip: 'Add to Question Bank',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_generatedQuestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.save),
                      label: const Text('Save All to Question Bank'),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
