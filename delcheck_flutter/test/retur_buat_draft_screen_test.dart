import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:delcheck_flutter/core/api_client.dart';
import 'package:delcheck_flutter/screens/retur_buat_draft_screen.dart';

final _fotoSementara = <File>[];

void main() {
  tearDown(() async {
    for (final file in _fotoSementara) {
      if (file.existsSync()) file.deleteSync();
    }
    _fotoSementara.clear();
  });

  testWidgets(
    'draft memakai pesanan/item ID yang dipilih tanpa batas qty beli',
    (tester) async {
      Map<String, dynamic>? bodyRetur;
      String? contentTypeRetur;
      final client = MockClient((request) async {
        if (request.method == 'GET' && request.url.path.endsWith('/pesanan')) {
          expect(request.url.queryParameters['status'], 'diterima');
          return _json({
            'data': {
              'items': [_pesananList(), _pesananSelesai()],
              'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 2},
            },
          });
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/pesanan/42')) {
          return _json({'data': _pesananDetail()});
        }
        if (request.method == 'POST' && request.url.path.endsWith('/retur')) {
          contentTypeRetur = request.headers['content-type'];
          bodyRetur = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({
            'data': {
              'id': 501,
              'nomor': 'RTR-501',
              'status': 'draft',
              'status_label': 'Draft',
            },
          }, status: 201);
        }
        return _json({'message': 'Endpoint tidak ditemukan.'}, status: 404);
      });
      final api = ApiClient(client: client)..token = 'test-token';
      bool? result;

      await tester.pumpWidget(_host(api, (value) => result = value));
      await tester.tap(find.text('Buka form'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilih pesanan'));
      await tester.pumpAndSettle();

      expect(find.text('ORDER-42'), findsOneWidget);
      expect(find.text('ORDER-43'), findsNothing);
      await tester.tap(find.text('ORDER-42'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Produk B'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Pembelian: 2 pcs'), findsOneWidget);
      await tester.tap(find.text('Produk B'));

      await tester.scrollUntilVisible(
        find.byType(TextFormField).first,
        220,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(find.byType(TextFormField).at(0), '500');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        '  Barang rusak  ',
      );
      await tester.scrollUntilVisible(
        find.text('Penggantian produk'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Penggantian produk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Draft'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(bodyRetur, {
        'pesanan_id': 42,
        'item_pesanan_id': 302,
        'qty': 500,
        'alasan': 'Barang rusak',
        'jenis_penyelesaian': 'replacement',
      });
      expect(bodyRetur!.containsKey('produk_id'), isFalse);
      expect(contentTypeRetur, startsWith('application/json'));

      client.close();
    },
  );

  testWidgets('validasi kuantitas dan alasan tampil sebelum request', (
    tester,
  ) async {
    final client = MockClient((_) async => _json({'data': {}}));
    final api = ApiClient(client: client);
    await tester.pumpWidget(_host(api, (_) {}));
    await tester.tap(find.text('Buka form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Draft'));
    await tester.pumpAndSettle();

    expect(
      find.text('Kuantitas harus berupa bilangan bulat lebih dari 0.'),
      findsOneWidget,
    );
    expect(find.text('Alasan wajib diisi.'), findsOneWidget);
    client.close();
  });

  testWidgets(
    'form edit memuat draft, item, foto lama, lalu update tanpa foto',
    (tester) async {
      Map<String, dynamic>? dataUpdate;
      String? methodUpdate;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/retur/501')) {
          return _json({'data': _returEditJson()});
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/pesanan/42')) {
          return _json({'data': _pesananDetail()});
        }
        if (request.method == 'GET' && request.url.path.endsWith('/pesanan')) {
          return _json({
            'data': {
              'items': [_pesananTujuanList()],
              'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
            },
          });
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/pesanan/43')) {
          return _json({'data': _pesananTujuanDetail()});
        }
        if (request.method == 'PUT' &&
            request.url.path.endsWith('/retur/501')) {
          methodUpdate = request.method;
          dataUpdate = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'data': _returEditJson(alasan: 'Alasan terbaru')});
        }
        return _json({}, status: 404);
      });
      final api = ApiClient(client: client);
      bool? result;

      await tester.pumpWidget(
        _host(api, (value) => result = value, returId: 501),
      );
      await tester.tap(find.text('Buka form'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Draft Return'), findsOneWidget);
      expect(find.text('ORDER-42'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        '7',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller!
            .text,
        'Bungkus rusak',
      );
      expect(
        tester
            .widget<RadioGroup<int>>(find.byType(RadioGroup<int>).first)
            .groupValue,
        302,
      );
      expect(
        tester
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>).first)
            .groupValue,
        'replacement',
      );
      await tester.scrollUntilVisible(
        find.text('Foto tersimpan saat ini'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Foto tersimpan saat ini'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, 900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ganti pesanan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ORDER-43'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produk C'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<int>>(find.byType(RadioGroup<int>).first)
            .groupValue,
        401,
      );
      await tester.enterText(find.byType(TextFormField).at(0), '12');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Alasan terbaru',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -460));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pengembalian dana'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(methodUpdate, 'PUT');
      expect(dataUpdate?['pesanan_id'], 43);
      expect(dataUpdate?['item_pesanan_id'], 401);
      expect(dataUpdate?['qty'], 12);
      expect(dataUpdate?['alasan'], 'Alasan terbaru');
      expect(dataUpdate?['jenis_penyelesaian'], 'refund');
      expect(dataUpdate!.containsKey('foto_kondisi'), isFalse);
      client.close();
    },
  );

  testWidgets('error API edit ditampilkan tanpa menghapus isian form', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/retur/501')) {
        return _json({'data': _returEditJson()});
      }
      if (request.method == 'GET' && request.url.path.endsWith('/pesanan/42')) {
        return _json({'data': _pesananDetail()});
      }
      if (request.method == 'PUT' && request.url.path.endsWith('/retur/501')) {
        return _json({
          'message': 'Data tidak valid.',
          'errors': {
            'alasan': ['Alasan ditolak backend.'],
          },
        }, status: 422);
      }
      return _json({}, status: 404);
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_host(api, (_) {}, returId: 501));
    await tester.tap(find.text('Buka form'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Alasan tetap ada',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();

    expect(find.text('Alasan ditolak backend.'), findsOneWidget);
    expect(find.text('Edit Draft Return'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'Alasan tetap ada',
    );
    client.close();
  });

  testWidgets('error API saat simpan ditampilkan tanpa hasil berhasil', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/pesanan')) {
        return _json({
          'data': {
            'items': [_pesananList()],
            'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
          },
        });
      }
      if (request.method == 'GET' && request.url.path.endsWith('/pesanan/42')) {
        return _json({'data': _pesananDetail()});
      }
      if (request.method == 'POST' && request.url.path.endsWith('/retur')) {
        return _json({
          'message': 'Pesanan sudah memiliki Return aktif.',
        }, status: 422);
      }
      return _json({}, status: 404);
    });
    final api = ApiClient(client: client);
    bool? result;

    await tester.pumpWidget(_host(api, (value) => result = value));
    await tester.tap(find.text('Buka form'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih pesanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ORDER-42'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Produk A'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Produk A'));
    await tester.scrollUntilVisible(
      find.byType(TextFormField).first,
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(find.byType(TextFormField).at(0), '1');
    await tester.enterText(find.byType(TextFormField).at(1), 'Rusak');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pengembalian dana'),
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pengembalian dana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Draft'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Pesanan sudah memiliki Return aktif.'), findsOneWidget);
    client.close();
  });

  testWidgets('memilih beberapa foto galeri dan kamera, preview dan hapus', (
    tester,
  ) async {
    final fotoA = _buatFoto('pilih_a.png');
    final fotoB = _buatFoto('pilih_b.png');
    final fotoC = _buatFoto('pilih_c.png');
    final picker = _FakeImagePicker(galeri: [fotoA, fotoB], kamera: fotoC);
    final api = ApiClient(client: MockClient((_) async => _json({'data': {}})));

    await _bukaForm(tester, api, picker);
    await _bukaBagianFoto(tester);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    expect(picker.batasTerakhir, 5);
    expect(find.text('2 dari 5 foto dipilih'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));

    await tester.tap(find.text('Kamera'));
    await tester.pumpAndSettle();
    expect(picker.sourceTerakhir, ImageSource.camera);
    expect(find.text('3 dari 5 foto dipilih'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus foto').first);
    await tester.pumpAndSettle();
    expect(find.text('2 dari 5 foto dipilih'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
  });

  testWidgets('menolak foto keenam meski picker mengabaikan limit', (
    tester,
  ) async {
    final fotos = <XFile>[];
    for (var i = 0; i < 6; i++) {
      fotos.add(_buatFoto('enam_$i.png'));
    }
    final picker = _FakeImagePicker(galeri: fotos);
    final api = ApiClient(client: MockClient((_) async => _json({'data': {}})));

    await _bukaForm(tester, api, picker);
    await _bukaBagianFoto(tester);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();

    expect(picker.batasTerakhir, 5);
    expect(find.text('5 dari 5 foto dipilih'), findsOneWidget);
    expect(find.text('Batas maksimal 5 foto sudah tercapai.'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(5));
  });

  testWidgets('menolak foto lebih besar dari 10 MB tanpa menghapus form', (
    tester,
  ) async {
    final fotoBesar = _buatFoto('besar.png', ukuran: 10 * 1024 * 1024 + 1);
    final picker = _FakeImagePicker(galeri: [fotoBesar]);
    final api = ApiClient(client: MockClient((_) async => _json({'data': {}})));

    await _bukaForm(tester, api, picker);
    await _bukaBagianFoto(tester);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();

    expect(find.text('0 dari 5 foto dipilih'), findsOneWidget);
    expect(find.text('Setiap foto maksimal 10 MB.'), findsWidgets);
  });

  testWidgets('draft dengan beberapa foto memakai multipart foto_kondisi[]', (
    tester,
  ) async {
    final fotoA = _buatFoto('upload_a.png');
    final fotoB = _buatFoto('upload_b.png');
    final picker = _FakeImagePicker(galeri: [fotoA, fotoB]);
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/pesanan')) {
        return _json({
          'data': {
            'items': [_pesananList()],
            'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
          },
        });
      }
      if (request.method == 'GET' && request.url.path.endsWith('/pesanan/42')) {
        return _json({'data': _pesananDetail()});
      }
      return _json({}, status: 404);
    });
    final api = _DraftApiClient(client: client)..token = 'test-token';
    bool? result;

    await _bukaForm(tester, api, picker, onResult: (value) => result = value);
    await _pilihPesananItemDanIsiForm(tester);
    await _bukaBagianFoto(tester);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    expect(find.text('2 dari 5 foto dipilih'), findsOneWidget);
    await tester.tap(find.text('Simpan Draft'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(api.fields?['pesanan_id'], 42);
    expect(api.fields?['item_pesanan_id'], 301);
    expect(api.files?['foto_kondisi[]']?.length, 2);
    final namaFile = api.files!['foto_kondisi[]']!
        .map((file) => file.path.split(Platform.pathSeparator).last)
        .toList();
    expect(namaFile[0].endsWith('upload_a.png'), isTrue);
    expect(namaFile[1].endsWith('upload_b.png'), isTrue);
    client.close();
  });

  testWidgets('upload gagal mempertahankan foto dan isian form', (
    tester,
  ) async {
    final fotoA = _buatFoto('gagal_a.png');
    final fotoB = _buatFoto('gagal_b.png');
    final picker = _FakeImagePicker(galeri: [fotoA, fotoB]);
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/pesanan')) {
        return _json({
          'data': {
            'items': [_pesananList()],
            'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
          },
        });
      }
      if (request.method == 'GET' && request.url.path.endsWith('/pesanan/42')) {
        return _json({'data': _pesananDetail()});
      }
      return _json({}, status: 404);
    });
    final api = _DraftApiClient(
      client: client,
      failureMessage: 'Upload ditolak oleh server.',
    );

    await _bukaForm(tester, api, picker);
    await _pilihPesananItemDanIsiForm(tester);
    await _bukaBagianFoto(tester);
    await tester.tap(find.text('Galeri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Draft'));
    await tester.pumpAndSettle();

    expect(find.text('Upload ditolak oleh server.'), findsOneWidget);
    expect(find.text('Simpan Draft'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '1',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'Rusak',
    );
    await _bukaBagianFoto(tester);
    expect(find.text('2 dari 5 foto dipilih'), findsOneWidget);
    expect(find.byTooltip('Hapus foto'), findsNWidgets(2));
    client.close();
  });
}

Widget _host(
  ApiClient api,
  ValueChanged<bool?> onResult, {
  ImagePicker? picker,
  int? returId,
}) => Provider<ApiClient>.value(
  value: api,
  child: MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () {
              Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ReturBuatDraftScreen(
                    returId: returId,
                    imagePicker: picker,
                  ),
                ),
              ).then(onResult);
            },
            child: const Text('Buka form'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _bukaForm(
  WidgetTester tester,
  ApiClient api,
  ImagePicker picker, {
  ValueChanged<bool?> onResult = _abaikanHasil,
}) async {
  await tester.pumpWidget(_host(api, onResult, picker: picker));
  await tester.tap(find.text('Buka form'));
  await tester.pumpAndSettle();
}

void _abaikanHasil(bool? _) {}

Future<void> _bukaBagianFoto(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Galeri'),
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

Future<void> _pilihPesananItemDanIsiForm(WidgetTester tester) async {
  await tester.tap(find.text('Pilih pesanan'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ORDER-42'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Produk A'),
    220,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Produk A'));
  await tester.scrollUntilVisible(
    find.byType(TextFormField).first,
    220,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.enterText(find.byType(TextFormField).at(0), '1');
  await tester.enterText(find.byType(TextFormField).at(1), 'Rusak');
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Pengembalian dana'),
    180,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('Pengembalian dana'));
  await tester.pumpAndSettle();
}

XFile _buatFoto(String nama, {int ukuran = 128}) {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}${DateTime.now().microsecondsSinceEpoch}_$nama',
  );
  file.writeAsBytesSync(List<int>.filled(ukuran, 1));
  _fotoSementara.add(file);
  return XFile(file.path, mimeType: 'image/png');
}

class _FakeImagePicker extends ImagePicker {
  _FakeImagePicker({this.galeri = const [], this.kamera});

  final List<XFile> galeri;
  final XFile? kamera;
  int? batasTerakhir;
  ImageSource? sourceTerakhir;

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    batasTerakhir = limit;
    return galeri;
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    sourceTerakhir = source;
    return kamera;
  }
}

