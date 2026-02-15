import 'package:flutter/material.dart';
import 'Daftar_Barang.dart'; 
import 'login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tambah_user.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  // Daftar halaman untuk body
  final List<Widget> _pages = [
    const DashboardHomeContent(), 
    const InventoryPage(),        
    const UserManagementPage(),   
    const Center(child: Text("Halaman Laporan", style: TextStyle(color: Colors.white))),
    const SettingsPage(),         
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.blue[700],
          unselectedItemColor: Colors.grey[400],
          showSelectedLabels: false,
          showUnselectedLabels: false,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded, size: 28), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded, size: 28), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.group_rounded, size: 28), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.pie_chart_rounded, size: 28), label: ''),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded, size: 28), label: ''),
          ],
        ),
      ),
    );
  }
}

class DashboardHomeContent extends StatelessWidget {
  const DashboardHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 60, 24, 10),
          child: Text(
            "Dashboard Admin",
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
              _buildStatCard("Kategori Alat", "2", const Color(0xFF1565C0), Icons.inventory_2_outlined),
              _buildStatCard("Stok Alat", "10", const Color(0xFFEF5350), Icons.construction_outlined),
              _buildStatCard("Denda", "Rp 0", const Color(0xFF66BB6A), Icons.payments_outlined),
              _buildStatCard("Peminjaman", "4", const Color(0xFFFFA726), Icons.assignment_outlined),
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
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(35),
                topRight: Radius.circular(35),
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
                        TextButton(onPressed: () {}, child: const Text("Lihat Semua"))
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                              dataRowMaxHeight: 60,
                              horizontalMargin: 20,
                              columnSpacing: 30,
                              columns: const [
                                DataColumn(label: Text('NAMA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                DataColumn(label: Text('ALAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                DataColumn(label: Text('PINJAM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                DataColumn(label: Text('KEMBALI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                              ],
                              rows: [
                                _buildDataRow("Daihan", "Headset", "11/08/2025", "14/08/2025"),
                                _buildDataRow("Ahmad", "Kamera", "12/08/2025", "15/08/2025"),
                                _buildDataRow("Siti", "Laptop", "13/08/2025", "16/08/2025"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ],
      ),
    );
  }

  DataRow _buildDataRow(String nama, String alat, String pinjam, String kembali) {
    return DataRow(cells: [
      DataCell(Text(nama, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      DataCell(Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6)),
        child: Text(alat, style: TextStyle(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.bold)),
      )),
      DataCell(Text(pinjam, style: const TextStyle(fontSize: 12))),
      DataCell(Text(kembali, style: const TextStyle(fontSize: 12))),
    ]);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Konfirmasi Keluar"),
        content: const Text("Apakah Anda yakin ingin keluar dari akun ini?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
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
          child: Text("Pengaturan", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(radius: 50, backgroundColor: Colors.blue[100], child: const Icon(Icons.person, size: 50, color: Color(0xFF1565C0))),
                      const SizedBox(height: 15),
                      const Text("Administrator", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const Text("admin@peminjaman.com", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 35),
                const Text("Akun", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                _buildSettingItem(Icons.person_outline, "Edit Profil", "Ubah nama dan data diri"),
                _buildSettingItem(Icons.lock_outline, "Ubah Kata Sandi", "Kelola keamanan akun"),
                const SizedBox(height: 25),
                const Text("Sistem", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                _buildSettingItem(Icons.notifications_none, "Notifikasi", "Atur pemberitahuan"),
                const SizedBox(height: 35),
                ElevatedButton(
                  onPressed: () => _handleLogout(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.logout_rounded), SizedBox(width: 10), Text("Keluar Aplikasi", style: TextStyle(fontWeight: FontWeight.bold))],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

class UserManagementPage extends StatelessWidget {
  const UserManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return Scaffold(
      backgroundColor: Colors.transparent, 
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[700],
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddUserPage())),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 60, 24, 20),
            child: Text(
              "Daftar Pengguna",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
              ),
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: supabase.from('user').stream(primaryKey: ['id']),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("Tidak ada data user."));
                  }

                  final users = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Icon(Icons.person, color: Colors.blue[700]),
                          ),
                          title: Text(user['nama'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${user['email'] ?? '-'}\nRole: ${user['role'] ?? '-'}"),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              bool? confirm = await showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text("Hapus User?"),
                                  content: const Text("User akan dihapus secara permanen."),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Hapus", style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await supabase.from('user').delete().eq('id', user['id']);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}