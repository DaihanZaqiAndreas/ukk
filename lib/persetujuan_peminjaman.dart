import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PersetujuanPeminjamanPage extends StatefulWidget {
  const PersetujuanPeminjamanPage({super.key});

  @override
  State<PersetujuanPeminjamanPage> createState() =>
      _PersetujuanPeminjamanPageState();
}

class _PersetujuanPeminjamanPageState extends State<PersetujuanPeminjamanPage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _futureData;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _futureData = _fetchDataManual();
    });
  }

  // --- LOGIKA DATA ---
  Future<List<Map<String, dynamic>>> _fetchDataManual() async {
    // Select semua kolom dari peminjaman
    final List<dynamic> response = await supabase
        .from('peminjaman')
        .select()
        .eq('status', 'menunggu')
        .order('tanggal_pinjam', ascending: false); // Urutkan dari yang terbaru

    List<Map<String, dynamic>> results = [];

    for (var item in response) {
      Map<String, dynamic> row = Map<String, dynamic>.from(item);

      // Ambil Alat, Stok & Gambar
      try {
        final alat = await supabase
            .from('alat')
            .select('nama_alat, stok, image_url')
            .eq('id', item['alat_id'])
            .single();
        row['alat'] = alat;
      } catch (e) {
        row['alat'] = {'nama_alat': 'ID: ${item['alat_id']}', 'stok': 0};
      }

      // Ambil User
      try {
        final user = await supabase
            .from('user')
            .select('nama, email')
            .eq('id', item['user_id'])
            .single();
        row['pengguna'] = user;
      } catch (e) {
        row['pengguna'] = {'nama': 'User ID: ${item['user_id']}'};
      }

      results.add(row);
    }
    return results;
  }

  Future<void> _updateStatus(
    BuildContext context,
    String id,
    int alatId,
    String status,
  ) async {
    try {
      if (status == 'dipinjam') {
        final alatData = await supabase
            .from('alat')
            .select('stok')
            .eq('id', alatId)
            .single();
        int stokSekarang = alatData['stok'] as int;

        // Ambil jumlah yang diminta user, default 1 jika null
        // Pastikan tabel peminjaman Anda punya kolom 'jumlah'
        // int jumlahMinta = 1; // Atau ambil dari row['jumlah']

        if (stokSekarang <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Stok alat habis!"),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        // Kurangi Stok
        await supabase
            .from('alat')
            .update({'stok': stokSekarang - 1})
            .eq('id', alatId);
      }

      await supabase.from('peminjaman').update({'status': status}).eq('id', id);
      _refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Permintaan berhasil di-${status.toUpperCase()}"),
            backgroundColor: status == 'dipinjam' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Persetujuan Peminjaman",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Terjadi kesalahan memuat data",
                style: TextStyle(color: Colors.grey[600]),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final list = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                return _buildRequestCard(list[index], context);
              },
            ),
          );
        },
      ),
    );
  }

  // --- WIDGET KARTU PERMINTAAN (DENGAN GAMBAR) ---
  Widget _buildRequestCard(Map<String, dynamic> item, BuildContext context) {
    final namaAlat = item['alat']?['nama_alat'] ?? "Alat Tidak Dikenal";
    final stokAlat = item['alat']?['stok'] ?? 0;
    // Mengambil Image URL dari database
    final String? imageUrl = item['alat']?['image_url'];

    final namaUser = item['pengguna']?['nama'] ?? "User Tidak Dikenal";
    final int jumlahPinjam =
        item['jumlah'] ?? 1; // Default 1 jika kolom jumlah null

    final tglPinjam = item['tanggal_pinjam'] != null
        ? DateFormat(
            'd MMM yyyy, HH:mm',
          ).format(DateTime.parse(item['tanggal_pinjam']).toLocal())
        : "-";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. GAMBAR PRODUK ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey.shade100,
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.grey.shade400,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.blue.shade200,
                            size: 30,
                          ),
                  ),
                ),

                const SizedBox(width: 12),

                // --- 2. INFORMASI UTAMA ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Alat
                      Text(
                        namaAlat,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Nama Peminjam & Jumlah
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "$namaUser • $jumlahPinjam Unit",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Indikator Stok Gudang
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: stokAlat > 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: stokAlat > 0
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          stokAlat > 0
                              ? "Stok Gudang: $stokAlat"
                              : "Stok Habis!",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: stokAlat > 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- 3. TANGGAL (Pojok Kanan Atas) ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Diajukan",
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                    Text(
                      tglPinjam.split(',')[0], // Tgl saja
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    Text(
                      tglPinjam.split(',')[1], // Jam saja
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // --- 4. TOMBOL AKSI ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(
                      context,
                      item['id'].toString(),
                      item['alat_id'],
                      'ditolak',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Tolak"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateStatus(
                      context,
                      item['id'].toString(),
                      item['alat_id'],
                      'dipinjam',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("Setuju & Pinjamkan"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.assignment_turned_in_rounded,
              size: 60,
              color: Colors.blue.shade200,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Semua Beres!",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tidak ada permintaan peminjaman\nyang perlu diproses saat ini.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 30),
          TextButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text("Cek Lagi"),
          ),
        ],
      ),
    );
  }
}
