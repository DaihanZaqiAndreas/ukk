import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'login.dart';

// ===============================
// DASHBOARD PETUGAS (UTAMA)
// ===============================
class PetugasDashboard extends StatefulWidget {
  const PetugasDashboard({super.key});

  @override
  State<PetugasDashboard> createState() => _PetugasDashboardState();
}

class _PetugasDashboardState extends State<PetugasDashboard> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardHomeContent(),
    PersetujuanPeminjamanPage(),
    PengembalianPage(),
    LaporanPetugasPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: ''),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_return),
            label: '',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.print_rounded), label: ''),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '',
          ),
        ],
      ),
    );
  }
}

// ===============================
// HOME PETUGAS
// ===============================
// ===============================
// HOME PETUGAS (SUDAH DIPERBAIKI)
// ===============================
class DashboardHomeContent extends StatelessWidget {
  const DashboardHomeContent({super.key});

  // 1. Fungsi Statistik (Tetap)
  Future<Map<String, dynamic>> _getStats() async {
    final supabase = Supabase.instance.client;
    final responses = await Future.wait([
      supabase.from('kategori').select('id'),
      supabase.from('alat').select('stok'),
      supabase.from('peminjaman').select('id').eq('status', 'dipinjam'),
    ]);

    int totalStok = 0;
    for (var item in (responses[1] as List)) {
      totalStok += (item['stok'] as int? ?? 0);
    }

    return {
      'totalKategori': (responses[0] as List).length,
      'totalStok': totalStok,
      'totalPinjam': (responses[2] as List).length,
    };
  }

  // 2. Fungsi Mengambil Riwayat + Nama Alat (Manual Fetch)
  Future<List<Map<String, dynamic>>> _getHistoryData() async {
    final supabase = Supabase.instance.client;
    
    // Ambil 5 peminjaman terakhir
    final List<dynamic> response = await supabase
        .from('peminjaman')
        .select()
        .order('tanggal_pinjam', ascending: false)
        .limit(5);

    List<Map<String, dynamic>> results = [];

    for (var item in response) {
      Map<String, dynamic> row = Map<String, dynamic>.from(item);
      
      // Ambil Nama Alat Manual (Agar tidak error Join)
      try {
        final alat = await supabase
            .from('alat')
            .select('nama_alat')
            .eq('id', item['alat_id'])
            .single();
        row['display_nama_alat'] = alat['nama_alat'];
      } catch (e) {
        row['display_nama_alat'] = 'Alat #${item['alat_id']}';
      }

      // Cek kolom jumlah, jika tidak ada default ke 1
      row['display_jumlah'] = item['jumlah'] ?? 1; 

      results.add(row);
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 60, 24, 10),
              child: Text(
                "Dashboard Petugas",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard("Kategori Alat", "${stats?['totalKategori'] ?? '...'}", const Color(0xFF1565C0), Icons.inventory_2_outlined),
                  _buildStatCard("Stok Alat", "${stats?['totalStok'] ?? '...'}", const Color(0xFFEF5350), Icons.construction_outlined),
                  _buildStatCard("Denda", "Rp 0", const Color(0xFF66BB6A), Icons.payments_outlined),
                  _buildStatCard("Peminjaman", "${stats?['totalPinjam'] ?? '...'}", const Color(0xFFFFA726), Icons.assignment_outlined),
                ],
              ),
            ),
            const SizedBox(height: 10),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Riwayat Peminjaman",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          TextButton(onPressed: () {}, child: const Text("Lihat Semua")),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // PANGGIL WIDGET TABEL DISINI
                      Expanded(child: _buildHistoryTable()),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- TABEL RIWAYAT YANG SUDAH DIUBAH KOLOMNYA ---
  Widget _buildHistoryTable() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getHistoryData(), // Memanggil fungsi manual fetch di atas
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Tidak ada riwayat."));
        }

        final items = snapshot.data!;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
              horizontalMargin: 20,
              columnSpacing: 30,
              columns: const [
                // KOLOM 1: Ganti User ID -> Nama Alat 
                DataColumn(
                  label: Text(
                    'ALAT',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                ),
                // KOLOM 2: Ganti Alat ID -> Jumlah
                DataColumn(
                  label: Text(
                    'JUMLAH',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                ),
                // KOLOM 3: Tanggal (Tetap)
                DataColumn(
                  label: Text(
                    'TGL PINJAM',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                ),
                // KOLOM 4: Status (Tetap)
                DataColumn(
                  label: Text(
                    'STATUS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
              rows: items.map((data) {
                return DataRow(
                  cells: [
                    // DATA 1: Menampilkan Nama Alat
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          data['display_nama_alat'], 
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // DATA 2: Menampilkan Jumlah (Default 1 jika null)
                    DataCell(
                      Center(child: Text("${data['display_jumlah']}")),
                    ),
                    // DATA 3: Tanggal
                    DataCell(
                      Text(
                        DateFormat('dd/MM/yyyy').format(DateTime.parse(data['tanggal_pinjam'])),
                      ),
                    ),
                    // DATA 4: Status Badge
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: data['status'] == 'dipinjam' ? Colors.blue[50] : Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['status'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: data['status'] == 'dipinjam' ? Colors.blue : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}
// ===============================
// HALAMAN PERSETUJUAN PEMINJAMAN (FIXED)
// ===============================
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

  // --- LOGIKA DATA (TETAP SAMA) ---
  Future<List<Map<String, dynamic>>> _fetchDataManual() async {
    final List<dynamic> response = await supabase
        .from('peminjaman')
        .select()
        .eq('status', 'menunggu');

    List<Map<String, dynamic>> results = [];

    for (var item in response) {
      Map<String, dynamic> row = Map<String, dynamic>.from(item);

      // Ambil Alat & Stok
      try {
        final alat = await supabase
            .from('alat')
            .select('nama_alat, stok, image_url') // Ambil stok & gambar juga
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
      BuildContext context, String id, int alatId, String status) async {
    try {
      if (status == 'dipinjam') {
        final alatData = await supabase
            .from('alat')
            .select('stok')
            .eq('id', alatId)
            .single();
        int stokSekarang = alatData['stok'] as int;

        if (stokSekarang <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text("Stok alat habis!"),
                  backgroundColor: Colors.orange),
            );
          }
          return;
        }
        // Kurangi Stok
        await supabase
            .from('alat')
            .update({'stok': stokSekarang - 1}).eq('id', alatId);
      }

      await supabase.from('peminjaman').update({'status': status}).eq('id', id);
      _refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Permintaan berhasil di-${status.toUpperCase()}"),
            backgroundColor: status == 'dipinjam' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
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

  // --- UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Background abu-abu muda
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
                child: Text("Terjadi kesalahan memuat data",
                    style: TextStyle(color: Colors.grey[600])));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          }

          final list = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: list.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(list[index], context);
              },
            ),
          );
        },
      ),
    );
  }

  // 1. WIDGET KARTU PERMINTAAN (UI BARU)
  Widget _buildRequestCard(Map<String, dynamic> item, BuildContext context) {
    final namaAlat = item['alat']?['nama_alat'] ?? "Alat Tidak Dikenal";
    final stokAlat = item['alat']?['stok'] ?? 0;
    final namaUser = item['pengguna']?['nama'] ?? "User Tidak Dikenal";
    final tglPinjam = item['tanggal_pinjam'] != null
        ? DateFormat('d MMM yyyy, HH:mm')
            .format(DateTime.parse(item['tanggal_pinjam']).toLocal())
        : "-";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bagian Header Kartu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Kotak Kiri
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_rounded,
                      color: Colors.blue.shade700, size: 28),
                ),
                const SizedBox(width: 16),
                // Info Utama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        namaAlat,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_rounded,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            namaUser,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: stokAlat > 0
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Sisa Stok Gudang: $stokAlat",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: stokAlat > 0
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tanggal Pojok Kanan
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Diajukan",
                      style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    ),
                    Text(
                      tglPinjam.split(',')[0], // Ambil tanggal saja
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Garis Pemisah
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bagian Tombol Aksi
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Tombol Tolak
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _updateStatus(context,
                        item['id'].toString(), item['alat_id'], 'ditolak'),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text("Tolak"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.shade200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Tombol Setuju
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateStatus(context,
                        item['id'].toString(), item['alat_id'], 'dipinjam'),
                    icon: const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white),
                    label: const Text("Setuju",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. WIDGET EMPTY STATE (JIKA KOSONG)
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inbox_rounded,
                size: 60, color: Colors.blue.shade200),
          ),
          const SizedBox(height: 20),
          Text(
            "Tidak Ada Permintaan",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Saat ini belum ada pengajuan\npeminjaman baru.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 30),
          TextButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text("Muat Ulang"),
          )
        ],
      ),
    );
  }
}

