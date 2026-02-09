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
  final supabase = Supabase.instance.client;

  String? _selectedKategori;
  
  // List kategori dinamis (bukan final lagi)
  List<String> _kategoriList = [];

  XFile? _pickedFile;
  Uint8List? _imageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // Ambil data kategori saat aplikasi dibuka
  }

  // --- 1. AMBIL KATEGORI DARI DATABASE ---
  Future<void> _fetchCategories() async {
    try {
      final response = await supabase.from('kategori').select('nama_kategori').order('nama_kategori');
      
      if (mounted) {
        setState(() {
          _kategoriList = (response as List)
              .map((e) => e['nama_kategori'] as String)
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetch kategori: $e");
      // Fallback jika database belum siap
      setState(() {
        _kategoriList = ['Kamera', 'Laptop', 'Lensa', 'Audio', 'Lainnya'];
      });
    }
  }

  // --- 2. TAMBAH KATEGORI BARU ---
  Future<void> _addNewCategory(String newCategory) async {
    if (newCategory.isEmpty) return;

    try {
      // Simpan ke Supabase
      await supabase.from('kategori').insert({'nama_kategori': newCategory});

      // Update UI: Tambah ke list & Langsung Pilih
      setState(() {
        _kategoriList.add(newCategory);
        _selectedKategori = newCategory; // <--- INI YG MEMBUAT OTOMATIS TERPILIH
      });

      if (mounted) {
        Navigator.pop(context); // Tutup dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kategori baru ditambahkan & dipilih!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menambah: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- 3. DIALOG INPUT KATEGORI ---
  void _showAddCategoryDialog() {
    final TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Tambah Kategori", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: catController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: "Nama Kategori Baru...",
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _addNewCategory(catController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  Future<void> _saveProduct() async {
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
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('alat_images').uploadBinary(
            fileName,
            _imageBytes!,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final String imageUrl = supabase.storage
          .from('alat_images')
          .getPublicUrl(fileName);

      await supabase.from('alat').insert({
        'nama_alat': _namaController.text.trim(),
        'kategori': _selectedKategori,
        'stok': int.tryParse(_stokController.text) ?? 0,
        'image_url': imageUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil ditambah!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
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
                    
                    // --- MODIFIKASI: DROPDOWN + TOMBOL TAMBAH ---
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: _showAddCategoryDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700, // Warna pembeda
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    // ------------------------------------------

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
                      image: MemoryImage(_imageBytes!),
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
          items: _kategoriList.map((val) {
            return DropdownMenuItem(
              value: val,
              child: Text(val, style: const TextStyle(fontSize: 13)),
            );
          }).toList(),
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