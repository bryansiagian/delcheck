import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:delcheck_flutter/core/api_client.dart';
import 'package:delcheck_flutter/models/app_user.dart';
import 'package:delcheck_flutter/providers/auth_provider.dart';
import 'package:delcheck_flutter/screens/pesanan_detail_screen.dart';
import 'package:delcheck_flutter/screens/pesanan_list_screen.dart';

void main() {
  testWidgets('Warehouse dapat membaca daftar pesanan tanpa aksi pengiriman', (
    tester,
  ) async {
    const kasus = [
      'menunggu_konfirmasi_sales',
      'ditolak',
      'dibatalkan',
      'dikonfirmasi',
      'diproses',
      'dikirim',
      'diterima',
    ];

    for (final status in kasus) {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/pesanan');
        // Tab "Semua" tidak mengirim filter status ke backend.
        expect(request.url.queryParameters.containsKey('status'), isFalse);
        return _jsonResponse({
          'data': {
            'items': [_pesananJson(status)],
            'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
          },
        });
      });
      final api = ApiClient(client: client);

      await tester.pumpWidget(_warehouseListHost(api));
      await tester.pumpAndSettle();

      expect(find.text('#PSN-00007'), findsOneWidget, reason: status);
      expect(find.text('Lihat detail  ›'), findsOneWidget);
      expect(find.text('Catat Pengiriman'), findsNothing, reason: status);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('Admin tetap dapat melihat aksi pengiriman yang valid', (
    tester,
  ) async {
    final client = MockClient((_) async => _listResponse('dikonfirmasi'));
    await tester.pumpWidget(_adminListHost(ApiClient(client: client)));
    await tester.pumpAndSettle();

    expect(find.text('Catat Pengiriman'), findsOneWidget);
    await tester.tap(find.text('Catat Pengiriman'));
    await tester.pumpAndSettle();
    expect(find.text('Nama pengemudi'), findsOneWidget);
    expect(find.text('Nomor telepon pengemudi'), findsOneWidget);
    expect(find.text('Plat kendaraan'), findsOneWidget);

    client.close();
  });

  testWidgets('status daftar memvalidasi pasangan pesanan dan pengiriman', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const valid = [
      (
        pesanan: 'dikonfirmasi',
        pengiriman: null,
        pesan: 'Pesanan telah dikonfirmasi Sales dan siap dikirim.',
      ),
      (
        pesanan: 'diproses',
        pengiriman: 'kurir',
        pesan: 'Pengiriman sudah dicatat dan stok telah diperbarui.',
      ),
      (
        pesanan: 'dikirim',
        pengiriman: 'jalan',
        pesan: 'Kurir telah berangkat dan pesanan sedang dikirim.',
      ),
      (
        pesanan: 'diterima',
        pengiriman: 'diterima',
        pesan: 'Pesanan telah diterima.',
      ),
    ];
    for (final kasus in valid) {
      final client = MockClient(
        (_) async => _listResponse(
          kasus.pesanan,
          statusPengiriman: kasus.pengiriman,
        ),
      );
      await tester.pumpWidget(_adminListHost(ApiClient(client: client)));
      await tester.pumpAndSettle();

      expect(find.text(kasus.pesan), findsOneWidget, reason: kasus.pesanan);
      expect(
        find.text('Status pesanan dan pengiriman tidak sesuai.'),
        findsNothing,
        reason: '${kasus.pesanan}/${kasus.pengiriman}',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }

    const tidakValid = [
      (pesanan: 'dikirim', pengiriman: 'kurir'),
      (pesanan: 'diterima', pengiriman: 'jalan'),
    ];
    for (final kasus in tidakValid) {
      final client = MockClient(
        (_) async => _listResponse(
          kasus.pesanan,
          statusPengiriman: kasus.pengiriman,
        ),
      );
      await tester.pumpWidget(_adminListHost(ApiClient(client: client)));
      await tester.pumpAndSettle();

      expect(
        find.text('Status pesanan dan pengiriman tidak sesuai.'),
        findsOneWidget,
        reason: '${kasus.pesanan}/${kasus.pengiriman}',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets(
    'Admin hanya dapat Tandai Jalan untuk pengiriman berstatus kurir',
    (tester) async {
      var jalanDipanggil = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/pesanan/7/tandai-jalan')) {
          jalanDipanggil = true;
          return _jsonResponse({
            'data': _pesananJson('dikirim', statusPengiriman: 'jalan'),
          });
        }
        return _jsonResponse({
          'data': _pesananJson('diproses', statusPengiriman: 'kurir'),
        });
      });
      await tester.pumpWidget(_detailHost(ApiClient(client: client), 'admin'));
      await tester.pumpAndSettle();

      expect(find.text('Tandai Jalan'), findsOneWidget);
      expect(find.text('Catat Pengiriman'), findsNothing);
      for (var i = 0; i < 5 && find.text('Siap').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Siap'), findsOneWidget);
      expect(find.text('Kurir'), findsOneWidget);
      expect(find.text('Jalan'), findsOneWidget);
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Nama pengemudi'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);

      await tester.tap(find.text('Tandai Jalan'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Tandai Jalan'),
        ),
      );
      await tester.pumpAndSettle();
      expect(jalanDipanggil, isTrue);
      expect(
        find.text('Pesanan ditandai sedang dalam perjalanan.'),
        findsOneWidget,
      );
      client.close();
    },
  );

  testWidgets('tombol daftar Admin sesuai tahap dan status pengiriman', (
    tester,
  ) async {
    const kasus = [
      (
        statusPesanan: 'dikonfirmasi',
        statusKirim: null,
        aksi: 'Catat Pengiriman',
      ),
      (statusPesanan: 'diproses', statusKirim: 'kurir', aksi: 'Tandai Jalan'),
      (statusPesanan: 'diproses', statusKirim: null, aksi: ''),
      (statusPesanan: 'dikirim', statusKirim: 'jalan', aksi: ''),
    ];
    for (final kasusStatus in kasus) {
      final client = MockClient(
        (_) async => _listResponse(
          kasusStatus.statusPesanan,
          statusPengiriman: kasusStatus.statusKirim,
        ),
      );
      await tester.pumpWidget(_adminListHost(ApiClient(client: client)));
      await tester.pumpAndSettle();
      expect(
        find.text('Catat Pengiriman'),
        kasusStatus.aksi == 'Catat Pengiriman' ? findsOneWidget : findsNothing,
        reason: '${kasusStatus.statusPesanan}/${kasusStatus.statusKirim}',
      );
      expect(
        find.text('Tandai Jalan'),
        kasusStatus.aksi == 'Tandai Jalan' ? findsOneWidget : findsNothing,
        reason: '${kasusStatus.statusPesanan}/${kasusStatus.statusKirim}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('Retail hanya mendapat konfirmasi saat status pesanan jalan', (
    tester,
  ) async {
    for (final status in ['diproses', 'dikirim']) {
      final client = MockClient(
        (_) async => _jsonResponse({
          'data': _pesananJson(
            status,
            statusPengiriman: status == 'dikirim' ? 'jalan' : 'kurir',
          ),
        }),
      );
      await tester.pumpWidget(_detailHost(ApiClient(client: client), 'retail'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pesanan sudah diterima'),
        status == 'dikirim' ? findsOneWidget : findsNothing,
        reason: 'status=$status',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets(
    'Warehouse yang membuka layar Pengiriman langsung tetap read-only',
    (tester) async {
      final client = MockClient((_) async => _listResponse('dikonfirmasi'));
      await tester.pumpWidget(
        _listHost(ApiClient(client: client), 'warehouse'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Catat Pengiriman'), findsNothing);
      expect(find.text('Lihat detail pesanan'), findsOneWidget);
      client.close();
    },
  );

  testWidgets('Warehouse dapat membuka detail pesanan tanpa tombol aksi', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/pesanan/7')) {
        return _jsonResponse({'data': _pesananJson('dikonfirmasi')});
      }
      return _listResponse('dikonfirmasi');
    });
    await tester.pumpWidget(
      _listHost(
        ApiClient(client: client),
        'warehouse',
        tampilanWarehouse: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('#PSN-00007'));
    await tester.pumpAndSettle();
    expect(find.text('Riwayat status'), findsOneWidget);
    expect(find.text('Bersama kurir'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Dalam perjalanan'), findsNothing);
    client.close();
  });

  testWidgets('detail pesanan hanya memberi aksi proses/kirim kepada Admin', (
    tester,
  ) async {
    for (final role in ['admin', 'sales', 'warehouse']) {
      final client = MockClient(
        (_) async => _jsonResponse({'data': _pesananJson('dikonfirmasi')}),
      );
      final api = ApiClient(client: client);
      await tester.pumpWidget(_detailHost(api, role));
      await tester.pumpAndSettle();

      expect(
        find.text('Catat Pengiriman'),
        role == 'admin' ? findsOneWidget : findsNothing,
        reason: 'role=$role',
      );
      expect(find.text('Setujui'), findsNothing, reason: 'role=$role');
      expect(find.text('Tolak'), findsNothing, reason: 'role=$role');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('timeline normal konsisten tidak menampilkan peringatan', (
    tester,
  ) async {
    const kasus = [
      (pesanan: 'dikonfirmasi', pengiriman: null),
      (pesanan: 'diproses', pengiriman: 'kurir'),
      (pesanan: 'dikirim', pengiriman: 'jalan'),
      (pesanan: 'diterima', pengiriman: 'diterima'),
    ];

    for (final status in kasus) {
      final client = MockClient(
        (_) async => _jsonResponse({
          'data': _pesananJson(
            status.pesanan,
            statusPengiriman: status.pengiriman,
          ),
        }),
      );
      await tester.pumpWidget(_detailHost(ApiClient(client: client), 'admin'));
      await tester.pumpAndSettle();

      expect(
        find.text('Status pesanan dan pengiriman tidak sesuai. Silakan hubungi Admin.'),
        findsNothing,
        reason: '${status.pesanan}/${status.pengiriman}',
      );
      for (var i = 0; i < 5 && find.text('Riwayat status').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Riwayat status'), findsOneWidget);
      for (final tahap in ['Siap', 'Kurir', 'Jalan', 'Diterima']) {
        for (var i = 0; i < 5 && find.text(tahap).evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView).last, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(find.text(tahap), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('timeline memberi peringatan untuk status yang tidak konsisten', (
    tester,
  ) async {
    const kasus = [
      (pesanan: 'dikirim', pengiriman: 'kurir'),
      (pesanan: 'diterima', pengiriman: 'jalan'),
      (pesanan: 'diproses', pengiriman: null),
    ];

    for (final status in kasus) {
      final client = MockClient(
        (_) async => _jsonResponse({
          'data': _pesananJson(
            status.pesanan,
            statusPengiriman: status.pengiriman,
          ),
        }),
      );
      await tester.pumpWidget(_detailHost(ApiClient(client: client), 'admin'));
      await tester.pumpAndSettle();

      expect(
        find.text('Status pesanan dan pengiriman tidak sesuai. Silakan hubungi Admin.'),
        findsOneWidget,
        reason: '${status.pesanan}/${status.pengiriman}',
      );
      for (var i = 0; i < 5 && find.text('Riwayat status').evaluate().isEmpty; i++) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(find.text('Riwayat status'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });
}

Widget _warehouseListHost(ApiClient api) =>
    _listHost(api, 'warehouse', tampilanWarehouse: true);

Widget _adminListHost(ApiClient api) => _listHost(api, 'admin');

Widget _detailHost(ApiClient api, String role) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role),
    ),
  ],
  child: const MaterialApp(home: PesananDetailScreen(id: 7)),
);

Widget _listHost(
  ApiClient api,
  String role, {
  bool tampilanWarehouse = false,
}) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role),
    ),
  ],
  child: MaterialApp(
    home: PesananListScreen(
      judul: 'Pengiriman',
      tampilanWarehouse: tampilanWarehouse,
      filter: const [PesananFilter('Semua', null)],
    ),
  ),
);

class _AuthProviderForTest extends AuthProvider {
  _AuthProviderForTest(ApiClient api, this.role) : super(api: api);

  final String role;

  @override
  AppUser? get user => AppUser(nama: 'Pengguna Test', peran: [role]);
}

http.Response _listResponse(String status, {String? statusPengiriman}) =>
    _jsonResponse({
      'data': {
        'items': [_pesananJson(status, statusPengiriman: statusPengiriman)],
        'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
      },
    });

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _pesananJson(
  String status, {
  String? statusPengiriman,
}) => {
  'id': 7,
  'nomor': 'PSN-00007',
  'status': status,
  'status_label': status,
  'total': 250000,
  'jumlah_item': 2,
  'created_at': '2026-11-03T08:15:00+07:00',
  if (status == 'dikonfirmasi') 'dikonfirmasi_at': '2026-11-03T09:15:00+07:00',
  if (status == 'diproses' || status == 'dikirim' || status == 'diterima')
    'diproses_at': '2026-11-03T10:15:00+07:00',
  if (status == 'dikirim' || status == 'diterima')
    'dikirim_at': '2026-11-03T11:15:00+07:00',
  if (status == 'diterima') 'diterima_at': '2026-11-03T12:15:00+07:00',
  'retailer': {'id': 3, 'kode': 'RTL-003', 'nama_toko': 'Toko Sumber Rejeki'},
  if (statusPengiriman != null)
    'pengiriman': {
      'id': 5,
      'status': statusPengiriman,
      'nama_pengemudi': 'Budi Santoso',
      'telepon_pengemudi': '081234567890',
      'nomor_kendaraan': 'BK 1234 AB',
      'created_at': '2026-11-03T08:15:00+07:00',
    },
  'items': const [],
};