// ===============================
// HALAMAN PENGEMBALIAN
// ===============================
class PengembalianPage extends StatelessWidget {
  const PengembalianPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _BasePage(
      title: "Monitoring Pengembalian",
      child: const Center(
        child: Text(
          "Pantau barang yang sudah / belum dikembalikan",
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

// ===============================
// HALAMAN LAPORAN
// ===============================
class LaporanPetugasPage extends StatelessWidget {
  const LaporanPetugasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _BasePage(
      title: "Laporan",
      child: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text("Cetak Laporan"),
          onPressed: () {
            // TODO: export PDF / Excel
          },
        ),
      ),
    );
  }
}

// ===============================
// HALAMAN PENGATURAN + LOGOUT
// ===============================
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('user') // Pastikan nama tabel benar ('user' atau 'users')
            .select()
            .eq('id', user.id)
            .single();
        setState(() {
          userData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI LOGOUT YANG DIPERBAIKI ---
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Konfirmasi Keluar"),
        content: const Text("Apakah Anda yakin ingin keluar dari akun ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              // 1. Proses Logout dari Supabase
              await supabase.auth.signOut();

              // 2. Cek apakah widget masih aktif sebelum navigasi
              if (context.mounted) {
                // 3. Pindah ke Halaman Login & Hapus semua riwayat navigasi sebelumnya
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()), 
                  (route) => false, // Ini mencegah tombol Back ditekan
                );
              }
            },
            child: const Text("Keluar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 60, 24, 20),
          child: Text(
            "Pengaturan",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 30,
                    ),
                    children: [
                      _buildProfileSection(),
                      const SizedBox(height: 35),
                      _buildSectionLabel("AKUN"),
                      _buildSettingItem(
                        Icons.person_outline_rounded,
                        "Profil",
                        "Petugas",
                        Colors.blue,
                      ),
                      const SizedBox(height: 25),
                      // Tombol Logout dipanggil di sini
                      _buildLogoutButton(context),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.blue.shade50,
            child: Text(
              (userData?['nama'] ?? "U")[0].toUpperCase(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userData?['nama'] ?? "Memuat...",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                userData?['email'] ?? "...",
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // WIDGET TOMBOL LOGOUT
  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _handleLogout(context), // Memanggil fungsi logout
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade600,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.red.shade100),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.logout_rounded, size: 20),
          SizedBox(width: 10),
          Text(
            "Keluar Aplikasi",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ===============================
// TEMPLATE PAGE
// ===============================
class _BasePage extends StatelessWidget {
  final String title;
  final Widget child;

  const _BasePage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

// ===============================
// DUMMY LOGIN PAGE
// ===============================
