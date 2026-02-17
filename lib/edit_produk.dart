import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProdukPage extends StatefulWidget {
  final Map<String, dynamic> item; // Menerima data produk yang akan diedit

  const EditProdukPage({super.key, required this.item});

  @override
  State<EditProdukPage> createState() => _EditProdukPageState();
}

class _EditProdukPageState extends State<EditProdukPage> {
  late TextEditingController _namaController;
  late TextEditingController _stokController;
  String? _selectedKategori;
  
  final List<String> _kategoriList = [
    'Kamera',
    'Laptop',
    'Lensa',
    'Audio',
    'Lainnya',
  ];

  XFile? _pickedFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    // Pre-fill data dari produk yang dipilih
    _namaController = TextEditingController(text: widget.item['nama_alat']);
    _stokController = TextEditingController(text: widget.item['stok'].toString());
    _selectedKategori = widget.item['kategori'];
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedFile = pickedFile;
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _updateProduct() async {
    if (_namaController.text.isEmpty || _stokController.text.isEmpty || _selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Harap isi semua bidang!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = widget.item['image_url']; // Gunakan URL lama secara default

      // Jika ada gambar baru yang dipilih, upload ulang
      if (_imageBytes != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('produk').uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        imageUrl = supabase.storage.from('produk').getPublicUrl(fileName);
      }

      // Update data di tabel 'alat'
      await supabase.from('alat').update({
        'nama_alat': _namaController.text.trim(),
        'stok': int.parse(_stokController.text.trim()),
        'kategori': _selectedKategori,
        'image_url': imageUrl,
      }).eq('id', widget.item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Produk berhasil diperbarui!")),
        );
        Navigator.pop(context, true); // Kembali dengan nilai true untuk refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memperbarui: $e")),
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
        title: const Text("Edit Produk", style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagePicker(),
            const SizedBox(height: 24),
            _buildTextField("Nama Produk", _namaController, "Contoh: Kamera Sony A7III"),
            const SizedBox(height: 16),
            _buildTextField("Stok", _stokController, "Jumlah barang", isNumber: true),
            const SizedBox(height: 16),
            _buildDropdown(),
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _imageBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                )
              : (widget.item['image_url'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(widget.item['image_url'], fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 40, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8),
                        Text("Ubah Foto Produk", style: TextStyle(color: Color(0xFF64748B))),
                      ],
                    )),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 8),
        Container(
          decoration: _inputBoxDecoration(),
          child: TextField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: _inputDecoration(hint),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Kategori", style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _inputBoxDecoration(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedKategori,
              isExpanded: true,
              hint: const Text("Pilih Kategori", style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
              items: _kategoriList.map((String val) {
                return DropdownMenuItem<String>(value: val, child: Text(val, style: const TextStyle(fontSize: 14)));
              }).toList(),
              onChanged: (value) => setState(() => _selectedKategori = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1565C0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("Simpan Perubahan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
    border: InputBorder.none,
  );
}