class Wilayah {
  final int id;
  final String kode;
  final String nama;
  final String tingkat; // provinsi | kota | kecamatan
  final int? parentId;

  const Wilayah({
    required this.id,
    required this.kode,
    required this.nama,
    required this.tingkat,
    this.parentId,
  });

  factory Wilayah.fromJson(Map<String, dynamic> json) => Wilayah(
        id: json['id'] as int,
        kode: json['kode'].toString(),
        nama: json['nama'] as String,
        tingkat: json['tingkat'] as String,
        parentId: json['parent_id'] as int?,
      );
}
