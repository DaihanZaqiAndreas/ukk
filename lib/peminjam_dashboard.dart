import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'login.dart';
import 'form_peminjaman.dart';
import 'Daftar_Barang.dart';

// =================================================
// 1. DASHBOARD UTAMA PEMINJAM
// =================================================
class DashboardPeminjamPage extends StatelessWidget {
  const DashboardPeminjamPage({super.key});

  void _handleLogout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF4A78D1),
      body: SafeArea(
        child: Column(
          children: [
            // Header Profile
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 30),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      (user?.email ?? "U")[0].toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A78D1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Selamat Datang,",
                          style: TextStyle(color: Colors.white70),
                        ),
                        Text(
                          user?.email?.split('@')[0] ?? "Peminjam",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () => _handleLogout(context),
                  ),
                ],
              ),
            ),

            // Menu Grid
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
                ),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                  children: [
                    _menuCard(
                      context,
                      "Katalog Alat",
                      Icons.inventory_2,
                      Colors.blue,
                      const InventoryPage(),
                    ),
                    _menuCard(
                      context,
                      "Pinjam Baru",
                      Icons.add_circle,
                      Colors.orange,
                      const FormPeminjamanPage(),
                    ),
                    _menuCard(
                      context,
                      "Pengembalian",
                      Icons.assignment_return,
                      Colors.green,
                      const PengembalianPage(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================
// 2. HALAMAN PENGEMBALIAN (DATA COLUMN FIX)
// =================================================
class PengembalianPage extends StatefulWidget {
  const PengembalianPage({super.key});

  @override
  State<PengembalianPage> createState() => _PengembalianPageState();
}

class _PengembalianPageState extends State<PengembalianPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // --- STREAM YANG SUDAH DIPERBAIKI ---
  // Mengambil semua data user, lalu memfilter status 'dipinjam' di aplikasi
  // Cara ini mengatasi error "Only one filter applied"
  Stream<List<Map<String, dynamic>>> _streamMyLoans() {
    final userId = supabase.auth.currentUser!.id;
    return supabase
        .from('peminjaman')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('tanggal_pinjam')
        .map((data) {
          // Filter Manual di Dart: Hanya ambil yang statusnya 'dipinjam'
          return data.where((item) => item['status'] == 'dipinjam').toList();
        });
  }

  // --- LOGIKA UPDATE STATUS (SESUAI KOLOM DB ANDA) ---
  Future<void> _prosesPengembalian(Map<String, dynamic> item, int denda) async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();

      // 1. Catat ke tabel pengembalian
      // HANYA KOLOM: peminjaman_id, tgl_kembali_aktual, denda
      // (petugas_id dibiarkan null karena ini aksi User, nanti diisi Petugas)
      await supabase.from('pengembalian').insert({
        'peminjaman_id': item['id'],
        'tgl_kembali_aktual': now.toIso8601String(),
        'denda': denda,
      });

      // 2. UPDATE STATUS PEMINJAMAN -> 'dikembalikan'
      await supabase
          .from('peminjaman')
          .update({'status': 'dikembalikan'})
          .eq('id', item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Berhasil dikembalikan. Menunggu verifikasi petugas.",
            ),
            backgroundColor: Colors.green,
          ),
        );
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
        title: const Text(
          "Kembalikan Alat",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: StreamBuilder(
          stream: _streamMyLoans(),
          builder: (context, snapshot) {
            // Handling Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Handling Error
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            final data = snapshot.data ?? [];

            // Handling Kosong
            if (data.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Tidak ada barang yang sedang dipinjam",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];

                // --- LOGIKA TANGGAL (ANTI CRASH) ---
                DateTime deadline = DateTime.now();
                try {
                  if (item['tanggal_kembali_seharusnya'] != null) {
                    deadline = DateTime.parse(
                      item['tanggal_kembali_seharusnya'],
                    );
                  }
                } catch (_) {}

                final now = DateTime.now();
                final terlambat = now.isAfter(deadline);
                final denda = terlambat ? 5000 : 0;

                // --- FETCH DETAIL ALAT ---
                return FutureBuilder(
                  future: supabase
                      .from('alat')
                      .select()
                      .eq('id', item['alat_id'])
                      .maybeSingle(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                        height: 100,
                        child: Center(child: LinearProgressIndicator()),
                      );
                    }

                    final alat = snap.data as Map<String, dynamic>? ?? {};
                    final namaAlat =
                        alat['nama_alat'] ?? "Item #${item['alat_id']}";
                    final imageUrl = alat['image_url'];

                    // TAMPILAN KARTU (UI TETAP SAMA)
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: terlambat
                            ? Border.all(color: Colors.red.shade200, width: 1.5)
                            : null,
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gambar Alat
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey.shade100,
                                  child: imageUrl != null
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) =>
                                              const Icon(Icons.image),
                                        )
                                      : const Icon(
                                          Icons.inventory_2,
                                          color: Colors.blue,
                                          size: 30,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Detail Teks
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      namaAlat,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: terlambat
                                            ? Colors.red.shade50
                                            : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Deadline: ${DateFormat('dd MMM yyyy').format(deadline)}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: terlambat
                                              ? Colors.red
                                              : Colors.blue.shade700,
                                        ),
                                      ),
                                    ),
                                    if (terlambat)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          "Telat! Denda: Rp $denda",
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Tombol Aksi
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: terlambat
                                    ? Colors.red
                                    : const Color(0xFF4A78D1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () => _prosesPengembalian(item, denda),
                              child: Text(
                                terlambat
                                    ? "Bayar & Kembalikan"
                                    : "Kembalikan Sekarang",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
