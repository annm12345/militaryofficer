import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:military_officer/views/authscreen/login.dart';
import 'package:military_officer/views/home/home.dart';
import 'package:military_officer/views/profile/usercontroller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UserController userController = Get.find();
  Timer? _midnightTimer;
  @override
  void initState() {
    super.initState();
    _checkLastAccess();
    _startMidnightCheck(); // Start the timer to check for the next day
    print("SplashScreen initState called");
    changeScreen(); // Call changeScreen when the widget is initialized
  }

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

  // Creating a method to change screen based on login status
  void changeScreen() {
    Future.delayed(const Duration(seconds: 2), () {
      if (userController.loggedInUser.value != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => Home()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => AuthPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(253, 247, 246, 246),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Image.asset(
                "icon/logo.png",
                width: 200,
                height: 200,
                fit: BoxFit
                    .cover, // Ensures the image covers the entire circular area
              ),
            ),
          ],
        ),
      ),
    );
  }
}
