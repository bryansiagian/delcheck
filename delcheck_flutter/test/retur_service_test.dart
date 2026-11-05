import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:delcheck_flutter/core/api_client.dart';
import 'package:delcheck_flutter/models/retur.dart';
import 'package:delcheck_flutter/services/retur_service.dart';

void main() {
  group('Retur.fromJson', () {
    test('mem-parsing nested item, foto, status dan tanggal nullable', () {
      final retur = Retur.fromJson(_returJson());

      expect(retur.id, 8);
      expect(retur.status, Retur.statusDiajukan);
      expect(retur.createdAt, DateTime.parse('2026-11-03T10:00:00+07:00'));
      expect(retur.updatedAt, isNull);
      expect(retur.pesanan?.nomor, 'PSN-00000045');
      expect(retur.retailer?.namaToko, 'Toko Contoh');
      expect(retur.item?.produk?.nama, 'Produk Contoh');
      expect(retur.item?.namaProdukPesanan, 'Produk pesanan');
      expect(retur.fotoKondisi.single.url, contains('/api/retur/8/foto/2'));
      expect(retur.fotoKondisi.single.ukuran, 1024);
      expect(retur.fotoPenjemputan, isEmpty);
      expect(retur.jadwalJemput, isNull);
      expect(retur.dikonfirmasiAt, isNull);
    });
  });

  group('ReturService', () {
    test('update tanpa foto memakai JSON PUT tanpa field foto', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'success': true, 'data': _returJson(status: 'draft')}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = ReturService(ApiClient(client: client));

      await service.perbaruiDraft(
        8,
        data: {
          'pesanan_id': 45,
          'item_pesanan_id': 55,
          'qty': 4,
          'alasan': 'Diperbarui',
          'jenis_penyelesaian': null,
        },
      );

      expect(captured.method, 'PUT');
      expect(captured.url.path, '/api/retur/8');
      expect(captured.headers['content-type'], startsWith('application/json'));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['pesanan_id'], 45);
      expect(body['item_pesanan_id'], 55);
      expect(body['qty'], 4);
      expect(body.containsKey('foto_kondisi'), isFalse);
    });

    test(
      'hapusDraft mengirim DELETE dan mengembalikan pesan backend',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'message': 'Draft berhasil dihapus.', 'data': null}),
            200,
          );
        });
        final service = ReturService(ApiClient(client: client));

        final pesan = await service.hapusDraft(8);

        expect(captured.method, 'DELETE');
        expect(captured.url.path, '/api/retur/8');
        expect(pesan, 'Draft berhasil dihapus.');
      },
    );

    test(
      'buatDraft mengirim beberapa foto dalam satu multipart request',
      () async {
        final temp = await Directory.systemTemp.createTemp('delcheck-draft-');
        addTearDown(() => temp.delete(recursive: true));
        final first = await File(
          '${temp.path}/kondisi-1.jpg',
        ).writeAsString('foto-1');
        final second = await File(
          '${temp.path}/kondisi-2.jpg',
        ).writeAsString('foto-2');
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'success': true, 'data': _returJson(status: 'draft')}),
            201,
            headers: {'content-type': 'application/json'},
          );
        });
        final service = ReturService(ApiClient(client: client));

        await service.buatDraft(
          pesananId: 45,
          itemPesananId: 55,
          qty: 2,
          alasan: 'Produk rusak',
          fotoKondisi: [first, second],
        );

        expect(captured.method, 'POST');
        expect(captured.url.path, '/api/retur');
        expect(
          captured.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect('name="foto_kondisi[]"'.allMatches(captured.body).length, 2);
        expect(captured.body, contains('kondisi-1.jpg'));
        expect(captured.body, contains('kondisi-2.jpg'));
        expect(captured.body, contains('name="pesanan_id"'));
        expect(captured.body, contains('name="item_pesanan_id"'));
      },
    );

    test(
      'daftar membentuk query pagination, filter status dan pencarian',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Berhasil.',
              'data': {
                'items': [_returJson()],
                'meta': {
                  'halaman': 2,
                  'per_halaman': 7,
                  'total': 10,
                  'halaman_terakhir': 2,
                },
              },
            }),
            200,
          );
        });
        final service = ReturService(ApiClient(client: client));

        final page = await service.daftar(
          status: Retur.statusDiajukan,
          q: '  RTR-8  ',
          halaman: 2,
          perPage: 7,
        );

        expect(captured.method, 'GET');
        expect(captured.url.path, '/api/retur');
        expect(captured.url.queryParameters, {
          'page': '2',
          'per_page': '7',
          'status': 'diajukan',
          'q': 'RTR-8',
        });
        expect(page.items.single.id, 8);
        expect(page.halaman, 2);
        expect(page.halamanTerakhir, 2);
        expect(page.total, 10);
      },
    );

    test(
      'update dengan foto memakai POST spoof PUT dan field file berulang',
      () async {
        final temp = await Directory.systemTemp.createTemp('delcheck-retur-');
        addTearDown(() => temp.delete(recursive: true));
        final first = await File(
          '${temp.path}/kondisi-1.jpg',
        ).writeAsString('foto-satu');
        final second = await File(
          '${temp.path}/kondisi-2.jpg',
        ).writeAsString('foto-dua');
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Berhasil.',
              'data': _returJson(),
            }),
            200,
          );
        });
        final api = ApiClient(client: client)..token = 'test-token';
        final service = ReturService(api);

        await service.perbaruiDraft(
          8,
          data: {'alasan': 'Diperbarui', 'jenis_penyelesaian': null},
          fotoKondisi: [first, second],
        );

        expect(captured.method, 'POST');
        expect(captured.url.path, '/api/retur/8');
        expect(captured.headers['authorization'], 'Bearer test-token');
        expect(captured.headers['accept'], 'application/json');
        expect(
          captured.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        expect(captured.body, contains('name="_method"'));
        expect(captured.body, contains('\r\n\r\nPUT\r\n'));
        expect(captured.body, contains('name="alasan"'));
        expect(captured.body, contains('name="jenis_penyelesaian"'));
        expect('name="foto_kondisi[]"'.allMatches(captured.body).length, 2);
        expect(captured.body, contains('kondisi-1.jpg'));
        expect(captured.body, contains('kondisi-2.jpg'));
      },
    );

    test(
      'upload bukti mendukung beberapa foto dengan nama field kontrak',
      () async {
        final temp = await Directory.systemTemp.createTemp('delcheck-retur-');
        addTearDown(() => temp.delete(recursive: true));
        final first = await File(
          '${temp.path}/jemput-1.jpg',
        ).writeAsString('foto-a');
        final second = await File(
          '${temp.path}/jemput-2.jpg',
        ).writeAsString('foto-b');
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': _returJson(status: 'dijemput'),
            }),
            200,
          );
        });
        final service = ReturService(ApiClient(client: client));

        final retur = await service.unggahBuktiPenjemputan(8, [first, second]);

        expect(retur.status, 'dijemput');
        expect(captured.method, 'POST');
        expect(captured.url.path, '/api/retur/8/bukti-penjemputan');
        expect('name="foto_penjemputan[]"'.allMatches(captured.body).length, 2);
      },
    );

    test(
      'ambilFoto mengirim Bearer dan bytes dikembalikan apa adanya',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        });
        final api = ApiClient(client: client)..token = 'image-token';

        final bytes = await api.getBytes(
          'http://192.168.43.188:8000/api/retur/8/foto/2',
        );

        expect(bytes, [1, 2, 3]);
        expect(captured.method, 'GET');
        expect(captured.headers['authorization'], 'Bearer image-token');
        expect(captured.headers['accept'], 'image/*, application/json');
      },
    );

    test(
      '401 pada foto memanggil callback sesi dan error backend dipetakan',
      () async {
        var unauthorizedCalled = false;
        final client = MockClient(
          (_) async =>
              http.Response(jsonEncode({'message': 'Unauthenticated.'}), 401),
        );
        final api = ApiClient(client: client)
          ..onUnauthorized = () => unauthorizedCalled = true;

        await expectLater(
          api.getBytes('http://192.168.43.188:8000/api/retur/8/foto/2'),
          throwsA(
            isA<ApiException>()
                .having((error) => error.status, 'status', 401)
                .having(
                  (error) => error.message,
                  'message',
                  'Unauthenticated.',
                ),
          ),
        );
        expect(unauthorizedCalled, isTrue);
      },
    );

    test(
      '403 pesan lokal dan 422 errors Laravel dipetakan ke ApiException',
      () async {
        final forbiddenApi = ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'sukses': false,
                'kode': 'TIDAK_PUNYA_AKSES',
                'pesan': 'Anda tidak memiliki akses.',
              }),
              403,
            ),
          ),
        );

        await expectLater(
          forbiddenApi.get('/retur'),
          throwsA(
            isA<ApiException>()
                .having((error) => error.status, 'status', 403)
                .having((error) => error.kode, 'kode', 'TIDAK_PUNYA_AKSES')
                .having(
                  (error) => error.message,
                  'message',
                  'Anda tidak memiliki akses.',
                ),
          ),
        );

        final validationApi = ApiClient(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message': 'The given data was invalid.',
                'errors': {
                  'foto_kondisi.0': ['The file must be an image.'],
                },
              }),
              422,
            ),
          ),
        );

        await expectLater(
          validationApi.post('/retur'),
          throwsA(
            isA<ApiException>()
                .having((error) => error.status, 'status', 422)
                .having(
                  (error) => error.message,
                  'message',
                  'The file must be an image.',
                )
                .having(
                  (error) => error.errors['foto_kondisi.0'],
                  'field error',
                  ['The file must be an image.'],
                ),
          ),
        );
      },
    );
  });
}

