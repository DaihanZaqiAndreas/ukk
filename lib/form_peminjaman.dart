import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Pastikan add package: intl di pubspec.yaml

class FormPeminjamanPage extends StatefulWidget {
  const FormPeminjamanPage({super.key});

  @override
  State<FormPeminjamanPage> createState() => _FormPeminjamanPageState();
}

class _FormPeminjamanPageState extends State<FormPeminjamanPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Variabel Form
  String? _selectedAlatId;
  DateTime? _selectedDate;
  final TextEditingController _jumlahController = TextEditingController(
    text: '1',
  );
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  bool _isLoading = false;
  int _maxStok = 0; // Untuk validasi jumlah input agar tidak melebihi stok

  // Fungsi Submit
  Future<void> _submitPeminjaman() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "User tidak terdeteksi";

      final jumlah = int.parse(_jumlahController.text);

      // Cek ulang stok di database sebelum insert (untuk keamanan ganda)
      final checkStok = await supabase
          .from('alat')
          .select('stok')
          .eq('id', _selectedAlatId!)
          .single();

      final currentStok = checkStok['stok'] as int;

      if (currentStok < jumlah) {
        throw "Stok tidak mencukupi. Sisa stok: $currentStok";
      }

      // Insert ke tabel peminjaman
      await supabase.from('peminjaman').insert({
        'user_id': user.id,
        'alat_id': _selectedAlatId,
        'tanggal_pinjam': _selectedDate!.toIso8601String(),
        'jumlah': jumlah,
        'status': 'menunggu', // Default status
        'keterangan': _keteranganController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Permintaan peminjaman berhasil dikirim!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Kembali ke dashboard
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

  // Fungsi Pilih Tanggal
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd MMMM yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A78D1),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== HEADER =====
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 15),
                const Text(
                  "Form Peminjaman",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // ===== FORM CARD =====
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Isi detail peminjaman",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. DROPDOWN ALAT
                      _buildLabel("Pilih Alat"),
                      FutureBuilder(
                        future: supabase
                            .from('alat')
                            .select()
                            .gt('stok', 0)
                            .order('nama_alat'),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: LinearProgressIndicator(),
                            );
                          }
                          final List data = snapshot.data as List;
                          return DropdownButtonFormField<String>(
                            decoration: _inputDecoration(
                              "Pilih alat yang tersedia",
                              Icons.handyman_outlined,
                            ),
                            items: data.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['id'].toString(),
                                child: Text(
                                  "${item['nama_alat']} (Sisa: ${item['stok']})",
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  // Simpan stok max untuk validasi
                                  setState(() {
                                    _maxStok = item['stok'];
                                  });
                                },
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedAlatId = value);
                            },
                            validator: (value) =>
                                value == null ? "Wajib memilih alat" : null,
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // 2. JUMLAH
                      _buildLabel("Jumlah Pinjam"),
                      TextFormField(
                        controller: _jumlahController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          "Masukkan jumlah",
                          Icons.numbers,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return "Wajib diisi";
                          final n = int.tryParse(value);
                          if (n == null || n <= 0) return "Minimal 1";
                          if (_selectedAlatId != null && n > _maxStok) {
                            return "Stok tidak cukup (Max: $_maxStok)";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 3. TANGGAL
                      _buildLabel("Tanggal Peminjaman"),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: _inputDecoration(
                          "Pilih tanggal",
                          Icons.calendar_today_outlined,
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? "Wajib diisi"
                            : null,
                      ),
                      const SizedBox(height: 20),

                      // 4. KETERANGAN
                      _buildLabel("Keperluan (Opsional)"),
                      TextFormField(
                        controller: _keteranganController,
                        maxLines: 3,
                        decoration: _inputDecoration(
                          "Contoh: Untuk praktikum fisika",
                          Icons.notes,
                        ),
                      ),
                      const SizedBox(height: 30),

                      // TOMBOL SUBMIT
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitPeminjaman,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A78D1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Ajukan Peminjaman",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget untuk Label
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E293B),
        ),
      ),
    );
  }

  // Helper Decoration
  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: const Color(0xFF4A78D1)),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF4A78D1), width: 1.5),
      ),
    );
  }
}
