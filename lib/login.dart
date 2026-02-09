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
    // 1. Validasi Input (Tetap sama)
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
      // 2. Login ke Supabase Auth
      final AuthResponse res = await Supabase.instance.client.auth
          .signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      final user = res.user;

      if (user != null) {
        // 3. Ambil data role dari tabel 'user'
        // Gunakan .select() tanpa parameter jika ingin ambil semua,
        // atau .select('role') untuk spesifik kolom role.
        final data = await Supabase.instance.client
            .from('user')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();

        // Cek jika data di tabel 'user' tidak ada meskipun auth berhasil
        if (data == null) {
          await Supabase.instance.client.auth
              .signOut(); // Logout kembali karena data profil tidak ada
          setState(() => _errorText = "Profil user tidak ditemukan!");
          return;
        }

        String role = data['role']?.toString().toLowerCase() ?? 'peminjam';

        // Pastikan widget masih aktif sebelum melakukan navigasi
        if (!mounted) return;

        // 4. Tentukan Halaman Tujuan
        Widget targetPage;
        if (role == 'admin') {
          targetPage = const AdminDashboard();
        } else if (role == 'petugas') {
          targetPage = const PetugasDashboard();
        } else {
          targetPage = const DashboardPeminjamPage();
        }

        // 5. Navigasi
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      }
    } on AuthException catch (error) {
      // Menangkap error spesifik dari Supabase (Password salah, user tidak ditemukan, dll)
      setState(() {
        _errorText = "Email atau sandi salah!";
      });
    } catch (e) {
      // Menangkap error lainnya (masalah internet, dsb)
      setState(() => _errorText = "Gagal terhubung ke server");
      debugPrint("Login Error: $e");
    } finally {
      // Pastikan loading berhenti baik sukses maupun gagal
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
                  color: Colors.black,
                ),
                children: [
                  TextSpan(text: "Pinjam "),
                  TextSpan(
                    text: "Alat",
                    style: TextStyle(color: Color(0xFF2196F3)),
                  ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Masuk",
                            style: TextStyle(color: Colors.white),
                          ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 16,
                    ),
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