Map<String, dynamic> _returJson({String status = 'diajukan'}) => {
  'id': 8,
  'nomor': 'RTR-20261103-00008',
  'pesanan': {'id': 45, 'nomor': 'PSN-00000045'},
  'retailer': {'id': 6, 'kode': 'RTL-000006', 'nama_toko': 'Toko Contoh'},
  'status': status,
  'status_label': status,
  'alasan': 'Produk rusak',
  'alasan_ditolak': null,
  'jenis_penyelesaian': 'refund',
  'item': {
    'id': 9,
    'item_pesanan_id': 55,
    'produk_id': 3,
    'produk': {
      'id': 3,
      'kode': 'SKU-0003',
      'nama': 'Produk Contoh',
      'satuan': 'pcs',
    },
    'nama_produk_pesanan': 'Produk pesanan',
    'qty': 2,
  },
  'foto_kondisi': [
    {
      'id': 2,
      'jenis': 'kondisi_produk',
      'url': 'http://192.168.43.188:8000/api/retur/8/foto/2',
      'mime': 'image/jpeg',
      'ukuran': 1024,
    },
  ],
  'jadwal_jemput': null,
  'catatan_jemput': null,
  'foto_penjemputan': [],
  'pengaju': 'Nama Retail',
  'dikonfirmasi_oleh': null,
  'dikonfirmasi_at': null,
  'dijemput_at': null,
  'created_at': '2026-11-03T10:00:00+07:00',
  'updated_at': null,
};
