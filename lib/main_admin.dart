import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'firebase_options.dart'; // Run flutterfire configure to generate this
import 'features/admin/presentation/screens/admin_login_screen.dart';
import 'core/theme/app_colors.dart';

import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: Replace with your actual Firebase Options for Web
  // or run `flutterfire configure`
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyAq2Qk_u0TO_TZ9ZZf2uFQxM_71wz75ubI',
      appId: '1:903048437394:web:0792503aab77b554d8504b',
      messagingSenderId: '903048437394',
      projectId: 'thewalkingpet-a1578',
      storageBucket: 'thewalkingpet-a1578.firebasestorage.app',
      authDomain: 'thewalkingpet-a1578.firebaseapp.com',
    ),
  );

  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOGZN Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.montserratTextTheme(),
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
      ),
      home: const AdminLoginScreen(),
    );
  }
}
