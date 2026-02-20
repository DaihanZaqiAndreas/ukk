import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'login.dart';
import 'persetujuan_peminjaman.dart';

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
  Stream<List<Map<String, dynamic>>> _streamRecentHistory() {
    final supabase = Supabase.instance.client;
    return supabase
        .from('peminjaman')
        .stream(primaryKey: ['id'])
        .order('tanggal_pinjam', ascending: false)
        .limit(5); // Ambil 5 data terbaru
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
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _buildStatCard(
                    "Kategori Alat",
                    "${stats?['totalKategori'] ?? '...'}",
                    const Color(0xFF1565C0),
                    Icons.inventory_2_outlined,
                  ),
                  _buildStatCard(
                    "Stok Alat",
                    "${stats?['totalStok'] ?? '...'}",
                    const Color(0xFFEF5350),
                    Icons.construction_outlined,
                  ),
                  _buildStatCard(
                    "Denda",
                    "Rp 0",
                    const Color(0xFF66BB6A),
                    Icons.payments_outlined,
                  ),
                  _buildStatCard(
                    "Peminjaman",
                    "${stats?['totalPinjam'] ?? '...'}",
                    const Color(0xFFFFA726),
                    Icons.assignment_outlined,
                  ),
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
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text("Lihat Semua"),
                          ),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _streamRecentHistory(), // Menggunakan Stream agar auto-update
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Belum ada aktivitas."));
        }

        final items = snapshot.data!;

        return Container(
          width: double.infinity,
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
              columnSpacing: 25,
              columns: const [
                DataColumn(
                  label: Text(
                    'ALAT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'JUMLAH',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'TANGGAL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'STATUS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
              rows: items.map((data) {
                // Format Tanggal
                final tgl = data['tanggal_pinjam'] != null
                    ? DateFormat(
                        'dd/MM HH:mm',
                      ).format(DateTime.parse(data['tanggal_pinjam']).toLocal())
                    : '-';

                // Warna Status
                String status = (data['status'] ?? '-')
                    .toString()
                    .toUpperCase();
                Color statusColor = Colors.grey;
                Color statusBg = Colors.grey.shade100;

                if (status == 'MENUNGGU') {
                  statusColor = Colors.orange;
                  statusBg = Colors.orange.shade50;
                } else if (status == 'DIPINJAM') {
                  statusColor = Colors.blue;
                  statusBg = Colors.blue.shade50;
                } else if (status == 'DIKEMBALIKAN') {
                  statusColor = Colors.purple;
                  statusBg = Colors.purple.shade50;
                } else if (status == 'SELESAI') {
                  statusColor = Colors.green;
                  statusBg = Colors.green.shade50;
                }

                return DataRow(
                  cells: [
                    // KOLOM 1: Nama Alat (Ambil pakai FutureBuilder kecil)
                    DataCell(
                      FutureBuilder(
                        future: Supabase.instance.client
                            .from('alat')
                            .select('nama_alat')
                            .eq('id', data['alat_id'])
                            .maybeSingle(),
                        builder: (context, snap) {
                          if (snap.hasData) {
                            return ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: Text(
                                snap.data!['nama_alat'] ??
                                    'ID: ${data['alat_id']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }
                          return const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                    ),

                    // KOLOM 2: Jumlah
                    DataCell(Center(child: Text("${data['jumlah'] ?? 1}"))),

                    // KOLOM 3: Tanggal
                    DataCell(Text(tgl)),

                    // KOLOM 4: Status
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
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

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
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
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }
}

class PengembalianPage extends StatefulWidget {
  const PengembalianPage({super.key});

  @override
  State<PengembalianPage> createState() => _PengembalianPageState();
}

class _PengembalianPageState extends State<PengembalianPage> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Stream: Hanya tampilkan yang statusnya 'dikembalikan'
  Stream<List<Map<String, dynamic>>> _streamReturns() {
    return supabase
        .from('peminjaman')
        .stream(primaryKey: ['id'])
        .eq('status', 'dikembalikan')
        .order('tanggal_pinjam', ascending: false);
  }

  Future<void> _verifikasi(Map<String, dynamic> item) async {
    setState(() => _isLoading = true);
    try {
      final int toolId = item['alat_id'];
      final int qty = item['jumlah'] ?? 1;
      final int peminjamanId = item['id'];

      // 1. Ambil Stok Terkini
      final toolData = await supabase
          .from('alat')
          .select('stok')
          .eq('id', toolId)
          .single();

      final int currentStock = toolData['stok'] ?? 0;

      // 2. Update Stok (Stok Lama + Jumlah Kembali)
      await supabase
          .from('alat')
          .update({'stok': currentStock + qty})
          .eq('id', toolId);

      // 3. Tandai Peminjaman Selesai
      await supabase
          .from('peminjaman')
          .update({'status': 'selesai'})
          .eq('id', peminjamanId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Barang diterima & Stok dikembalikan ke Gudang"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Background abu muda
      appBar: AppBar(
        title: const Text(
          "Verifikasi Pengembalian",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: _streamReturns(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? [];

          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Tidak ada pengembalian pending",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            separatorBuilder: (c, i) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = data[index];

              // Kita ambil data Alat (Gambar & Nama) di sini
              return FutureBuilder(
                future: supabase
                    .from('alat')
                    .select()
                    .eq('id', item['alat_id'])
                    .maybeSingle(),
                builder: (context, snap) {
                  // Loading state kecil saat ambil data alat
                  if (!snap.hasData) {
                    return const SizedBox(
                      height: 100,
                      child: Center(child: LinearProgressIndicator()),
                    );
                  }

                  final alat = snap.data as Map<String, dynamic>? ?? {};
                  final String namaAlat =
                      alat['nama_alat'] ?? "Item #${item['alat_id']}";
                  final String? imageUrl = alat['image_url'];

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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- BAGIAN GAMBAR (PENGGANTI ICON) ---
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey.shade100,
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              );
                                            },
                                      )
                                    : const Icon(
                                        Icons.image,
                                        size: 30,
                                        color: Colors.blueGrey,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // --- BAGIAN INFORMASI ---
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "Dikembalikan: ${item['jumlah'] ?? 1} Unit",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "User ID: ${item['user_id']}",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // --- TOMBOL TERIMA ---
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () => _verifikasi(item),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              _isLoading
                                  ? "Memproses..."
                                  : "TERIMA BARANG & RESTOCK",
                              style: const TextStyle(
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
