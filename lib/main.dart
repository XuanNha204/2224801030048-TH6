import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'controllers/music_controller.dart';
import 'firebase_options.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
    ),
  );
  FirebaseAuth? auth;
  FirebaseFirestore? firestore;
  String? setupError;
  if (const bool.fromEnvironment('FIREBASE_ENABLED')) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      auth = FirebaseAuth.instance;
      firestore = FirebaseFirestore.instance;
    } catch (_) {
      setupError =
          'Không kết nối được Firebase. Kiểm tra cấu hình theo README.md.';
    }
  }
  final controller = MusicController(
    preferences: await SharedPreferences.getInstance(),
    auth: auth,
    firestore: firestore,
    firebaseSetupError: setupError,
  );
  await controller.initialize();
  runApp(SonicApp(controller: controller));
}

class SonicApp extends StatelessWidget {
  const SonicApp({super.key, required this.controller});
  final MusicController controller;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sonic • Âm nhạc của bạn',
    debugShowCheckedModeBanner: false,
    theme: sonicTheme,
    home: HomeScreen(controller: controller),
  );
}
