import 'dart:io';
import 'dart:typed_data';
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
  final List<String> _kategoriList = ['Kamera', 'Laptop', 'Lensa', 'Audio', 'Lainnya'];
  
  File? _imageFile;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _saveProduct() async {
    if (_namaController.text.isEmpty || _imageFile == null || _selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lengkapi semua data dan foto!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fileName = 'alat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'produk/$fileName';
      final Uint8List imageBytes = await _imageFile!.readAsBytes();

      await supabase.storage.from('foto-alat').uploadBinary(
        path,
        imageBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      final String imageUrl = supabase.storage.from('foto-alat').getPublicUrl(path);

      await supabase.from('alat').insert({
        'nama_alat': _namaController.text,
        'stok': int.tryParse(_stokController.text) ?? 0,
        'image_url': imageUrl,
        'kategori': _selectedKategori, 
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Barang Berhasil Disimpan")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menyimpan: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "TAMBAH BARANG",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 15),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 35),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("UNGGAH FOTO"),
                    const SizedBox(height: 12),
                    _buildImagePicker(),
                    
                    const SizedBox(height: 30),
                    _buildSectionHeader("DETAIL INFORMASI"),
                    const SizedBox(height: 15),
                    
                    _buildInputLabel("Nama Barang"),
                    _buildTextField(_namaController, "Masukkan nama barang", Icons.inventory_2_outlined),
                    
                    const SizedBox(height: 20),
                    _buildInputLabel("Stok"),
                    _buildTextField(_stokController, "0", Icons.shutter_speed_outlined, isNumber: true),
                    
                    const SizedBox(height: 20),
                    _buildInputLabel("Kategori"),
                    _buildDropdownField(),
                    
                    const SizedBox(height: 45),
                    _buildSubmitButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header per bagian (All Caps Blue)
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF1565C0),
        fontWeight: FontWeight.w900,
        fontSize: 13,
        letterSpacing: 1.5,
      ),
    );
  }

  // Label input kecil
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF475569)),
      ),
    );
  }

  // Box Dropdown
  Widget _buildDropdownField() {
    return Container(
      decoration: _boxDecoration(),
      child: DropdownButtonFormField<String>(
        value: _selectedKategori,
        hint: const Text("Pilih Kategori", style: TextStyle(color: Colors.grey, fontSize: 14)),
        icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: Colors.blue),
        decoration: _inputDecoration(Icons.category_outlined),
        items: _kategoriList.map((String val) {
          return DropdownMenuItem<String>(
            value: val,
            child: Text(val, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: (value) => setState(() => _selectedKategori = value),
      ),
    );
  }

  // Box Image Picker
  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.blue.withOpacity(0.1), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))
          ],
          image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null,
        ),
        child: _imageFile == null 
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_enhance_rounded, size: 40, color: Color(0xFF2196F3)),
                  ),
                  const SizedBox(height: 12),
                  const Text("Klik untuk ambil foto", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                ],
              )
            : null,
      ),
    );
  }

  // Text Field
  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return Container(
      decoration: _boxDecoration(),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _inputDecoration(icon).copyWith(hintText: hint),
      ),
    );
  }

  // Tombol Submit Besar
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
          shadowColor: Colors.blue.withOpacity(0.4),
        ),
        child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("SIMPAN DATA BARANG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
      ),
    );
  }

  // Helper Dekorasi Kontainer
  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
      ],
    );
  }

  // Helper Dekorasi Input
  InputDecoration _inputDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.blue.shade300, size: 22),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      filled: true,
      fillColor: Colors.transparent,
    );
  }
}