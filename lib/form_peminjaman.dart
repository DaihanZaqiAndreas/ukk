import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class FormPeminjamanPage extends StatefulWidget {
  final Map<String, dynamic> alat;

  const FormPeminjamanPage({super.key, required this.alat});

  @override
  State<FormPeminjamanPage> createState() => _FormPeminjamanPageState();
}

class _FormPeminjamanPageState extends State<FormPeminjamanPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  int jumlah = 1;
  int durasiHari = 3;
  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitPeminjaman() async {
    setState(() => isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw 'User tidak ditemukan';

      final now = DateTime.now();
      final deadline = now.add(Duration(days: durasiHari));

      final insertData = {
        'user_id': user.id,
        'alat_id': widget.alat['id'],
        'jumlah': jumlah,
        'tanggal_pinjam': now.toIso8601String(),
        'tanggal_kembali_seharusnya': deadline.toIso8601String(),
        'status': 'menunggu',
      };

      await supabase.from('peminjaman').insert(insertData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengajuan peminjaman berhasil!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxStok = widget.alat['stok'] ?? 0;
    final tanggalKembali = DateTime.now().add(Duration(days: durasiHari));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF1E88E5),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'alat-${widget.alat['id']}',
                child: Container(
                  decoration: BoxDecoration(
                    image: widget.alat['image_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(widget.alat['image_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: widget.alat['image_url'] == null
                        ? Colors.grey[300]
                        : null,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: widget.alat['image_url'] == null
                        ? const Center(
                            child: Icon(
                              Icons.image,
                              size: 80,
                              color: Colors.white54,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Alat Info Header
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.alat['nama_alat'] ?? 'Nama Alat',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.alat['kategori']?.toString() ??
                                          'Tanpa Kategori',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 16,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Stok: $maxStok',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(thickness: 1, height: 1),

                    // Form Section
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detail Peminjaman',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Jumlah Counter
                          _buildCounterCard(
                            title: 'Jumlah Barang',
                            icon: Icons.shopping_basket_outlined,
                            value: jumlah,
                            min: 1,
                            max: maxStok,
                            onChanged: (val) => setState(() => jumlah = val),
                            suffix: 'unit',
                          ),

                          const SizedBox(height: 16),

                          // Durasi Counter
                          _buildCounterCard(
                            title: 'Durasi Peminjaman',
                            icon: Icons.calendar_month_outlined,
                            value: durasiHari,
                            min: 1,
                            max: 30,
                            onChanged: (val) =>
                                setState(() => durasiHari = val),
                            suffix: 'hari',
                          ),

                          const SizedBox(height: 24),

                          // Summary Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1E88E5).withOpacity(0.1),
                                  const Color(0xFF1565C0).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF1E88E5).withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E88E5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.event_available,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Tanggal Pengembalian',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat(
                                              'dd MMMM yyyy',
                                            ).format(tanggalKembali),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: Colors.amber.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Harap kembalikan tepat waktu untuk menghindari denda',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            height: 100,
                          ), // Space for bottom button
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Bottom Submit Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
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
            height: 56,
            child: ElevatedButton(
              onPressed: isLoading ? null : _submitPeminjaman,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          'Ajukan Peminjaman ($jumlah unit, $durasiHari hari)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounterCard({
    required String title,
    required IconData icon,
    required int value,
    required int min,
    required int max,
    required Function(int) onChanged,
    required String suffix,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF1E88E5)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Minus Button
              Material(
                color: value > min ? const Color(0xFF1E88E5) : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: value > min ? () => onChanged(value - 1) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.remove,
                      color: value > min ? Colors.white : Colors.grey[400],
                      size: 24,
                    ),
                  ),
                ),
              ),

              // Value Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E88E5), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$value',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Plus Button
              Material(
                color: value < max ? const Color(0xFF1E88E5) : Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: value < max ? () => onChanged(value + 1) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.add,
                      color: value < max ? Colors.white : Colors.grey[400],
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (value == max) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Maksimum $max $suffix',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
