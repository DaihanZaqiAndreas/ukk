import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart'; // Pastikan Anda memindahkan class LoginPage ke file ini

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hanya untuk koneksi Supabase
  await Supabase.initialize(
    url: 'https://obglxpxcpgwpbzhoxbcl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9iZ2x4cHhjcGd3cGJ6aG94YmNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0MzE2MDUsImV4cCI6MjA4NDAwNzYwNX0.7mAHFxTYPTI5kXIEAIgHbY0jFTOrqvTIjyqWlID4nFA',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Peminjaman Alat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(), // Langsung arahkan ke halaman login
    );
  }
}
