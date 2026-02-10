import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'login.dart';

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

  // --- LOGIKA LOAD DATA ---
  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      // 1. Get user data
      final user = supabase.auth.currentUser;
      if (user != null) {
        final userDataResponse = await supabase
            .from('user')
            .select()
            .eq('id', user.id)
            .single();
        userData = userDataResponse;
      }

      // 2. Get kategori
      try {
        final kategoriResponse = await supabase
            .from('kategori')
            .select('nama_kategori')
            .order('nama_kategori');
        kategoriList = ['Semua'] +
            (kategoriResponse as List)
                .map((e) => e['nama_kategori'] as String)
                .toList();
      } catch (e) {
        kategoriList = ['Semua', 'Kamera', 'Laptop', 'Lensa', 'Audio'];
      }

      // 3. Load Alat & Riwayat
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
      query = query.gt('stok', 0); // Hanya stok > 0

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

      // PERBAIKAN DI SINI:
      // Kita ubah 'alat:alat_id(...)' menjadi 'alat:alat!fk_peminjaman_alat(...)'
      // Ini memaksa Supabase menggunakan relationship 'fk_peminjaman_alat'
      
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
      // Opsional: Tampilkan snackbar error agar terlihat di layar HP
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: ${e.toString()}')),
        );
      }
    }
  }
  // --- LOGIKA TRANSAKSI ---

  // 1. Ajukan Peminjaman
  Future<void> _ajukanPeminjaman(Map<String, dynamic> alat) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _FormPeminjamanDialog(alat: alat),
    );

    if (result != null) {
      try {
        final user = supabase.auth.currentUser;
        if (user == null) throw 'User tidak ditemukan';

        final now = DateTime.now();
        final deadline = now.add(Duration(days: result['durasi_hari'] ?? 3));
        
        final insertData = {
          'user_id': user.id,
          'alat_id': alat['id'],
          'jumlah': result['jumlah'] ?? 1,
          'tanggal_pinjam': now.toIso8601String(),
          'tanggal_kembali_seharusnya': deadline.toIso8601String(),
          'status': 'menunggu',
        };
        
        await supabase.from('peminjaman').insert(insertData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pengajuan berhasil!'), backgroundColor: Colors.green));
          _loadRiwayatPeminjaman();
          _loadAlat();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gagal: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  // 2. Proses Pengembalian (LOGIKA BARU DARI FILE KEDUA)
  Future<void> _konfirmasiPengembalian(Map<String, dynamic> item) async {
    // Hitung Denda
    DateTime deadline = DateTime.now();
    try {
      if (item['tanggal_kembali_seharusnya'] != null) {
        deadline = DateTime.parse(item['tanggal_kembali_seharusnya']);
      }
    } catch (_) {}

    final now = DateTime.now();
    final isTerlambat = now.isAfter(deadline);
    final int dendaEstimasi = isTerlambat ? 5000 : 0; // Contoh logika denda flat

    // Tampilkan Dialog Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kembalikan Barang?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda ingin mengembalikan "${item['alat']['nama_alat']}"?'),
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
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              )
            else
               const Text('Status: Tepat Waktu (Tidak ada denda)', 
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5)),
            child: const Text('Ya, Kembalikan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _prosesDatabasePengembalian(item, dendaEstimasi);
    }
  }

  Future<void> _prosesDatabasePengembalian(Map<String, dynamic> item, int denda) async {
    try {
      // A. Insert ke tabel pengembalian
      await supabase.from('pengembalian').insert({
        'peminjaman_id': item['id'],
        'tgl_kembali_aktual': DateTime.now().toIso8601String(),
        'denda': denda,
      });

      // B. Update status peminjaman jadi 'dikembalikan'
      await supabase
          .from('peminjaman')
          .update({'status': 'dikembalikan'}) // Atau 'selesai' tergantung aturan database Anda
          .eq('id', item['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Barang berhasil dikembalikan. Menunggu verifikasi petugas.'),
          backgroundColor: Colors.green,
        ));
        _loadRiwayatPeminjaman(); // Refresh list
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // --- UI BUILDER ---
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
                children: [
                  _buildAlatTab(),
                  _buildRiwayatTab(),
                ],
              ),
            ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Selamat Datang,',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Text(
                            userData?['nama'] ?? 'Peminjam',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () async {
                          await supabase.auth.signOut();
                          if (mounted) {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            );
                          }
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
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'Katalog Alat'),
          Tab(text: 'Riwayat & Pengembalian'), // Updated Title
        ],
      ),
    );
  }

  // --- TAB 1: ALAT ---
  Widget _buildAlatTab() {
    return Column(
      children: [
        _buildKategoriFilter(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAlat,
            child: alatList.isEmpty
                ? Center(
                    child: Text('Tidak ada alat tersedia', 
                    style: TextStyle(color: Colors.grey[600])),
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
                    itemBuilder: (context, index) => _buildAlatCard(alatList[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildKategoriFilter() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kategoriList.length,
        itemBuilder: (context, index) {
          final kategori = kategoriList[index];
          final isSelected = kategori == selectedKategori;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(kategori),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => selectedKategori = kategori);
                _loadAlat();
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF1E88E5),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAlatCard(Map<String, dynamic> alat) {
    final stok = alat['stok'] ?? 0;
    final isAvailable = stok > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                image: alat['image_url'] != null
                    ? DecorationImage(image: NetworkImage(alat['image_url']), fit: BoxFit.cover)
                    : null,
              ),
              child: alat['image_url'] == null
                  ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                  : null,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alat['nama_alat'] ?? 'Nama Alat',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    alat['kategori']?.toString() ?? '-',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Stok: $stok',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: isAvailable ? Colors.green : Colors.red,
                        ),
                      ),
                      if (isAvailable)
                        InkWell(
                          onTap: () => _ajukanPeminjaman(alat),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 16),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: RIWAYAT & PENGEMBALIAN (MODERNIZED) ---
  Widget _buildRiwayatTab() {
    return RefreshIndicator(
      onRefresh: _loadRiwayatPeminjaman,
      child: riwayatPeminjaman.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 100),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.history, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Belum ada riwayat', style: TextStyle(color: Colors.grey)),
                    ],
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
            ),
    );
  }

  Widget _buildRiwayatCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? 'menunggu').toString().toLowerCase();
    final alat = item['alat'];
    final alatNama = alat is Map ? alat['nama_alat'] ?? 'Alat' : 'Alat';
    final imageUrl = alat is Map ? alat['image_url'] : null;
    
    // Parse Tanggal
    final tglPinjam = item['tanggal_pinjam'] != null
        ? DateFormat('dd MMM').format(DateTime.parse(item['tanggal_pinjam']))
        : '-';
    
    String deadlineStr = '-';
    bool isTerlambat = false;
    
    if (item['tanggal_kembali_seharusnya'] != null) {
      final deadline = DateTime.parse(item['tanggal_kembali_seharusnya']);
      deadlineStr = DateFormat('dd MMM').format(deadline);
      // Cek terlambat hanya jika status masih 'dipinjam'
      if (status == 'dipinjam' || status == 'pinjam') {
        isTerlambat = DateTime.now().isAfter(deadline);
      }
    }

    // Tombol Aksi logic
    final bool showReturnButton = (status == 'dipinjam' || status == 'pinjam');

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
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
                // Image Thumbnail
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    image: imageUrl != null
                        ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imageUrl == null ? const Icon(Icons.inventory_2, color: Colors.grey) : null,
                ),
                const SizedBox(width: 16),
                // Text Detail
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('$tglPinjam - $deadlineStr', style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                        ],
                      ),
                      if (isTerlambat)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '⚠ Terlambat (Denda berjalan)',
                            style: TextStyle(fontSize: 12, color: Colors.red[700], fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            // ACTION BUTTON AREA
            if (showReturnButton) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _konfirmasiPengembalian(item),
                  icon: const Icon(Icons.assignment_return_outlined, size: 18, color: Colors.white),
                  label: Text(
                    isTerlambat ? 'Bayar Denda & Kembalikan' : 'Kembalikan Barang',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTerlambat ? Colors.red : const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        bgColor = Colors.orange.shade50; textColor = Colors.orange.shade800; label = 'Menunggu'; break;
      case 'disetujui':
        bgColor = Colors.blue.shade50; textColor = Colors.blue.shade800; label = 'Disetujui'; break;
      case 'dipinjam':
      case 'pinjam':
        bgColor = Colors.green.shade50; textColor = Colors.green.shade800; label = 'Dipinjam'; break;
      case 'dikembalikan':
      case 'selesai':
        bgColor = Colors.grey.shade100; textColor = Colors.grey.shade600; label = 'Selesai'; break;
      case 'ditolak':
        bgColor = Colors.red.shade50; textColor = Colors.red.shade800; label = 'Ditolak'; break;
      default:
        bgColor = Colors.grey.shade100; textColor = Colors.black; label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// --- DIALOG FORM PEMINJAMAN ---
class _FormPeminjamanDialog extends StatefulWidget {
  final Map<String, dynamic> alat;
  const _FormPeminjamanDialog({required this.alat});

  @override
  State<_FormPeminjamanDialog> createState() => _FormPeminjamanDialogState();
}

class _FormPeminjamanDialogState extends State<_FormPeminjamanDialog> {
  int jumlah = 1;
  int durasiHari = 3;

  @override
  Widget build(BuildContext context) {
    final maxStok = widget.alat['stok'] ?? 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Form Peminjaman', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.alat['nama_alat'] ?? '', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            _buildCounter('Jumlah', jumlah, 1, maxStok, (val) => setState(() => jumlah = val)),
            const SizedBox(height: 16),
            _buildCounter('Durasi (Hari)', durasiHari, 1, 14, (val) => setState(() => durasiHari = val)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Icon(Icons.event_available, size: 16, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Kembali: ${DateFormat('dd MMM yyyy').format(DateTime.now().add(Duration(days: durasiHari)))}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {'jumlah': jumlah, 'durasi_hari': durasiHari}),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E88E5)),
          child: const Text('Ajukan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildCounter(String label, int val, int min, int max, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
              onPressed: val > min ? () => onChanged(val - 1) : null,
            ),
            Text('$val', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: val < max ? () => onChanged(val + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}