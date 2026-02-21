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

  List<String> _kategoriList = [
    "Keyboard",
    "Mouse",
    "Headset",
    "Monitor",
    "Lainnya",
  ];

  XFile? _pickedFile;
  Uint8List? _imageBytes;
  String? _oldImageUrl;
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _fetchCategoriesFromDB();
  }

  void _loadExistingData() {
    _namaController.text = widget.item['nama_alat'] ?? '';
    _stokController.text = (widget.item['stok'] ?? 0).toString();
    _oldImageUrl = widget.item['image_url'];

    String existingKategori = widget.item['kategori'] ?? 'Lainnya';

    if (!_kategoriList.contains(existingKategori)) {
      _kategoriList.add(existingKategori);
    }
    _selectedKategori = existingKategori;
  }

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
      // Abaikan jika error
    }
  }

  // === SHOW CATEGORY MANAGEMENT DIALOG ===
  void _showCategoryManagement() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryManagementSheet(
        categories: _kategoriList,
        onRefresh: () {
          _fetchCategoriesFromDB();
        },
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

      if (_imageBytes != null) {
        final fileName = 'update_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage
            .from('alat_images')
            .uploadBinary(
              fileName,
              _imageBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );

        finalImageUrl = supabase.storage
            .from('alat_images')
            .getPublicUrl(fileName);
      }

      await supabase
          .from('alat')
          .update({
            'nama_alat': _namaController.text.trim(),
            'kategori': _selectedKategori,
            'stok': int.tryParse(_stokController.text) ?? 0,
            'image_url': finalImageUrl,
          })
          .eq('id', widget.item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Data berhasil diperbarui!")),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
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

                    Row(
                      children: [
                        Expanded(child: _buildDropdownField()),
                        const SizedBox(width: 10),
                        // Tombol Kelola Kategori
                        InkWell(
                          onTap: _showCategoryManagement,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 50,
                            width: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.settings_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),

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
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
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
                  ),
                ],
              ),
              child: const Icon(Icons.edit, color: Color(0xFF4A78D0), size: 20),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: Colors.white,
  );
}

// ========================================
// CATEGORY MANAGEMENT BOTTOM SHEET
// ========================================
class _CategoryManagementSheet extends StatefulWidget {
  final List<String> categories;
  final VoidCallback onRefresh;

  const _CategoryManagementSheet({
    required this.categories,
    required this.onRefresh,
  });

  @override
  State<_CategoryManagementSheet> createState() =>
      _CategoryManagementSheetState();
}

class _CategoryManagementSheetState extends State<_CategoryManagementSheet> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _fullCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('kategori')
          .select('id, nama_kategori')
          .order('nama_kategori');

      setState(() {
        _fullCategories = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _addCategory(String name) async {
    if (name.trim().isEmpty) return;

    try {
      await supabase.from('kategori').insert({'nama_kategori': name.trim()});

      if (mounted) {
        Navigator.pop(context); // Close add dialog
        _loadCategories();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✓ Kategori berhasil ditambahkan"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editCategory(int id, String oldName, String newName) async {
    if (newName.trim().isEmpty || newName.trim() == oldName) return;

    try {
      await supabase
          .from('kategori')
          .update({'nama_kategori': newName.trim()})
          .eq('id', id);

      if (mounted) {
        Navigator.pop(context); // Close edit dialog
        _loadCategories();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✓ Kategori berhasil diperbarui"),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteCategory(int id, String name) async {
    try {
      await supabase.from('kategori').delete().eq('id', id);

      if (mounted) {
        Navigator.pop(context); // Close confirmation dialog
        _loadCategories();
        widget.onRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✓ \"$name\" berhasil dihapus"),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_circle_outline,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Tambah Kategori",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Masukkan nama kategori baru untuk pengelompokan barang.",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "Contoh: Printer, Kabel, Laptop...",
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                prefixIcon: const Icon(Icons.label_outline, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF3B82F6),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Batal",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => _addCategory(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Simpan",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(int id, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, color: Color(0xFFF59E0B)),
            ),
            const SizedBox(width: 12),
            const Text(
              "Edit Kategori",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ubah nama kategori sesuai kebutuhan Anda.",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: "Nama kategori...",
                filled: true,
                fillColor: const Color(0xFFFFFBEB),
                prefixIcon: const Icon(
                  Icons.label_outline,
                  size: 20,
                  color: Color(0xFFF59E0B),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFEF3C7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFEF3C7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFFF59E0B),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Batal",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => _editCategory(id, currentName, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Update",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Hapus Kategori?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: "Apakah Anda yakin ingin menghapus kategori ",
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                children: [
                  TextSpan(
                    text: "\"$name\"",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const TextSpan(text: "?"),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tindakan ini tidak dapat dibatalkan.",
                      style: TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Batal",
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () => _deleteCategory(id, name),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Hapus",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Handle Bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Kelola Kategori",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          "Tambah, edit, atau hapus kategori",
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // List Kategori
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _fullCategories.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: _fullCategories.length,
                      itemBuilder: (context, index) {
                        final cat = _fullCategories[index];
                        return _buildCategoryCard(
                          id: cat['id'],
                          name: cat['nama_kategori'],
                        );
                      },
                    ),
            ),

            // Add Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    label: const Text(
                      "Tambah Kategori Baru",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({required int id, required String name}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.label_outline,
            color: Color(0xFF3B82F6),
            size: 22,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit Button
            IconButton(
              onPressed: () => _showEditDialog(id, name),
              icon: const Icon(Icons.edit_outlined, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFFFBEB),
                foregroundColor: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 8),
            // Delete Button
            IconButton(
              onPressed: () => _showDeleteConfirmation(id, name),
              icon: const Icon(Icons.delete_outline, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.category_outlined,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Belum Ada Kategori",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tambahkan kategori untuk mengelompokkan barang",
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
