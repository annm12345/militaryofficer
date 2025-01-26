import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:military_officer/views/home/home.dart';
import 'package:military_officer/views/map/sqlite.dart';
import 'package:military_officer/views/profile/user.dart';
import 'package:military_officer/views/profile/usercontroller.dart';
import 'package:http/http.dart' as http;

class VerificationPage extends StatefulWidget {
  final String name; // The name of the logged-in user
  final String rank; // The rank of the logged-in user
  final String bc; // The bc of the logged-in user
  final String unit; // The unit of the logged-in user
  final String email; // The email of the logged-in user
  final String mobile; // The mobile of the logged-in user
  final String command; // The command of the logged-in user

  const VerificationPage(
      {Key? key,
      required this.name,
      required this.rank,
      required this.bc,
      required this.unit,
      required this.email,
      required this.mobile,
      required this.command})
      : super(key: key);

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  List<Answer> _savedAnswers = [];
  List<TextEditingController> _answerControllers = [];
  List<bool> _isAnswerCorrect = [];

  @override
  void initState() {
    super.initState();
    _fetchSavedAnswers();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    final url = Uri.parse(
        "http://militarycommand.atwebpages.com/fetch_questionbyemail.php?email=${widget.email}");
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData is List) {
          // Convert JSON data to List<Answer>
          List<Answer> answers = responseData.map((data) {
            return Answer(
              questiontext: data['question'] ?? '', // Handle missing keys
              answer: data['answer'] ?? '',
            );
          }).toList();

          // Save answers to Hive
          await DatabaseHelper().saveAnswers(answers);
          print('Answers saved successfully');
        } else {
          _showAlert('Error', 'Unexpected data format received');
        }
      } else {
        _showAlert('Error',
            'Failed to load questions (Status: ${response.statusCode})');
      }
    } catch (e) {
      _showAlert('Error', 'An error occurred: $e');
    }
  }

// Method to fetch saved answers from Hive
  Future<void> _fetchSavedAnswers() async {
    try {
      var savedAnswers = await DatabaseHelper().getAnswers();
      setState(() {
        _savedAnswers = savedAnswers;
        // Initialize controllers for each answer with existing data
        _answerControllers = List.generate(savedAnswers.length, (index) {
          return TextEditingController(text: '');
        });
        _isAnswerCorrect = List.generate(savedAnswers.length, (index) => false);
      });
    } catch (e) {
      print("Error fetching answers from Hive: $e");
    }
  }

// Method to validate the user's answers
  void _checkAnswers() {
    bool allAnswersCorrect = true;

    for (int i = 0; i < _savedAnswers.length; i++) {
      if (_answerControllers[i].text.trim() != _savedAnswers[i].answer.trim()) {
        setState(() {
          _isAnswerCorrect[i] = false; // Mark answer as incorrect
        });
        allAnswersCorrect = false;
      } else {
        setState(() {
          _isAnswerCorrect[i] = true; // Mark answer as correct
        });
      }
    }

    if (allAnswersCorrect) {
      _showAlert('Success', 'All your answers are correct!');
      final UserController userController = Get.find();
      userController.setUser(User(
        name: widget.name,
        rank: widget.rank,
        bc: widget.bc,
        unit: widget.unit,
        email: widget.email,
        mobile: widget.mobile,
        command: widget.command,
      ));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } else {
      _showAlert(
          'Error', 'Some of your answers are incorrect. Please try again.');
    }
  }

// Method to show dialog with message
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
      appBar: AppBar(
        title: Text('Verification Page'),
      ),
      body: _savedAnswers.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Show each question and allow user to input their answer
                  Expanded(
                    child: ListView.builder(
                      itemCount: _savedAnswers.length,
                      itemBuilder: (context, index) {
                        var answer = _savedAnswers[index];
                        return Card(
                          margin: EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  answer.questiontext,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8.0),
                                TextField(
                                  controller: _answerControllers[index],
                                  decoration: InputDecoration(
                                    hintText: 'Enter your answer...',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Button to submit answers
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: ElevatedButton(
                      onPressed: _checkAnswers,
                      child: Text('Submit Answers'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
