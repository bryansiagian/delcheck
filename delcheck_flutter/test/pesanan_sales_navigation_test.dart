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
import 'package:delcheck_flutter/screens/pesanan_list_screen.dart';

void main() {
  testWidgets('menu Konfirmasi Pesanan hanya tampil untuk Sales', (
    tester,
  ) async {
    for (final role in ['sales', 'retail', 'admin', 'warehouse']) {
      final client = MockClient((_) async => _jsonResponse({'data': {}}));
      final api = ApiClient(client: client);
      await tester.pumpWidget(_homeHost(api, role));
      await tester.pumpAndSettle();

      expect(
        find.text('Konfirmasi Pesanan'),
        role == 'sales' ? findsOneWidget : findsNothing,
        reason: 'role=$role',
      );
      if (role == 'admin') {
        expect(find.text('Pengiriman'), findsOneWidget);
      } else {
        expect(find.text('Pengiriman'), findsNothing);
      }
      if (role == 'warehouse') {
        expect(find.text('Daftar Pesanan'), findsOneWidget);
        expect(find.text('Produk'), findsOneWidget);
        expect(find.text('Stok'), findsOneWidget);
      }
      if (role == 'retail') {
        expect(find.text('Pesanan Saya'), findsOneWidget);
        expect(find.text('Pesan Produk'), findsOneWidget);
        expect(find.text('Return'), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('daftar Sales memakai filter menunggu dan membuka detail', (
    tester,
  ) async {
    final requestedStatuses = <String>[];
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/pesanan/7')) {
        return _jsonResponse({
          'data': _pesananJson('menunggu_konfirmasi_sales'),
        });
      }
      requestedStatuses.add(request.url.queryParameters['status'] ?? '');
      return _jsonResponse({
        'data': {
          'items': [_pesananJson('menunggu_konfirmasi_sales')],
          'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
        },
      });
    });
    final api = ApiClient(client: client);
    await tester.pumpWidget(_salesListHost(api));
    await tester.pumpAndSettle();

    expect(requestedStatuses, ['menunggu_konfirmasi_sales']);
    expect(find.text('#PSN-00007'), findsOneWidget);
    expect(find.text('Toko Sumber Rejeki'), findsOneWidget);

    await tester.tap(find.text('#PSN-00007'));
    await tester.pumpAndSettle();
    expect(requestedPaths, contains('/api/pesanan/7'));
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    client.close();
  });

  testWidgets('persetujuan Sales memanggil API lalu menyegarkan antrian', (
    tester,
  ) async {
    var statusBerubah = false;
    var jumlahDaftar = 0;
    var jumlahSetujui = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/pesanan/7/setujui')) {
        jumlahSetujui++;
        statusBerubah = true;
        return _jsonResponse({'data': _pesananJson('dikonfirmasi')});
      }
      if (request.url.path.endsWith('/pesanan/7')) {
        return _jsonResponse({
          'data': _pesananJson(
            statusBerubah ? 'dikonfirmasi' : 'menunggu_konfirmasi_sales',
          ),
        });
      }
      jumlahDaftar++;
      return _jsonResponse({
        'data': {
          'items': statusBerubah
              ? []
              : [_pesananJson('menunggu_konfirmasi_sales')],
          'meta': {
            'halaman': 1,
            'halaman_terakhir': 1,
            'total': statusBerubah ? 0 : 1,
          },
        },
      });
    });
    final api = ApiClient(client: client);
    await tester.pumpWidget(_salesListHost(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#PSN-00007'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('akan diteruskan ke gudang untuk dikirim'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Setujui'),
      ),
    );
    await tester.pumpAndSettle();

    expect(jumlahSetujui, 1);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(jumlahDaftar, 2);
    expect(
      find.text('Tidak ada pesanan yang menunggu konfirmasi'),
      findsOneWidget,
    );
    client.close();
  });

  testWidgets('penolakan Sales mewajibkan alasan dan menyegarkan antrian', (
    tester,
  ) async {
    var ditolak = false;
    var jumlahDaftar = 0;
    Map<String, dynamic>? requestTolak;
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/pesanan/7/tolak')) {
        requestTolak = jsonDecode(request.body) as Map<String, dynamic>;
        ditolak = true;
        return _jsonResponse({'data': _pesananJson('ditolak')});
      }
      if (request.url.path.endsWith('/pesanan/7')) {
        return _jsonResponse({
          'data': _pesananJson(
            ditolak ? 'ditolak' : 'menunggu_konfirmasi_sales',
          ),
        });
      }
      jumlahDaftar++;
      return _jsonResponse({
        'data': {
          'items': ditolak ? [] : [_pesananJson('menunggu_konfirmasi_sales')],
          'meta': {
            'halaman': 1,
            'halaman_terakhir': 1,
            'total': ditolak ? 0 : 1,
          },
        },
      });
    });
    final api = ApiClient(client: client);
    await tester.pumpWidget(_salesListHost(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#PSN-00007'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    expect(find.text('Alasan wajib diisi'), findsOneWidget);
    expect(requestTolak, isNull);

    await tester.enterText(
      find.byType(TextFormField),
      '  Produk tidak sesuai  ',
    );
    await tester.tap(find.text('Kirim'));
    await tester.pumpAndSettle();
    expect(requestTolak, {'alasan': 'Produk tidak sesuai'});
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(jumlahDaftar, 2);
    expect(
      find.text('Tidak ada pesanan yang menunggu konfirmasi'),
      findsOneWidget,
    );
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

Widget _salesListHost(ApiClient api) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, 'sales'),
    ),
  ],
  child: const MaterialApp(
    home: PesananListScreen(
      judul: 'Konfirmasi Pesanan',
      tampilanSales: true,
      filter: [
        PesananFilter(
          'Menunggu',
          'menunggu_konfirmasi_sales',
          icon: Icons.hourglass_top_rounded,
        ),
      ],
    ),
  ),
);

class _AuthProviderForTest extends AuthProvider {
  _AuthProviderForTest(ApiClient api, this.role) : super(api: api);

  final String role;

  @override
  AppUser? get user => AppUser(nama: 'Sales Test', peran: [role]);
}

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _pesananJson(String status) => {
  'id': 7,
  'nomor': 'PSN-00007',
  'status': status,
  'status_label': status == 'ditolak' ? 'Ditolak' : 'Menunggu konfirmasi',
  'total': 250000,
  'jumlah_item': 2,
  'created_at': '2026-11-03T08:15:00+07:00',
  'retailer': {'id': 3, 'kode': 'RTL-003', 'nama_toko': 'Toko Sumber Rejeki'},
  'items': [
    {
      'id': 12,
      'produk_id': 16,
      'nama_produk': 'Minyak Goreng',
      'satuan': 'liter',
      'harga': 125000,
      'qty': 2,
      'subtotal': 250000,
    },
  ],
};
