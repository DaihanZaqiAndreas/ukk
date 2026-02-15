import 'package:flutter/material.dart';

class PeminjamDashboard extends StatelessWidget {
  const PeminjamDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pinjam Alat"),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Penting: Kembalikan alat tepat waktu untuk menghindari denda!",
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Pilih Kategori",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CategoryIcon(icon: Icons.camera_alt, label: "Kamera"),
                _CategoryIcon(icon: Icons.laptop, label: "Laptop"),
                _CategoryIcon(icon: Icons.build, label: "Tools"),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              "Alat Tersedia",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.videocam, color: Colors.blue),
                title: Text("Proyektor Epson"),
                subtitle: Text("Status: Tersedia"),
                trailing: Icon(Icons.add_circle, color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CategoryIcon({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
