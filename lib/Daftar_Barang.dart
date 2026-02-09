import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tambah_produk.dart';
import 'edit_produk.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final supabase = Supabase.instance.client;

  // --- STATE VARIABLES ---
  String role = 'peminjam';
  String _searchQuery = "";
  
  // --- KATEGORI (Dynamic List) ---
  String _selectedCategory = "Semua";
  // Ubah menjadi variabel biasa agar bisa ditambah
  List<String> _categories = [
    "Semua",
    "Keyboard",
    "Mouse",
    "Headset",
    "Monitor",
    "Lainnya"
  ];

  bool get canManage => role == 'admin' || role == 'petugas';

  late Stream<List<Map<String, dynamic>>> _alatStream;

  @override
  void initState() {
    super.initState();
    _initStream();
    _getUserRole();
    _fetchCategories(); // Ambil kategori dari DB saat mulai
  }

  void _initStream() {
    _alatStream = supabase
        .from('alat')
        .stream(primaryKey: ['id'])
        .order('id');
  }

  // Ambil data kategori real dari database (jika ada tabel kategori)
  Future<void> _fetchCategories() async {
    try {
      final response = await supabase.from('kategori').select('nama_kategori');
      final List<String> loadedCategories = ["Semua"];
      
      for (var item in response) {
        loadedCategories.add(item['nama_kategori']);
      }

      // Gabungkan dengan default jika DB kosong atau error
      if (mounted && loadedCategories.length > 1) {
        setState(() {
          _categories = loadedCategories;
        });
      }
    } catch (e) {
      // Ignore error jika tabel belum siap, pakai default list
    }
  }

  Future<void> _getUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await supabase
          .from('user')
          .select('role')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          role = res['role'] ?? 'peminjam';
        });
      }
    } catch (e) {
      debugPrint("Error fetching role: $e");
    }
  }

  // --- FUNGSI TAMBAH KATEGORI ---
  Future<void> _addNewCategory(String categoryName) async {
    if (categoryName.isEmpty) return;

    try {
      // 1. Simpan ke Database Supabase
      // Pastikan Anda sudah membuat tabel 'kategori' di Supabase
      await supabase.from('kategori').insert({'nama_kategori': categoryName});

      // 2. Update List Lokal (Agar langsung muncul di filter)
      setState(() {
        _categories.add(categoryName);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kategori berhasil ditambahkan!")),
        );
        Navigator.pop(context); // Tutup Dialog
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menambah kategori: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- DIALOG UI TAMBAH KATEGORI ---
  void _showAddCategoryDialog() {
    final TextEditingController catController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Tambah Kategori", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Masukkan nama kategori baru untuk pengelompokan barang.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: catController,
              decoration: InputDecoration(
                hintText: "Contoh: Printer, Kabel...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
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

  Future<void> _deleteAlat(int id) async {
    try {
      await supabase.from('alat').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Barang berhasil dihapus'), backgroundColor: Colors.green),
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

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Barang?"),
        content: const Text("Data yang dihapus tidak dapat dikembalikan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAlat(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A78D1),
      body: Column(
        children: [
          // --- HEADER & SEARCH ---
          _buildHeader(),

          // --- CONTENT BODY ---
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(35),
                  topRight: Radius.circular(35),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // --- BAGIAN KONTROL (FILTER, KATEGORI, TAMBAH) ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // 1. FILTER DROPDOWN
                        Expanded(
                          flex: 2,
                          child: _buildFilterButton(),
                        ),
                        
                        // 2. TOMBOL CONTROL (Hanya Admin/Petugas)
                        if (canManage) ...[
                          const SizedBox(width: 8),
                          // Tombol Tambah Kategori
                          _buildIconButton(
                            icon: Icons.category_rounded,
                            color: Colors.orange.shade700,
                            label: "Kat.",
                            onTap: _showAddCategoryDialog,
                          ),
                          const SizedBox(width: 8),
                          // Tombol Tambah Produk
                          _buildIconButton(
                            icon: Icons.add_rounded,
                            color: const Color(0xFF1565C0),
                            label: "Produk",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const TambahProdukPage()),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),

                  // --- LIST BARANG ---
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _alatStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text("Error: ${snapshot.error}"));
                        }
                        
                        final data = snapshot.data ?? [];
                        
                        // --- LOGIC FILTERING ---
                        final filtered = data.where((item) {
                          final nameMatches = item['nama_alat']
                              .toString()
                              .toLowerCase()
                              .contains(_searchQuery);
                          
                          final categoryMatches = _selectedCategory == "Semua" || 
                              (item['kategori'] ?? "").toString().toLowerCase() == _selectedCategory.toLowerCase();
                              
                          return nameMatches && categoryMatches;
                        }).toList();

                        if (filtered.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildInventoryCard(filtered[index]);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER BARU: TOMBOL ICON KOTAK ---
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER LAINNYA ---
  
  Widget _buildFilterButton() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          setState(() {
            _selectedCategory = value;
          });
        },
        itemBuilder: (BuildContext context) {
          return _categories.map((String choice) {
            return PopupMenuItem<String>(
              value: choice,
              child: Row(
                children: [
                  Icon(
                    _selectedCategory == choice
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _selectedCategory == choice 
                        ? const Color(0xFF4A78D1) 
                        : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    choice,
                    style: TextStyle(
                      fontWeight: _selectedCategory == choice 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                      color: _selectedCategory == choice 
                          ? const Color(0xFF4A78D1) 
                          : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_list_rounded, color: Color(0xFF4A78D1)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _selectedCategory == "Semua" ? "Filter" : _selectedCategory,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4A78D1),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF4A78D1)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Daftar Barang",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: "Cari nama barang...",
              hintStyle: TextStyle(color: Colors.blue.shade100),
              prefixIcon: Icon(Icons.search, color: Colors.blue.shade100),
              filled: true,
              fillColor: const Color(0xFF3b6cc7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final int stok = item['stok'] ?? 0;
    final String? imageUrl = item['image_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 80,
              height: 80,
              color: const Color(0xFFF1F5F9),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported, color: Colors.grey),
                    )
                  : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 30),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nama_alat'] ?? "Tanpa Nama",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item['kategori'] ?? "Umum",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stok > 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stok > 0 ? "Stok: $stok" : "Habis",
                    style: TextStyle(
                      color: stok > 0 ? Colors.green[700] : Colors.red[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            Column(
              children: [
                _actionButton(
                  icon: Icons.edit_rounded,
                  color: Colors.blue.shade50,
                  iconColor: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProdukPage(item: item),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _actionButton(
                  icon: Icons.delete_outline_rounded,
                  color: Colors.red.shade50,
                  iconColor: Colors.red,
                  onTap: () => _showDeleteDialog(item['id']),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Data barang tidak ditemukan",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}