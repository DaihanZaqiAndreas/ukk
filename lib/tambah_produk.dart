import 'dart:typed_data'; // Tambahkan ini untuk mendukung bytes gambar
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TambahProdukPage extends StatefulWidget {
  const TambahProdukPage({super.key});

  @override
  State<TambahProdukPage> createState() => _TambahProdukPageState();
}

class _TambahProdukPageState extends State<TambahProdukPage> {
  final _namaController = TextEditingController();
  final _stokController = TextEditingController();
  String? _selectedKategori;
  final List<String> _kategoriList = [
    'Kamera',
    'Laptop',
    'Lensa',
    'Audio',
    'Lainnya',
  ];

  // PERBAIKAN: Gunakan XFile dan Uint8List agar tidak error di Web
  XFile? _pickedFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      // PERBAIKAN: Baca file sebagai bytes
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedFile = pickedFile;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _saveProduct() async {
    // PERBAIKAN: Cek ketersediaan file lewat bytes
    if (_namaController.text.isEmpty ||
        _imageBytes == null ||
        _selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lengkapi semua data dan foto!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload Gambar (Gunakan uploadBinary agar support semua platform)
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('alat_images')
          .uploadBinary(
            fileName,
            _imageBytes!, // Gunakan bytes yang sudah dibaca
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      // 2. Dapatkan URL
      final String imageUrl = supabase.storage
          .from('alat_images')
          .getPublicUrl(fileName);

      // 3. Insert ke Tabel 'alat'
      await supabase.from('alat').insert({
        'nama_alat': _namaController.text.trim(),
        'kategori': _selectedKategori,
        'stok': int.tryParse(_stokController.text) ?? 0,
        'image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil ditambah!")),
        );
        // PERBAIKAN: Kirim nilai 'true' saat kembali
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI TETAP SAMA PERSIS
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Tambah Produk",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 35,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("FOTO PRODUK"),
                    const SizedBox(height: 15),
                    _buildImagePicker(),
                    const SizedBox(height: 30),
                    _buildFieldLabel("Nama Barang"),
                    _buildTextField(_namaController, "Isi Nama Barang"),
                    const SizedBox(height: 20),
                    _buildFieldLabel("Jumlah Stok"),
                    _buildTextField(
                      _stokController,
                      "Isi Stok",
                      isNumber: true,
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel("Kategori"),
                    _buildDropdownField(),
                    const SizedBox(height: 40),
                    _buildSubmitButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PERBAIKAN: Gunakan Image.memory untuk menampilkan gambar
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF4A78D0),
              borderRadius: BorderRadius.circular(20),
              image: _imageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(
                        _imageBytes!,
                      ), // Ganti FileImage dengan MemoryImage
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _imageBytes == null
                ? const Center(
                    child: Icon(Icons.image, size: 80, color: Colors.white),
                  )
                : null,
          ),
          Positioned(
            bottom: -6,
            right: -6,
            child: Container(
              height: 36,
              width: 36,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Color(0xFF4A78D0), size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // --- SISA WIDGET HELPER TETAP SAMA ---
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return Container(
      decoration: _inputBoxDecoration(),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _inputDecoration(hint),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _inputBoxDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedKategori,
          hint: const Text(
            "Pilih Kategori",
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
          icon: const Icon(Icons.expand_more),
          isExpanded: true,
          items: _kategoriList
              .map(
                (val) => DropdownMenuItem(
                  value: val,
                  child: Text(val, style: const TextStyle(fontSize: 13)),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _selectedKategori = value),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A78D0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Simpan",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  BoxDecoration _inputBoxDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: Colors.white,
  );
}
