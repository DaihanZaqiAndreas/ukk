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
  // Variabel untuk Role Management
  String role = 'peminjam'; 
  bool get canManage => role == 'admin' || role == 'petugas';

  // PERBAIKAN 1: Gunakan 'late' agar stream bisa diinisialisasi di initState
  late Stream<List<Map<String, dynamic>>> _alatStream;

  @override
  void initState() {
    super.initState();
    _initStream();
    _getUserRole();
  }

  // PERBAIKAN 2: Fungsi inisialisasi stream agar data real-time
  void _initStream() {
    _alatStream = supabase
        .from('alat')
        .stream(primaryKey: ['id'])
        .order('id');
  }

  // PERBAIKAN 3: Ambil role user yang sedang login dari tabel 'user'
  Future<void> _getUserRole() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final res = await supabase
          .from('user') // Sesuaikan dengan nama tabel di Supabase Anda
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

  Future<void> _deleteAlat(int id) async {
    try {
      await supabase.from('alat').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk berhasil dihapus')),
        );
      }
    } catch (e) {
      debugPrint("Error hapus: $e");
    }
  }

  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Barang?"),
        content: const Text("Data yang dihapus tidak dapat dikembalikan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAlat(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- HEADER SEARCH (UI TETAP) ---
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
          color: const Color(0xFF2196F3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Daftar Barang",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                decoration: InputDecoration(
                  hintText: "Cari Barang...",
                  hintStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  suffixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),

        // --- CONTENT AREA ---
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // PERBAIKAN 4: Tombol Tambah hanya muncul jika Admin/Petugas
                if (canManage) _buildActionButtons(),
                _buildTableHeader(),
                const SizedBox(height: 5),

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
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            "Belum ada data barang.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final items = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return _buildListItem(items[index]);
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
    );
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                (item['image_url'] != null &&
                    item['image_url'].toString().isNotEmpty)
                ? Image.network(
                    item['image_url'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
          const SizedBox(width: 12),

          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nama_alat'] ?? 'Tanpa Nama',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item['kategori'] ?? 'Umum',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 1,
            child: Text(
              "${item['stok'] ?? 0}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // PERBAIKAN 5: Tombol Edit/Hapus hanya muncul untuk yang berwenang
          if (canManage)
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                 _buildActionButton(Icons.edit, Colors.blue, () async {
  final result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EditProdukPage(item: item), // 'item' adalah data dari baris list
    ),
  );
  
  if (result == true) {
    // Optional: Logika tambahan jika ingin refresh manual
    // tapi karena menggunakan Stream, data akan update otomatis.
  }
}),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    Icons.delete,
                    Colors.red,
                    () => _showDeleteDialog(item['id']),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey[200],
      child: const Icon(Icons.inventory_2, size: 20, color: Colors.grey),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              // PERBAIKAN 6: Gunakan await agar saat kembali dari halaman tambah, 
              // data bisa di-refresh jika perlu (walaupun stream otomatis).
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TambahProdukPage()),
              );
            },
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              "Tambah",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildFilterButton("Merek"),
          const SizedBox(width: 10),
          _buildFilterButton("Jenis"),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Text("Foto", style: _headerTextStyle),
          ),
          const Expanded(
            flex: 4,
            child: Text("Nama Barang", style: _headerTextStyle),
          ),
          const Expanded(
            flex: 1,
            child: Text("Stok", style: _headerTextStyle),
          ),
          // Aksi juga disembunyikan di header jika role bukan admin/petugas
          if (canManage)
            const Expanded(
              flex: 2,
              child: Text(
                "Aksi",
                textAlign: TextAlign.right,
                style: _headerTextStyle,
              ),
            ),
        ],
      ),
    );
  }
}

// Konstanta gaya teks header agar kode lebih bersih
const _headerTextStyle = TextStyle(
  color: Colors.blue,
  fontWeight: FontWeight.bold,
  fontSize: 12,
);