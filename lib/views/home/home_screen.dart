import 'dart:async';

import 'package:flutter/material.dart';
import 'package:military_officer/controllers/home_controller.dart';
import 'package:military_officer/home_buttoms.dart';
import 'package:military_officer/views/authscreen/login.dart';
import 'package:military_officer/views/map/map.dart';
import 'package:military_officer/views/profile/usercontroller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:velocity_x/velocity_x.dart';
import 'package:military_officer/colors.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:military_officer/images.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _checkLastAccess();
    _startMidnightCheck(); // Start the timer to check for the next day
  }

  final UserController userController = Get.find();
// Check the last access date
  Future<void> _checkLastAccess() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get the last access date
    String? lastAccessDate = prefs.getString('lastAccessDate');
    final now = DateTime.now();

    if (lastAccessDate != null) {
      DateTime lastDate = DateTime.parse(lastAccessDate);

      // If the last use was before today, navigate to AuthPage
      if (now.day != lastDate.day ||
          now.month != lastDate.month ||
          now.year != lastDate.year) {
        _navigateToAuthPage();
      }
    }

    // Update the last access date to today
    prefs.setString('lastAccessDate', now.toIso8601String());
  }

// Continuously checks if the day has changed
  void _startMidnightCheck() {
    _midnightTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastAccessDate = prefs.getString('lastAccessDate');
      final now = DateTime.now();

      if (lastAccessDate != null) {
        DateTime lastDate = DateTime.parse(lastAccessDate);

        // Check if the date has changed
        if (now.day != lastDate.day ||
            now.month != lastDate.month ||
            now.year != lastDate.year) {
          _navigateToAuthPage();
        }
      }
    });
  }

// Prevent multiple navigations
  bool _hasNavigated = false;

  void _navigateToAuthPage() {
    if (!_hasNavigated) {
      _hasNavigated = true;
      _midnightTimer?.cancel(); // Stop the timer when navigating
      userController.setUser(null); // Clearing user data
      Get.offAll(() => AuthPage()); // Navigate to AuthPage
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel(); // Clean up the timer
    super.dispose();
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          print('onStatus: $val');
          if (val == 'done') {
            _postSpeech(_text);
          }
        },
        onError: (val) {
          print('onError: $val');
          setState(() {
            _isListening = false;
          });
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _text = val.recognizedWords;
            });
            if (_text.length >= 5) {
              _speech.stop();
              _postSpeech(_text);
            }
          },
          localeId: 'my_MM', // Burmese language code
          listenFor: const Duration(seconds: 7), // Max listening duration
        );
      } else {
        setState(() => _isListening = false);
        _speech.stop();
        _postSpeech(_text);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _postSpeech(_text);
    }
  }

  Future<void> _postSpeech(String text) async {
    if (text.isNotEmpty) {
      final url =
          'https://militaryvoicecommand.000webhostapp.com/text.php?transcript=$text';
      print('Posting to URL: $url');
      try {
        final response = await http.get(Uri.parse(url));
        print('HTTP response status: ${response.statusCode}');
        if (response.statusCode == 200) {
          print('Response: ${response.body}');
          // Check if the response body equals "မြေပုံ"
          if (response.body.trim() == '"မြေပုံ"') {
            // Navigate to MapPage using GetX
            var controller = Get.find<HomeController>();
            controller.updateIndex(1);
            // Restart listening if needed
            _listen();
          } else if (response.body.trim() == '"ကြေးနန်း"') {
            var controller = Get.find<HomeController>();
            controller.updateIndex(2);
            // Restart listening if needed
            _listen();
          } else {
            _listen();
          }
        } else {
          print('Error: ${response.statusCode}');
          _listen();
        }
      } catch (e) {
        print('Exception: $e');
        _listen();
      }
    } else {
      print('No text to post.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGrey,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          width: context.screenWidth,
          height: context.screenHeight,
          child: Column(
            children: [
              Container(
                alignment: Alignment.center,
                height: 60,
                color: lightGrey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: const InputDecoration(
                          suffixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: whiteColor,
                          border: InputBorder.none,
                          hintText: "Search Anything",
                          hintStyle: TextStyle(color: textfieldGrey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Swipper brands
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          2,
                          (index) => HomeButtom(
                            height: context.screenHeight * 0.13,
                            width: context.screenWidth / 2.5,
                            icon: index == 0 ? icforce : icmission,
                            title: index == 0 ? "တပ်များ" : "စစ်ဦးစီး",
                          ),
                        ),
                      ),
                      20.heightBox,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          2,
                          (index) => HomeButtom(
                            height: context.screenHeight * 0.13,
                            width: context.screenWidth / 2.5,
                            icon: index == 0 ? icforce : icmission,
                            title: index == 0 ? "စစ်ရေး" : "စစ်ထောက်",
                          ),
                        ),
                      ),
                      // Additional swiper content can go here
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _listen,
      //   child: Icon(_isListening ? Icons.mic : Icons.mic_none),
      // ),
      bottomSheet: _text.isNotEmpty
          ? Container(
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: Text(
                _text,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : null,
    );
  }
}
