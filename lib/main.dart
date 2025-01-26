import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:military_officer/views/map/sqlite.dart';
import 'package:military_officer/views/profile/usercontroller.dart';
import 'package:military_officer/views/splash_screen/splash.dart'; // Import SplashScreen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final UserController userController = Get.put(UserController());
  await userController.loadUserFromPreferences();
  await DatabaseHelper().initHive(); // Initialize Hive
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
