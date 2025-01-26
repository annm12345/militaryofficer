import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:military_officer/views/authscreen/login.dart';
import 'package:military_officer/views/map/sqlite.dart';

class QuestionPage extends StatefulWidget {
  final String email; // The email of the logged-in user

  const QuestionPage({Key? key, required this.email}) : super(key: key);

  @override
  _QuestionPageState createState() => _QuestionPageState();
}

class _QuestionPageState extends State<QuestionPage> {
  List<Map<String, dynamic>> questions = [];
  List<String> answers = [];

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final url =
        Uri.parse('http://militarycommand.atwebpages.com/fetch_question.php');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> responseData = json.decode(response.body);
        setState(() {
          questions = List<Map<String, dynamic>>.from(responseData.take(5));
          answers = List.generate(5, (index) => '');
        });
      } else {
        _showAlert('Error', 'Failed to load questions');
      }
    } catch (e) {
      _showAlert('Error', 'An error occurred: $e');
    }
  }

  Future<void> _submitAnswers() async {
    if (answers.any((answer) => answer.isEmpty)) {
      _showAlert('Error', 'Please answer all questions.');
      return;
    }

    final url =
        Uri.parse('http://militarycommand.atwebpages.com/save_answers.php');
    try {
      var body = {
        'email': widget.email, // Send the email along with the answers
      };

      // Add each answer as answer_<question_id>
      for (int i = 0; i < questions.length; i++) {
        body['answer_${questions[i]["id"]}'] = answers[i];
      }

      var response = await http.post(url, body: body);

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        if (responseData['success']) {
          _showAlert('Success', 'Your answers have been saved.');

          // Create a list of Answer objects to store in Hive
          List<Answer> answerList = [];
          for (int i = 0; i < questions.length; i++) {
            // Add question text and answer to the Answer object
            answerList.add(Answer(
              questiontext: questions[i]['question'], // Store question text
              answer: answers[i], // Store the answer
            ));
          }

          // Save answers to Hive
          await DatabaseHelper().saveAnswers(answerList);

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => AuthPage(),
            ),
          );
        } else {
          _showAlert('Error', 'Failed to save answers.');
        }
      } else {
        _showAlert('Error', 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showAlert('Error', 'An error occurred: $e');
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Answer Questions')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: questions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  for (int i = 0; i < questions.length; i++) ...[
                    Text(
                      questions[i]['question'],
                      style: const TextStyle(fontSize: 16),
                    ),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          answers[i] = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Your answer here',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  ElevatedButton(
                    onPressed: _submitAnswers,
                    child: const Text('Submit Answers'),
                  ),
                ],
              ),
      ),
    );
  }
}
