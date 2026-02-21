import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'login.dart';
import 'form_peminjaman.dart';

class DashboardPeminjamPage extends StatefulWidget {
  const DashboardPeminjamPage({super.key});

  @override
  State<DashboardPeminjamPage> createState() => _DashboardPeminjamPageState();
}

class _DashboardPeminjamPageState extends State<DashboardPeminjamPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> alatList = [];
  List<Map<String, dynamic>> riwayatPeminjaman = [];
  bool isLoading = true;
  String selectedKategori = 'Semua';
  List<String> kategoriList = ['Semua'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final userDataResponse = await supabase
            .from('user')
            .select()
            .eq('id', user.id)
            .single();
        userData = userDataResponse;
      }

      try {
        final kategoriResponse = await supabase
            .from('kategori')
            .select('nama_kategori')
            .order('nama_kategori');
        kategoriList =
            ['Semua'] +
            (kategoriResponse as List)
                .map((e) => e['nama_kategori'] as String)
                .toList();
      } catch (e) {
        kategoriList = ['Semua', 'Kamera', 'Laptop', 'Lensa', 'Audio'];
      }

      await _loadAlat();
      await _loadRiwayatPeminjaman();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAlat() async {
    try {
      var query = supabase.from('alat').select('''
        id, nama_alat, stok, image_url, kategori_id, kategori
      ''');
      query = query.gt('stok', 0);

      final response = await query;
      setState(() {
        alatList = (response as List).cast<Map<String, dynamic>>();
        if (selectedKategori != 'Semua') {
          alatList = alatList.where((alat) {
            final kat = alat['kategori']?.toString().toLowerCase();
            return kat == selectedKategori.toLowerCase();
          }).toList();
        }
      });
    } catch (e) {
      debugPrint('Error loading alat: $e');
    }
  }

  Future<void> _loadRiwayatPeminjaman() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Pastikan menggunakan foreign key yang benar saat join
      final response = await supabase
          .from('peminjaman')
          .select('''
            id, jumlah, tanggal_pinjam, tanggal_kembali_seharusnya, status, denda,
            alat:alat!fk_peminjaman_alat(id, nama_alat, image_url) 
          ''')
          .eq('user_id', user.id)
          .order('id', ascending: false);

      setState(() {
        riwayatPeminjaman = (response as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading riwayat: $e');
    }
  }

  // --- PERBAIKAN LOGIC DATABASE DI SINI ---
  Future<void> _konfirmasiPengembalian(Map<String, dynamic> item) async {
    DateTime deadline = DateTime.now();
    try {
      if (item['tanggal_kembali_seharusnya'] != null) {
        deadline = DateTime.parse(item['tanggal_kembali_seharusnya']);
      }
    } catch (_) {}

    final now = DateTime.now();
    final isTerlambat = now.isAfter(deadline);
    final int dendaEstimasi = isTerlambat ? 5000 : 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kembalikan Barang?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda ingin mengembalikan "${item['alat']['nama_alat']}"?',
            ),
            const SizedBox(height: 12),
            if (isTerlambat)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anda Terlambat!\nDenda: Rp ${NumberFormat('#,###').format(dendaEstimasi)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Text(
                'Status: Tepat Waktu (Tidak ada denda)',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isTerlambat ? Colors.red : Colors.green,
            ),
            child: Text(
              isTerlambat ? 'Bayar & Kembalikan' : 'Kembalikan',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 1. Insert ke tabel pengembalian (agar data tgl_kembali_aktual tersimpan)
        // Pastikan tabel 'pengembalian' ada di Supabase
        await supabase.from('pengembalian').insert({
          'peminjaman_id': item['id'],
          'tgl_kembali_aktual': DateTime.now().toIso8601String(),
          'denda': dendaEstimasi,
        });

        // 2. Update status di tabel peminjaman
        // JANGAN update 'tgl_kembali_aktual' di sini jika kolomnya tidak ada
        await supabase
            .from('peminjaman')
            .update({
              'status': 'dikembalikan', // atau 'selesai' tergantung flow Anda
            })
            .eq('id', item['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Barang berhasil dikembalikan!'),
              backgroundColor: Colors.green,
            ),
          );
          _loadRiwayatPeminjaman();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                _buildAppBar(),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [_buildAlatTab(), _buildRiwayatTab()],
              ),
            ),
    );
  }

  // --- PERBAIKAN UI DI SINI (PADDING STATUS BAR) ---
  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1E88E5),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              // PERBAIKAN: bottom: 70 memberikan ruang agar teks tidak tertutup TabBar putih
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 70),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.end, // Teks di bawah (di atas TabBar)
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Halo,',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            userData?['nama'] ?? 'Peminjam',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // TabBar dengan Background Putih
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1E88E5),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1E88E5),
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Daftar Alat'),
              Tab(text: 'Riwayat Saya'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlatTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.filter_list, color: Color(0xFF1E88E5)),
              const SizedBox(width: 8),
              const Text(
                'Filter:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kategoriList.map((kat) {
                      final isSelected = selectedKategori == kat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(kat),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              selectedKategori = kat;
                              _loadAlat();
                            });
                          },
                          backgroundColor: Colors.grey[100],
                          selectedColor: const Color(0xFF1E88E5),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: alatList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tidak ada alat tersedia',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: alatList.length,
                  itemBuilder: (context, index) {
                    final alat = alatList[index];
                    return _buildAlatCard(alat);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAlatCard(Map<String, dynamic> alat) {
    return Card(
      elevation: 2, // Memberikan bayangan halus
      color: Colors.white, // Background putih sesuai desain
      surfaceTintColor: Colors.white, // Mencegah warna tint pada Material 3
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // Sudut membulat
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. BAGIAN GAMBAR
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                12,
              ), // Padding agar gambar tidak mepet
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: alat['image_url'] != null
                  ? Image.network(
                      alat['image_url'],
                      fit: BoxFit
                          .contain, // Gambar utuh di tengah (bukan cover/crop)
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                    )
                  : const Center(
                      child: Icon(
                        Icons.inventory_2_outlined,
                        size: 40,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),

          // 2. BAGIAN INFORMASI & TOMBOL
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Alat
                Text(
                  alat['nama_alat'] ?? 'Nama Alat',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Info Stok dengan Ikon
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stok: ${alat['stok'] ?? 0}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tombol Pinjam Full Width
                SizedBox(
                  width: double.infinity,
                  height: 38, // Tinggi tombol proporsional
                  child: ElevatedButton(
                    onPressed: () async {
                      // Navigasi ke Form Peminjaman
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FormPeminjamanPage(alat: alat),
                        ),
                      );

                      // Refresh data jika berhasil pinjam
                      if (result == true) {
                        _loadAlat();
                        _loadRiwayatPeminjaman();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5), // Warna Biru
                      foregroundColor: Colors.white, // Teks Putih
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'Pinjam',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

  Widget _buildRiwayatTab() {
    return riwayatPeminjaman.isEmpty
        ? CustomScrollView(
            slivers: [
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum ada riwayat peminjaman',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: riwayatPeminjaman.length,
            itemBuilder: (context, index) {
              final item = riwayatPeminjaman[index];
              return _buildRiwayatCard(item);
            },
          );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> item) {
    final status = item['status'] ?? 'menunggu';
    final alat = item['alat'];
    final alatNama = alat is Map ? alat['nama_alat'] ?? 'Alat' : 'Alat';
    final imageUrl = alat is Map ? alat['image_url'] : null;

    final tglPinjam = item['tanggal_pinjam'] != null
        ? DateFormat('dd MMM').format(DateTime.parse(item['tanggal_pinjam']))
        : '-';

    final deadlineStr = item['tanggal_kembali_seharusnya'] != null
        ? DateFormat(
            'dd MMM yyyy',
          ).format(DateTime.parse(item['tanggal_kembali_seharusnya']))
        : '-';

    DateTime? deadline;
    try {
      if (item['tanggal_kembali_seharusnya'] != null) {
        deadline = DateTime.parse(item['tanggal_kembali_seharusnya']);
      }
    } catch (_) {}

    final isTerlambat =
        deadline != null &&
        DateTime.now().isAfter(deadline) &&
        (status == 'dipinjam' || status == 'pinjam');

    final showReturnButton = (status == 'dipinjam' || status == 'pinjam');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isTerlambat
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl == null
                      ? const Icon(Icons.inventory_2, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              alatNama,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$tglPinjam - $deadlineStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      if (isTerlambat)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '⚠ Terlambat (Denda berjalan)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (showReturnButton) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _konfirmasiPengembalian(item),
                  icon: const Icon(
                    Icons.assignment_return_outlined,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    isTerlambat
                        ? 'Bayar Denda & Kembalikan'
                        : 'Kembalikan Barang',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTerlambat
                        ? Colors.red
                        : const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'menunggu':
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade800;
        label = 'Menunggu';
        break;
      case 'disetujui':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade800;
        label = 'Disetujui';
        break;
      case 'dipinjam':
      case 'pinjam':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        label = 'Dipinjam';
        break;
      case 'dikembalikan':
      case 'selesai':
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade600;
        label = 'Selesai';
        break;
      case 'ditolak':
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        label = 'Ditolak';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.black;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// ===============================
// SETTINGS PAGE
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
            .from('user')
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
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                          "Profil Saya",
                          userData?['email'] ?? "-",
                          const Color(0xFF1E88E5),
                        ),
                        const SizedBox(height: 12),
                        _buildSettingItem(
                          Icons.shield_outlined,
                          "Role",
                          userData?['role']?.toString().toUpperCase() ??
                              "PEMINJAM",
                          Colors.green,
                        ),
                        const SizedBox(height: 35),
                        _buildSectionLabel("LAINNYA"),
                        _buildSettingItem(
                          Icons.info_outline_rounded,
                          "Tentang Aplikasi",
                          "Versi 1.0.0",
                          Colors.orange,
                        ),
                        const SizedBox(height: 35),
                        _buildLogoutButton(context),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                (userData?['nama'] ?? "U")[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userData?['nama'] ?? "Memuat...",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userData?['email'] ?? "...",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    userData?['role']?.toString().toUpperCase() ?? "PEMINJAM",
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 24,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => _handleLogout(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.red.shade600,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade200, width: 1.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: 22, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Text(
              "Keluar dari Akun",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
