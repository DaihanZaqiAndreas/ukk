import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_dashboard.dart';
import 'petugas_dashboard.dart';
import 'peminjam_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(() => _errorText = "Isi email atau sandi terlebih dahulu!");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // 1. Login ke Supabase Auth
      final AuthResponse res =
          await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = res.user;

      if (user != null) {
        // 2. Ambil data role dari tabel 'user'
        // Pastikan nama tabelnya 'user' (sesuai gambar) bukan 'profiles'
        final data = await Supabase.instance.client
            .from('user')
            .select('role')
            .eq('id',
                user.id) // user.id dari Auth harus sama dengan id di tabel user
            .maybeSingle(); // Menggunakan maybeSingle agar tidak error jika data kosong

        if (data == null) {
          setState(() => _errorText = "Data user tidak ditemukan di database.");
          return;
        }

        String role = data['role'] ?? 'peminjam';

        if (!mounted) return;

        // 3. Navigasi berdasarkan Role
        Widget targetPage;
        if (role == 'admin') {
          targetPage = const AdminDashboard();
        } else if (role == 'petugas') {
          targetPage = const PetugasDashboard();
        } else {
          targetPage = const PeminjamDashboard();
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      }
    } on AuthException catch (error) {
      setState(() {
        // Pesan error lebih user-friendly
        _errorText = "Email atau sandi salah!";
      });
    } catch (e) {
      setState(() => _errorText = "Terjadi kesalahan koneksi");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: const TextSpan(
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
                children: [
                  TextSpan(text: "Pinjam "),
                  TextSpan(
                      text: "Alat", style: TextStyle(color: Color(0xFF2196F3))),
                ],
              ),
            ),
            const SizedBox(height: 48),
            const Text("Email", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: "Masukan Email",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Password", style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: "Masukan Password",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 11)),
              ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("Masuk",
                            style: TextStyle(color: Colors.white)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