http.Response _json(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

class _DraftApiClient extends ApiClient {
  _DraftApiClient({required super.client, this.failureMessage});

  final String? failureMessage;
  Map<String, dynamic>? fields;
  Map<String, List<File>>? files;

  @override
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, dynamic> fields = const {},
    Map<String, List<File>> files = const {},
  }) async {
    this.fields = fields;
    this.files = files;
    if (failureMessage != null) {
      throw ApiException(status: 422, message: failureMessage!);
    }
    return {
      'data': {
        'id': 501,
        'nomor': 'RTR-501',
        'status': 'draft',
        'status_label': 'Draft',
      },
    };
  }
}

Map<String, dynamic> _pesananList() => {
  'id': 42,
  'nomor': 'ORDER-42',
  'status': 'diterima',
  'total': 50000,
  'jumlah_item': 2,
  'created_at': '2026-11-03T10:00:00+07:00',
};

Map<String, dynamic> _pesananSelesai() => {
  'id': 43,
  'nomor': 'ORDER-43',
  'status': 'selesai',
  'total': 10000,
  'jumlah_item': 1,
  'created_at': '2026-11-02T10:00:00+07:00',
};

Map<String, dynamic> _pesananDetail() => {
  ..._pesananList(),
  'items': [
    {
      'id': 301,
      'produk_id': 11,
      'nama_produk': 'Produk A',
      'satuan': 'pcs',
      'qty': 4,
      'harga': 10000,
      'subtotal': 40000,
    },
    {
      'id': 302,
      'produk_id': 12,
      'nama_produk': 'Produk B',
      'satuan': 'pcs',
      'qty': 2,
      'harga': 5000,
      'subtotal': 10000,
    },
  ],
};

