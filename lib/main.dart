import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart'; // Pastikan Anda memindahkan class LoginPage ke file ini

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hanya untuk koneksi Supabase
  await Supabase.initialize(
    url: 'https://fwkgwcyjcmvqoijzypes.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ3a2d3Y3lqY212cW9panp5cGVzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAzMTM3MTEsImV4cCI6MjA4NTg4OTcxMX0.9EbMPWnD5W0RWsrheMBYhbTncpOMZYAkqSygUZSKeZE',
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
