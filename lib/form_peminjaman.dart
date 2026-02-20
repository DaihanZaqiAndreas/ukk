import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:intl/intl.dart'; // Aktifkan jika butuh format tanggal

class FormPeminjamanPage extends StatefulWidget {
  const FormPeminjamanPage({super.key});

  @override
  State<FormPeminjamanPage> createState() => _FormPeminjamanPageState();
}

class _FormPeminjamanPageState extends State<FormPeminjamanPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // --- STATE VARIABLES ---
  String? _selectedAlatId;
  String? _selectedAlatNama;
  String? _selectedAlatImage; // Menyimpan URL gambar
  int _maxStok = 0; // Menyimpan stok maksimal barang terpilih

  final TextEditingController _jumlahController = TextEditingController(
    text: '1',
  );

  // Keranjang Belanja (Menyimpan Map barang)
  List<Map<String, dynamic>> _cart = [];

  bool _isLoading = false;
  List<Map<String, dynamic>> _availableTools = [];

  @override
  void initState() {
    super.initState();
    _fetchTools();
  }

  // Ambil data alat (ID, Nama, Stok, Gambar)
  Future<void> _fetchTools() async {
    final response = await supabase
        .from('alat')
        .select(
          'id, nama_alat, stok, image_url',
        ) // Pastikan kolom image_url diambil
        .gt('stok', 0)
        .order('nama_alat');

    if (mounted) {
      setState(() {
        _availableTools = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  // --- LOGIKA KERANJANG ---
  void _addToCart() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAlatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Pilih alat terlebih dahulu!",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Cek duplikasi
    final isExist = _cart.any((item) => item['id'] == _selectedAlatId);
    if (isExist) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Barang ini sudah ada di daftar!",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _cart.add({
        'id': _selectedAlatId,
        'nama': _selectedAlatNama,
        'jumlah': int.parse(_jumlahController.text),
        'image': _selectedAlatImage, // Masukkan gambar ke cart
      });

      // Reset Input Form Kecil
      _selectedAlatId = null;
      _selectedAlatNama = null;
      _selectedAlatImage = null;
      _maxStok = 0;
      _jumlahController.text = '1';
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  // --- LOGIKA SUBMIT KE DATABASE ---
  Future<void> _submitAll() async {
    if (_cart.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      final now = DateTime.now();
      final deadline = now.add(const Duration(days: 3));

      List<Map<String, dynamic>> dataToInsert = _cart.map((item) {
        return {
          'user_id': user!.id,
          'alat_id': int.parse(item['id']),
          'jumlah': item['jumlah'],
          'tanggal_pinjam': now.toIso8601String(),
          'tanggal_kembali_seharusnya': deadline.toIso8601String(),
          'status': 'menunggu',
        };
      }).toList();

      await supabase.from('peminjaman').insert(dataToInsert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil mengajukan peminjaman!"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A78D1),
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Ajukan Peminjaman",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC), // Warna background soft gray/white
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BAGIAN 1: FORM INPUT ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 10),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Detail Barang",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // DROPDOWN PILIH ALAT
                          DropdownButtonFormField<String>(
                            decoration: _inputDecoration(
                              "Pilih alat...",
                              Icons.handyman_outlined,
                            ),
                            value: _selectedAlatId,
                            isExpanded: true,
                            items: _availableTools.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['id'].toString(),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['nama_alat'],
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Sisa: ${item['stok']}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedAlatId = value;
                                final selectedTool = _availableTools.firstWhere(
                                  (element) =>
                                      element['id'].toString() == value,
                                  orElse: () => {
                                    'nama_alat': 'Unknown',
                                    'stok': 0,
                                    'image_url': null,
                                  },
                                );
                                _selectedAlatNama = selectedTool['nama_alat'];
                                _selectedAlatImage = selectedTool['image_url'];
                                _maxStok = selectedTool['stok'];
                                _jumlahController.text = '1';
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              // INPUT JUMLAH
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _jumlahController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration(
                                    "Jml",
                                    Icons.numbers_rounded,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty)
                                      return 'Wajib';
                                    int? input = int.tryParse(value);
                                    if (input == null || input < 1)
                                      return 'Min 1';
                                    if (_maxStok > 0 && input > _maxStok)
                                      return 'Maks $_maxStok';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // TOMBOL TAMBAH (Kecil di samping)
                              Expanded(
                                flex: 3,
                                child: SizedBox(
                                  height: 55, // Samakan tinggi dengan textfield
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.add_shopping_cart_rounded,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      "Tambah",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4A78D1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: _addToCart,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(
                    thickness: 1,
                    height: 30,
                    color: Color(0xFFE2E8F0),
                  ),

                  // --- BAGIAN 2: DAFTAR KERANJANG ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Daftar Peminjaman",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A78D1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_cart.length} Item",
                            style: const TextStyle(
                              color: Color(0xFF4A78D1),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: _cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_basket_outlined,
                                  size: 60,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Belum ada barang dipilih",
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            itemCount: _cart.length,
                            itemBuilder: (context, index) {
                              final item = _cart[index];
                              return _buildCartItem(item, index);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // --- TOMBOL ACTION BAWAH ---
          Container(
            padding: const EdgeInsets.all(24),
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
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A78D1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF4A78D1).withOpacity(0.4),
                  ),
                  onPressed: (_cart.isEmpty || _isLoading) ? null : _submitAll,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          "Ajukan Sekarang (${_cart.length})",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET ITEM KERANJANG (DENGAN GAMBAR) ---
  Widget _buildCartItem(Map<String, dynamic> item, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // GAMBAR PRODUK
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              color: Colors.grey.shade100,
              child:
                  (item['image'] != null && item['image'].toString().isNotEmpty)
                  ? Image.network(
                      item['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.grey,
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                    )
                  : Icon(
                      Icons.image_not_supported,
                      color: Colors.blue.shade200,
                      size: 30,
                    ),
            ),
          ),

          const SizedBox(width: 16),

          // DETAIL TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nama'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "Jumlah: ${item['jumlah']} Unit",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // TOMBOL HAPUS
          IconButton(
            onPressed: () => _removeFromCart(index),
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: "Hapus",
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF4A78D1), width: 1.5),
      ),
    );
  }
}