Map<String, dynamic> _pesananTujuanList() => {
  'id': 43,
  'nomor': 'ORDER-43',
  'status': 'diterima',
  'total': 75000,
  'jumlah_item': 1,
  'created_at': '2026-11-04T10:00:00+07:00',
};

Map<String, dynamic> _pesananTujuanDetail() => {
  ..._pesananTujuanList(),
  'items': [
    {
      'id': 401,
      'produk_id': 13,
      'nama_produk': 'Produk C',
      'satuan': 'pcs',
      'qty': 3,
      'harga': 25000,
      'subtotal': 75000,
    },
  ],
};

Map<String, dynamic> _returEditJson({String alasan = 'Bungkus rusak'}) => {
  'id': 501,
  'nomor': 'RTR-501',
  'status': 'draft',
  'status_label': 'Draft',
  'alasan': alasan,
  'jenis_penyelesaian': 'replacement',
  'pesanan': {'id': 42, 'nomor': 'ORDER-42'},
  'item': {
    'id': 51,
    'item_pesanan_id': 302,
    'produk_id': 12,
    'produk': {'id': 12, 'nama': 'Produk B', 'satuan': 'pcs'},
    'nama_produk_pesanan': 'Produk B',
    'qty': 7,
  },
  'foto_kondisi': [
    {
      'id': 900,
      'jenis': 'kondisi_produk',
      'url': 'http://192.168.43.188:8000/api/retur/501/foto/900',
      'mime': 'image/jpeg',
      'ukuran': 1234,
    },
  ],
  'foto_penjemputan': [],
};
