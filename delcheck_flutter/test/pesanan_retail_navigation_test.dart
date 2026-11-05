import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:delcheck_flutter/core/api_client.dart';
import 'package:delcheck_flutter/models/app_user.dart';
import 'package:delcheck_flutter/providers/auth_provider.dart';
import 'package:delcheck_flutter/screens/home_screen.dart';
import 'package:delcheck_flutter/screens/pesanan_detail_screen.dart';
import 'package:delcheck_flutter/screens/pesanan_list_screen.dart';

void main() {
  testWidgets('menu Pesanan Saya hanya tampil untuk Retail', (tester) async {
    final apiRetail = ApiClient(
      client: MockClient((_) async => _jsonResponse({'data': {}})),
    );
    await tester.pumpWidget(_homeHost(apiRetail, 'retail'));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan Saya'), findsOneWidget);
    expect(find.text('Return'), findsOneWidget);

    final apiSales = ApiClient(
      client: MockClient((_) async => _jsonResponse({'data': {}})),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_homeHost(apiSales, 'sales'));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan Saya'), findsNothing);
  });

  testWidgets('kategori Retail mengirim filter status dan membuka detail', (
    tester,
  ) async {
    final statusDiminta = <String>[];
    final pathDiminta = <String>[];
    final client = MockClient((request) async {
      pathDiminta.add(request.url.path);
      if (request.url.path.endsWith('/pesanan/1')) {
        return _jsonResponse({'data': _pesananJson('ditolak')});
      }

      statusDiminta.add(request.url.queryParameters['status'] ?? '');
      final status =
          request.url.queryParameters['status'] == 'diterima,ditolak,dibatalkan'
          ? 'ditolak'
          : 'dikirim';
      return _jsonResponse({
        'data': {
          'items': [_pesananJson(status)],
          'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
        },
      });
    });
    final api = ApiClient(client: client);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _AuthProviderForTest(api, 'retail'),
          ),
        ],
        child: const MaterialApp(
          home: PesananListScreen(
            judul: 'Pesanan Saya',
            tampilanRetail: true,
            filter: [
              PesananFilter(
                'Pesanan Aktif',
                'menunggu_konfirmasi_sales,dikonfirmasi,diproses,dikirim',
              ),
              PesananFilter('Riwayat Pesanan', 'diterima,ditolak,dibatalkan'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      statusDiminta.first,
      'menunggu_konfirmasi_sales,dikonfirmasi,diproses,dikirim',
    );
    expect(find.text('#PSN-00001'), findsOneWidget);
    expect(find.text('Dalam perjalanan'), findsOneWidget);

    await tester.tap(find.text('Riwayat Pesanan'));
    await tester.pumpAndSettle();
    expect(statusDiminta.last, 'diterima,ditolak,dibatalkan');
    expect(find.text('Ditolak'), findsOneWidget);

    await tester.tap(find.text('#PSN-00001'));
    await tester.pumpAndSettle();
    expect(pathDiminta, contains('/api/pesanan/1'));
    expect(find.text('Riwayat status'), findsOneWidget);
    client.close();
  });

  testWidgets('Retail mengonfirmasi pesanan dikirim melalui service API', (
    tester,
  ) async {
    var jumlahKonfirmasi = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/pesanan/1/terima')) {
        jumlahKonfirmasi++;
        return _jsonResponse({'data': _pesananJson('diterima')});
      }
      return _jsonResponse({'data': _pesananJson('dikirim')});
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_detailHost(api));
    await tester.pumpAndSettle();
    expect(find.text('Pesanan sudah diterima'), findsOneWidget);
    expect(find.text('Batalkan pesanan'), findsNothing);

    await tester.tap(find.text('Pesanan sudah diterima'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Pastikan barang sudah sampai di toko Anda dan sesuai pesanan.',
      ),
      findsOneWidget,
    );
    expect(jumlahKonfirmasi, 0);

    await tester.tap(find.text('Ya, sudah diterima'));
    await tester.pumpAndSettle();
    expect(jumlahKonfirmasi, 1);
    expect(find.text('Pesanan sudah diterima'), findsNothing);
    expect(find.text('Diterima'), findsOneWidget);
    client.close();
  });

  testWidgets('Retail hanya melihat aksi pembatalan saat menunggu Sales', (
    tester,
  ) async {
    for (final status in ['menunggu_konfirmasi_sales', 'dikirim']) {
      final client = MockClient((_) async {
        return _jsonResponse({'data': _pesananJson(status)});
      });
      final api = ApiClient(client: client);
      await tester.pumpWidget(_detailHost(api));
      await tester.pumpAndSettle();
      expect(
        find.text('Batalkan pesanan'),
        status == 'menunggu_konfirmasi_sales' ? findsOneWidget : findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('daftar aktif dimuat ulang setelah konfirmasi penerimaan', (
    tester,
  ) async {
    var diterima = false;
    var jumlahDaftar = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/pesanan/1/terima')) {
        diterima = true;
        return _jsonResponse({'data': _pesananJson('diterima')});
      }
      if (request.url.path.endsWith('/pesanan/1')) {
        return _jsonResponse({
          'data': _pesananJson(diterima ? 'diterima' : 'dikirim'),
        });
      }
      jumlahDaftar++;
      return _jsonResponse({
        'data': {
          'items': diterima ? [] : [_pesananJson('dikirim')],
          'meta': {
            'halaman': 1,
            'halaman_terakhir': 1,
            'total': diterima ? 0 : 1,
          },
        },
      });
    });
    final api = ApiClient(client: client);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider<AuthProvider>.value(
            value: _AuthProviderForTest(api, 'retail'),
          ),
        ],
        child: const MaterialApp(
          home: PesananListScreen(
            judul: 'Pesanan Saya',
            tampilanRetail: true,
            filter: [PesananFilter('Pesanan Aktif', 'dikirim')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(jumlahDaftar, 1);

    await tester.tap(find.text('#PSN-00001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pesanan sudah diterima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, sudah diterima'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(jumlahDaftar, 2);
    expect(find.text('Tidak ada pesanan pada kategori ini'), findsOneWidget);
    client.close();
  });
}

Widget _homeHost(ApiClient api, String role) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role),
    ),
  ],
  child: const MaterialApp(home: HomeScreen()),
);

Widget _detailHost(ApiClient api) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, 'retail'),
    ),
  ],
  child: MaterialApp(home: PesananDetailScreen(id: 1)),
);

class _AuthProviderForTest extends AuthProvider {
  _AuthProviderForTest(ApiClient api, this.role) : super(api: api);

  final String role;

  @override
  AppUser? get user => AppUser(nama: 'Test User', peran: [role]);
}

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _pesananJson(String status) => {
  'id': 1,
  'nomor': 'PSN-00001',
  'status': status,
  'status_label': status == 'ditolak' ? 'Ditolak' : 'Dalam perjalanan',
  'total': 125000,
  'jumlah_item': 2,
  'created_at': '2026-11-02T09:30:00+07:00',
  if (status == 'dikirim' || status == 'diterima')
    'pengiriman': {
      'id': 4,
      'status': status == 'diterima' ? 'diterima' : 'jalan',
      'nama_pengemudi': 'Budi Santoso',
      'telepon_pengemudi': '081234567890',
      'nomor_kendaraan': 'BK 1234 AB',
    },
  'items': [
    {
      'id': 9,
      'produk_id': 15,
      'nama_produk': 'Kopi Bubuk',
      'satuan': 'pcs',
      'harga': 62500,
      'qty': 2,
      'subtotal': 125000,
    },
  ],
};
