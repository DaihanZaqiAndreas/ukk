import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddUserPage extends StatefulWidget {
  const AddUserPage({super.key});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  String _selectedRole = 'peminjam';
  bool _isLoading = false;

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. Daftar ke Auth
      // Di dalam fungsi _register()
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );

      if (res.user != null) {
        await supabase.from('user').insert({
          'id': res.user!.id, // Menggunakan ID dari Auth Supabase
          'nama': _namaController.text.trim(),
          'email': _emailController.text.trim(),
          'role': _selectedRole,
          // Jangan simpan password plain text di tabel public jika tidak sangat terpaksa
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah User Baru")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(labelText: "Nama Lengkap"),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              items: [
                'admin',
                'petugas',
                'peminjam',
              ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _selectedRole = v!),
              decoration: const InputDecoration(labelText: "Role"),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text("Simpan User"),
            ),
          ],
        ),
      ),
    );
  }
}
