class Alat {
  final int id;
  final String namaAlat;
  final int? kategoriId;
  final int stok;

  Alat({
    required this.id,
    required this.namaAlat,
    this.kategoriId,
    required this.stok,
  });

  // Konversi dari Map Supabase ke Objek Dart
  factory Alat.fromMap(Map<String, dynamic> map) {
    return Alat(
      id: map['id'],
      namaAlat: map['nama_alat'],
      kategoriId: map['kategori_id'],
      stok: map['stok'] ?? 0,
    );
  }
}
