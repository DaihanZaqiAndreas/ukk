import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddUserPage extends StatefulWidget {
  final Map<String, dynamic>? user; // Menerima data user untuk mode Edit

  const AddUserPage({super.key, this.user});

  @override
  State<AddUserPage> createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  String _selectedRole = 'peminjam';
  bool _isLoading = false;

  // Cek apakah sedang dalam mode Edit
  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _namaController.text = widget.user!['nama'] ?? '';
      _emailController.text = widget.user!['email'] ?? '';
      _selectedRole = widget.user!['role'] ?? 'peminjam';
    }
  }

  Future<void> _handleSave() async {
    if (_namaController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nama dan Email wajib diisi!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (isEdit) {
        // --- LOGIKA EDIT ---
        // 1. Update data publik (Nama & Role)
        await supabase
            .from('user')
            .update({
              'nama': _namaController.text.trim(),
              'email': _emailController.text.trim(),
              'role': _selectedRole,
            })
            .eq('id', widget.user!['id']);

        // 2. Update Email Autentikasi (Jika berubah)
        if (_emailController.text.trim() != widget.user!['email']) {
          await supabase.auth.updateUser(
            UserAttributes(email: _emailController.text.trim()),
          );
        }

        // Catatan: Password tidak diubah di sini demi keamanan (bisa buat fitur reset terpisah)
      } else {
        // --- LOGIKA TAMBAH BARU ---
        if (_passController.text.isEmpty) {
          throw "Password wajib diisi untuk user baru";
        }

        final res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
          data: {'nama': _namaController.text.trim(), 'role': _selectedRole},
        );

        // Manual insert ke tabel user jika trigger tidak aktif (jaga-jaga)
        if (res.user != null) {
          // Opsional: Cek jika trigger SQL Anda sudah jalan, bagian ini tidak perlu
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? "Data berhasil diperbarui!"
                  : "User berhasil ditambahkan!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), // Latar belakang abu-abu sangat muda
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[700],
        title: Text(
          isEdit ? "Edit Data Pengguna" : "Tambah Pengguna Baru",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Dekoratif
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.person_outline,
                      size: 45,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isEdit
                        ? "Perbarui informasi user"
                        : "Lengkapi form di bawah",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Form Input
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Informasi Akun",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _buildCustomTextField(
                    controller: _namaController,
                    label: "Nama Lengkap",
                    icon: Icons.badge_outlined,
                  ),

                  _buildCustomTextField(
                    controller: _emailController,
                    label: "Alamat Email",
                    icon: Icons.email_outlined,
                    inputType: TextInputType.emailAddress,
                  ),

                  // Password hanya muncul saat Tambah Baru
                  if (!isEdit)
                    _buildCustomTextField(
                      controller: _passController,
                      label: "Password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),

                  const SizedBox(height: 10),
                  const Text(
                    "Hak Akses",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _buildRoleDropdown(),

                  const SizedBox(height: 40),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                        shadowColor: Colors.blue.withOpacity(0.3),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isEdit
                                  ? "SIMPAN PERUBAHAN"
                                  : "TAMBAH USER SEKARANG",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Helper untuk Text Field yang Cantik
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blue[300]),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // Widget Helper untuk Dropdown Role
  Widget _buildRoleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.blue[300],
          ),
          border: InputBorder.none,
          labelText: "Pilih Role Pengguna",
        ),
        items: ['admin', 'petugas', 'peminjam']
            .map(
              (role) => DropdownMenuItem(
                value: role,
                child: Text(
                  role.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (val) => setState(() => _selectedRole = val!),
      ),
    );
  }
}
