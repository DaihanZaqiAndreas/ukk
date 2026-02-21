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
  final _formKey = GlobalKey<FormState>();
  String _selectedRole = 'peminjam';
  bool _isLoading = false;
  bool _passwordVisible = false;

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

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (isEdit) {
        // --- LOGIKA EDIT ---
        await supabase
            .from('user')
            .update({
              'nama': _namaController.text.trim(),
              'email': _emailController.text.trim(),
              'role': _selectedRole,
            })
            .eq('id', widget.user!['id']);

        // Update Email Autentikasi (Jika berubah)
        if (_emailController.text.trim() != widget.user!['email']) {
          await supabase.auth.updateUser(
            UserAttributes(email: _emailController.text.trim()),
          );
        }
      } else {
        // --- LOGIKA TAMBAH BARU ---
        final res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
          data: {'nama': _namaController.text.trim(), 'role': _selectedRole},
        );

        if (res.user == null) {
          throw "Gagal membuat akun user";
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEdit
                        ? "Data berhasil diperbarui!"
                        : "User berhasil ditambahkan!",
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Error: ${e.toString()}",
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Color(0xFF1E293B),
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? "Edit Pengguna" : "Tambah Pengguna",
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEdit ? "Perbarui Informasi User" : "Buat Akun Baru",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isEdit
                        ? "Edit data pengguna yang sudah terdaftar"
                        : "Lengkapi form untuk menambahkan user baru",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Form Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informasi Pribadi Section
                    _buildSectionHeader(
                      icon: Icons.badge_outlined,
                      title: "Informasi Pribadi",
                    ),
                    const SizedBox(height: 16),

                    _buildModernTextField(
                      controller: _namaController,
                      label: "Nama Lengkap",
                      hint: "Masukkan nama lengkap",
                      icon: Icons.person_outline_rounded,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama lengkap wajib diisi';
                        }
                        return null;
                      },
                    ),

                    _buildModernTextField(
                      controller: _emailController,
                      label: "Alamat Email",
                      hint: "contoh@email.com",
                      icon: Icons.email_outlined,
                      inputType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email wajib diisi';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value)) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),

                    // Password hanya muncul saat Tambah Baru
                    if (!isEdit) ...[
                      _buildModernTextField(
                        controller: _passController,
                        label: "Password",
                        hint: "Min. 6 karakter",
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        passwordVisible: _passwordVisible,
                        onTogglePassword: () {
                          setState(() => _passwordVisible = !_passwordVisible);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password wajib diisi';
                          }
                          if (value.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Hak Akses Section
                    _buildSectionHeader(
                      icon: Icons.admin_panel_settings_outlined,
                      title: "Hak Akses",
                    ),
                    const SizedBox(height: 16),

                    _buildModernRoleSelector(),

                    const SizedBox(height: 40),

                    // Submit Button
                    _buildSubmitButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool passwordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: isPassword && !passwordVisible,
            keyboardType: inputType,
            validator: validator,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF94A3B8).withOpacity(0.6),
                fontSize: 15,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 22),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        passwordVisible
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: const Color(0xFF64748B),
                        size: 22,
                      ),
                      onPressed: onTogglePassword,
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFEF4444),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernRoleSelector() {
    final roles = [
      {
        'value': 'admin',
        'label': 'Admin',
        'icon': Icons.admin_panel_settings,
        'color': const Color(0xFFEF4444),
        'desc': 'Akses penuh sistem',
      },
      {
        'value': 'petugas',
        'label': 'Petugas',
        'icon': Icons.badge,
        'color': const Color(0xFF3B82F6),
        'desc': 'Kelola peminjaman',
      },
      {
        'value': 'peminjam',
        'label': 'Peminjam',
        'icon': Icons.person,
        'color': const Color(0xFF10B981),
        'desc': 'Akses terbatas',
      },
    ];

    return Column(
      children: roles.map((role) {
        final isSelected = _selectedRole == role['value'];
        return GestureDetector(
          onTap: () => setState(() => _selectedRole = role['value'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? (role['color'] as Color).withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? (role['color'] as Color)
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: (role['color'] as Color).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (role['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    role['icon'] as IconData,
                    color: role['color'] as Color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role['label'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? const Color(0xFF1E293B)
                              : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        role['desc'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (role['color'] as Color)
                          : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                    color: isSelected
                        ? (role['color'] as Color)
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledBackgroundColor: const Color(0xFF94A3B8),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEdit ? Icons.save_rounded : Icons.person_add_rounded,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEdit ? "Simpan Perubahan" : "Tambah Pengguna",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
