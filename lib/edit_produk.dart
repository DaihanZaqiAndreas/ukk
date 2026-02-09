import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProdukPage extends StatefulWidget {
  final Map<String, dynamic> item;
  const EditProdukPage({super.key, required this.item});

  @override
  State<EditProdukPage> createState() => _EditProdukPageState();
}

class _EditProdukPageState extends State<EditProdukPage> {
  final _namaController = TextEditingController();
  final _stokController = TextEditingController();
  String? _selectedKategori;
  
  // Hapus 'final' agar list bisa ditambah secara dinamis
  List<String> _kategoriList = [
    "Keyboard",
    "Mouse",
    "Headset",
    "Monitor",
    "Lainnya"
  ];

  XFile? _pickedFile;
  Uint8List? _imageBytes; // Untuk menampung gambar BARU
  String? _oldImageUrl;   // Untuk menampung URL gambar LAMA
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _fetchCategoriesFromDB(); // Ambil kategori terbaru dari DB
  }

  // --- LOGIKA LOAD DATA ---
  void _loadExistingData() {
    _namaController.text = widget.item['nama_alat'] ?? '';
    _stokController.text = (widget.item['stok'] ?? 0).toString();
    _oldImageUrl = widget.item['image_url'];

    // Validasi kategori agar sesuai dropdown
    String existingKategori = widget.item['kategori'] ?? 'Lainnya';
    
    // Jika kategori tidak ada di list default, tambahkan sementara
    if (!_kategoriList.contains(existingKategori)) {
      _kategoriList.add(existingKategori);
    }
    _selectedKategori = existingKategori;
  }

  // Ambil kategori dari database agar sinkron
  Future<void> _fetchCategoriesFromDB() async {
    try {
      final response = await supabase.from('kategori').select('nama_kategori');
      if (mounted) {
        setState(() {
          for (var item in response) {
            String catName = item['nama_kategori'];
            if (!_kategoriList.contains(catName)) {
              _kategoriList.add(catName);
            }
          }
        });
      }
    } catch (e) {
      // Abaikan jika error / tabel belum ada
    }
  }

  // --- LOGIKA TAMBAH KATEGORI BARU ---
  Future<void> _addNewCategory(String categoryName) async {
    if (categoryName.isEmpty) return;

    try {
      // 1. Simpan ke Database Supabase
      await supabase.from('kategori').insert({'nama_kategori': categoryName});

      // 2. Update List Lokal & Langsung Pilih
      setState(() {
        _kategoriList.add(categoryName);
        _selectedKategori = categoryName; // Otomatis pilih kategori baru
      });

      if (mounted) {
        Navigator.pop(context); // Tutup Dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kategori baru ditambahkan!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddCategoryDialog() {
    final TextEditingController catController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Tambah Kategori", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: catController,
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

  // --- LOGIKA GAMBAR & UPDATE ---
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
    if (_namaController.text.isEmpty || _selectedKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nama dan Kategori wajib diisi!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _oldImageUrl;

      // 1. Cek apakah ada gambar BARU yang dipilih
      if (_imageBytes != null) {
        final fileName = 'update_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Upload gambar baru
        await supabase.storage.from('alat_images').uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        // Dapatkan URL baru
        finalImageUrl = supabase.storage
            .from('alat_images')
            .getPublicUrl(fileName);
      }

      // 2. Update Database Supabase
      await supabase.from('alat').update({
        'nama_alat': _namaController.text.trim(),
        'kategori': _selectedKategori,
        'stok': int.tryParse(_stokController.text) ?? 0,
        'image_url': finalImageUrl, 
      }).eq('id', widget.item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data berhasil diperbarui!")),
        );
        Navigator.pop(context, true); // Kembali dengan sinyal sukses
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal update: $e")),
        );
      }
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
          "Edit Produk",
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
                    _buildTextField(_namaController, "Edit Nama Barang"),
                    const SizedBox(height: 20),
                    _buildFieldLabel("Jumlah Stok"),
                    _buildTextField(
                      _stokController,
                      "Edit Stok",
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
                            height: 50, // Tinggi disamakan dengan field
                            width: 50,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade700,
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
                    // -------------------------------------------

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

  // --- WIDGET LOGIKA GAMBAR ---
  Widget _buildImagePicker() {
    ImageProvider? imageProvider;

    if (_imageBytes != null) {
      imageProvider = MemoryImage(_imageBytes!);
    } else if (_oldImageUrl != null && _oldImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_oldImageUrl!);
    }

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
              image: imageProvider != null
                  ? DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imageProvider == null
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: const Icon(Icons.edit, color: Color(0xFF4A78D0), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

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
        onPressed: _isLoading ? null : _updateProduct,
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
                "Simpan Perubahan",
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
      );
}