import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tambah_produk.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final supabase = Supabase.instance.client;
  
  // Stream data alat dari Supabase
  final Stream<List<Map<String, dynamic>>> _alatStream =
      Supabase.instance.client.from('alat').stream(primaryKey: ['id']).order('id');

  // Fungsi Hapus Data
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

  // Dialog Konfirmasi Hapus
  void _showDeleteDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Barang?"),
        content: const Text("Data yang dihapus tidak dapat dikembalikan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
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
    // KITA GUNAKAN COLUMN (BUKAN SCAFFOLD) AGAR NAVBAR DASHBOARD TIDAK TERTUTUP
    return Column(
      children: [
        // --- BAGIAN HEADER BIRU (SEARCH BAR) ---
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
          color: const Color(0xFF2196F3), // Warna Biru Dashboard
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
                  hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
                  suffixIcon: const Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30), // Search bar bulat
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),

        // --- BAGIAN KONTEN PUTIH (LIST DATA) ---
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC), // Warna latar belakang abu sangat muda
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // 1. TOMBOL TAMBAH & FILTER (POSISI SESUAI PERMINTAAN)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // A. Tombol Tambah (Biru) di Kiri
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const TambahProdukPage()),
                            );
                          },
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text("Tambah", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0), // Biru lebih gelap
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        
                        const SizedBox(width: 10),

                        // B. Dropdown Merek (Style Outline)
                        _buildFilterButton("Merek"),
                        
                        const SizedBox(width: 10),

                        // C. Dropdown Jenis Barang (Style Outline)
                        _buildFilterButton("Jenis Barang"),
                      ],
                    ),
                  ),
                ),

                // 2. HEADER TABEL (Judul Kolom)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text("Foto", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 4, child: Text("Nama Barang", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 1, child: Text("Stok", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text("Aksi", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                    ],
                  ),
                ),

                const SizedBox(height: 5),

                // 3. LIST ITEMS (DATA DARI SUPABASE)
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _alatStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text("Belum ada data barang.", style: TextStyle(color: Colors.grey)));
                      }

                      final items = snapshot.data!;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  // WIDGET TOMBOL FILTER (Putih dengan Border)
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
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_right, size: 16, color: Colors.grey),
        ],
      ),
    );
  }

  // WIDGET ITEM LIST (Baris Data)
  Widget _buildListItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // 1. Gambar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item['image_url'] != null
                ? Image.network(
                    item['image_url'],
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_,__,___) => Container(color: Colors.grey[200], width: 50, height: 50, child: const Icon(Icons.image_not_supported)),
                  )
                : Container(color: Colors.grey[200], width: 50, height: 50, child: const Icon(Icons.inventory_2)),
          ),
          const SizedBox(width: 12),
          
          // 2. Nama & Kategori
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nama_alat'] ?? 'Tanpa Nama',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
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

          // 3. Stok
          Expanded(
            flex: 1,
            child: Text(
              "${item['stok']}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // 4. Aksi (Edit & Hapus)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Tombol Edit (Biru)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                // Tombol Hapus (Merah)
                GestureDetector(
                  onTap: () => _showDeleteDialog(item['id']),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.delete, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}