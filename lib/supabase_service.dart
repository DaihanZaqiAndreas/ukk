import 'package:supabase_flutter/supabase_flutter.dart';
import 'alat.dart';

class SupabaseService {
  // Mengambil instance client Supabase yang sudah diinisialisasi di main.dart
  final SupabaseClient supabase = Supabase.instance.client;

  // 1. FUNGSI LOGIN
  // Memeriksa email dan password secara manual dari tabel 'users'
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final user = await supabase
          .from('user')
          .select()
          .eq('email', email)
          .eq('password', password)
          .single(); // Mengambil satu baris data saja
      return user;
    } catch (e) {
      // Mengembalikan null jika user tidak ditemukan atau terjadi error
      return null;
    }
  }

  // 2. FUNGSI AMBIL DAFTAR ALAT
  // Mengambil seluruh data dari tabel 'alat' dan mengubahnya menjadi List Objek
  Future<List<Alat>> getAlat() async {
    final data = await supabase.from('alat').select();
    // Mengubah data Map menjadi List dari model Alat
    return (data as List).map((item) => Alat.fromMap(item)).toList();
  }

  // 3. FUNGSI TAMBAH PEMINJAMAN
  // Memasukkan data baru ke tabel 'peminjaman'
// Ubah di supabase_service.dart
  Future<void> addPeminjaman(String userId, int alatId) async {
    // Gunakan String untuk UUID
    await supabase.from('peminjaman').insert({
      'user_id': userId,
      'alat_id': alatId,
      'status_pinjam':
          'pinjam', // Sesuaikan nama kolom dengan gambar: status_pinjam
    });
  }
}
