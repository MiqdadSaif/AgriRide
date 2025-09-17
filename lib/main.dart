import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'email_password_auth_page.dart';
import 'home_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async
 {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyD-1ZyWJjXND1Vx6Wl_tAYYsaXbEA7r9Lc",
        authDomain: "agritest1-172c9.firebaseapp.com",
        projectId: "agritest1-172c9",
        storageBucket: "agritest1-172c9.firebasestorage.app",
        messagingSenderId: "62168716597",
        appId: "1:62168716597:web:35e010ae3b8230d976e87c",
      ),
    );
  } 
  else
   {
    await Firebase.initializeApp();
   }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget 
{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) 
  {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "AgriRent",
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF34D399),
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF34D399),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}


class AuthWrapper extends StatelessWidget 
{
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center
            
            (
              child: CircularProgressIndicator(color: Color(0xFF34D399)),
            ),
          );
        }

        
        if (snapshot.hasData) 
        {
          return const HomePage();
        }

        
        return const EmailPasswordAuthPage();
      },
    );
  }
}
