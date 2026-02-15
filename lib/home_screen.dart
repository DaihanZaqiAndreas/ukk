import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'alat.dart';

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Halo, ${user['role']}'),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<List<Alat>>(
        future: service.getAlat(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan data'));
          }

          final listAlat = snapshot.data!;
          return ListView.builder(
            itemCount: listAlat.length,
            itemBuilder: (context, index) {
              final alat = listAlat[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(alat.namaAlat),
                  subtitle: Text('Stok: ${alat.stok}'),
                  trailing: ElevatedButton(
                    onPressed: () async {
                      await service.addPeminjaman(user['id'], alat.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Peminjaman berhasil diajukan!')),
                      );
                    },
                    child: const Text('Pinjam'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
