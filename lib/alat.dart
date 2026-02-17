class Alat {
  final int id;
  final String namaAlat;
  final String? kategori;
  final String? imageUrl;
  final int stok;

  Alat({
    required this.id,
    required this.namaAlat,
    this.kategori,
    this.imageUrl,
    required this.stok,
  });

  factory Alat.fromMap(Map<String, dynamic> map) {
    return Alat(
      id: map['id'],
      namaAlat: map['nama_alat'] ?? '',
      kategori: map['kategori'],
      imageUrl: map['image_url'],
      stok: map['stok'] ?? 0,
    );
  }
}
