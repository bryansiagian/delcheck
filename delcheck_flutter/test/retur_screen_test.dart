import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:delcheck_flutter/core/api_client.dart';
import 'package:delcheck_flutter/models/app_user.dart';
import 'package:delcheck_flutter/providers/auth_provider.dart';
import 'package:delcheck_flutter/screens/retur_detail_screen.dart';
import 'package:delcheck_flutter/screens/retur_list_screen.dart';

void main() {
  testWidgets('aksi edit dan hapus hanya tersedia bagi Retail pada draft', (
    tester,
  ) async {
    final cases = [
      ('retail', 'draft', true),
      ('sales', 'draft', false),
      ('retail', 'diajukan', false),
    ];

    for (final (role, status, tampil) in cases) {
      final client = MockClient((request) async {
        final data = _returJson(status: status);
        if (request.url.path.endsWith('/retur')) {
          return http.Response(
            jsonEncode({
              'data': {
                'items': [data],
                'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(client: client);
      await tester.pumpWidget(_roleHost(api, role));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#RT-42').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Edit Draft'),
        findsNWidgets(tampil ? 1 : 0),
        reason: 'role=$role status=$status',
      );
      expect(
        find.text('Hapus'),
        findsNWidgets(tampil ? 1 : 0),
        reason: 'role=$role status=$status',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('aksi keputusan hanya tersedia bagi Sales pada Return diajukan', (
    tester,
  ) async {
    for (final (role, status, tampil) in [
      ('sales', 'diajukan', true),
      ('sales', 'disetujui', false),
      ('sales', 'ditolak', false),
      ('retail', 'diajukan', false),
      ('admin', 'diajukan', false),
      ('warehouse', 'diajukan', false),
    ]) {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({'data': _returJson(status: status)}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await tester.pumpWidget(_detailHost(ApiClient(client: client), role));
      await tester.pumpAndSettle();
      expect(
        find.text('Setujui'),
        findsNWidgets(tampil ? 1 : 0),
        reason: 'role=$role status=$status',
      );
      expect(
        find.text('Tolak'),
        findsNWidgets(tampil ? 1 : 0),
        reason: 'role=$role status=$status',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });

  testWidgets('Sales mengonfirmasi sebelum menyetujui Return', (tester) async {
    var status = 'diajukan';
    var jumlahSetujui = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'data': _returJson(status: status)}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/api/retur/42/setujui');
      jumlahSetujui++;
      status = 'disetujui';
      return http.Response(
        jsonEncode({'data': _returJson(status: status)}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(_detailHost(ApiClient(client: client), 'sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    expect(find.text('Setujui Return?'), findsOneWidget);
    expect(jumlahSetujui, 0);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(jumlahSetujui, 0);

    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setujui').last);
    await tester.pumpAndSettle();
    expect(jumlahSetujui, 1);
    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.text('Return berhasil disetujui.'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
    client.close();
  });

  testWidgets('Sales wajib memberi alasan sebelum menolak Return', (
    tester,
  ) async {
    var jumlahTolak = 0;
    String? alasanDikirim;
    var status = 'diajukan';
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'data': _returJson(status: status)}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.method, 'POST');
      expect(request.url.path, '/api/retur/42/tolak');
      alasanDikirim =
          (jsonDecode(request.body) as Map<String, dynamic>)['alasan']
              as String;
      jumlahTolak++;
      status = 'ditolak';
      return http.Response(
        jsonEncode({'data': _returJson(status: status)}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(_detailHost(ApiClient(client: client), 'sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Tolak').last);
    await tester.pumpAndSettle();
    expect(find.text('Alasan penolakan wajib diisi.'), findsOneWidget);
    expect(jumlahTolak, 0);

    await tester.enterText(find.byType(TextField), '  Barang rusak  ');
    await tester.tap(find.text('Tolak').last);
    await tester.pumpAndSettle();
    expect(jumlahTolak, 1);
    expect(alasanDikirim, 'Barang rusak');
    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.text('Return berhasil ditolak.'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
    client.close();
  });

  testWidgets('Retail dapat mengajukan Draft valid dan aksi edit/hapus hilang', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var jumlahAjukan = 0;
    var status = 'draft';
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/retur/42') {
        return http.Response(
          jsonEncode({'data': _returJson(status: status, lengkap: true)}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/retur/42/ajukan') {
        jumlahAjukan++;
        status = 'diajukan';
        return http.Response(
          jsonEncode({'data': _returJson(status: status, lengkap: true)}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/retur/42/foto/1') {
        return http.Response.bytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p8sAAAAASUVORK5CYII=',
          ),
          200,
          headers: {'content-type': 'image/png'},
        );
      }
      return http.Response(
        jsonEncode({'message': 'Request tidak diharapkan.'}),
        404,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(client: client)..token = 'retail-token';
    await tester.pumpWidget(_detailHost(api, 'retail'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Draft'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    expect(find.text('Ajukan Return'), findsOneWidget);
    final appBarRect = tester.getRect(find.byType(AppBar));
    final bodyRect = tester.getRect(find.byType(RefreshIndicator));
    final actionRect = tester.getRect(find.text('Ajukan Return'));
    expect(bodyRect.top, greaterThanOrEqualTo(appBarRect.bottom));
    expect(bodyRect.bottom, lessThanOrEqualTo(actionRect.top));
    expect(actionRect.bottom, lessThanOrEqualTo(640));

    await tester.scrollUntilVisible(
      find.text('Retailer / toko'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Retailer / toko'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Ajukan Return')).dy, actionRect.top);

    await tester.tap(find.text('Ajukan Return'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Pastikan alasan, jenis penyelesaian, dan foto kondisi produk sudah benar. Setelah diajukan, draft tidak dapat diedit atau dihapus.',
      ),
      findsOneWidget,
    );
    expect(jumlahAjukan, 0);
    await tester.tap(find.text('Periksa lagi'));
    await tester.pumpAndSettle();
    expect(jumlahAjukan, 0);

    await tester.tap(find.text('Ajukan Return'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajukan Return').last);
    await tester.pumpAndSettle();

    expect(jumlahAjukan, 1);
    expect(find.text('Diajukan'), findsOneWidget);
    expect(find.text('Return berhasil diajukan kepada Sales.'), findsOneWidget);
    expect(find.text('Edit Draft'), findsNothing);
    expect(find.text('Hapus'), findsNothing);
    expect(find.text('Ajukan Return'), findsNothing);

    client.close();
  });

  testWidgets('Draft dengan syarat pengajuan belum lengkap ditolak di UI', (
    tester,
  ) async {
    var jumlahAjukan = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/retur/42') {
        return http.Response(
          jsonEncode({'data': _returJson(status: 'draft')}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'POST') jumlahAjukan++;
      return http.Response(
        jsonEncode({'data': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(_detailHost(ApiClient(client: client), 'retail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajukan Return'));
    await tester.pumpAndSettle();

    expect(
      find.text('Pilih jenis penyelesaian sebelum mengajukan.'),
      findsOneWidget,
    );
    expect(jumlahAjukan, 0);
    client.close();
  });

  testWidgets('layout detail Draft tetap terbaca pada layar HP sempit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/retur/42') {
        return http.Response(
          jsonEncode({'data': _returJson(status: 'draft')}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    await tester.pumpWidget(_detailHost(ApiClient(client: client), 'retail'));
    await tester.pumpAndSettle();

    final appBarRect = tester.getRect(find.byType(AppBar));
    final bodyRect = tester.getRect(find.byType(RefreshIndicator));
    final actionRect = tester.getRect(find.text('Ajukan Return'));
    expect(bodyRect.top, greaterThanOrEqualTo(appBarRect.bottom));
    expect(bodyRect.bottom, lessThanOrEqualTo(actionRect.top));
    expect(actionRect.bottom, lessThanOrEqualTo(568));
    expect(find.text('Edit Draft'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Alur status'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Alur status'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Ajukan Return')).dy, actionRect.top);
    client.close();
  });

  testWidgets('hapus draft meminta konfirmasi lalu refresh daftar', (
    tester,
  ) async {
    var jumlahDaftar = 0;
    var jumlahHapus = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/retur')) {
        jumlahDaftar++;
        return http.Response(
          jsonEncode({
            'data': {
              'items': [_returJson(status: 'draft')],
              'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'DELETE' &&
          request.url.path.endsWith('/retur/42')) {
        jumlahHapus++;
        return http.Response(
          jsonEncode({
            'message': 'Draft Return berhasil dihapus.',
            'data': null,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': _returJson(status: 'draft')}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(client: client)..token = 'retail-token';
    await tester.pumpWidget(_roleHost(api, 'retail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#RT-42').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    expect(
      find.text('Draft yang dihapus tidak dapat dikembalikan.'),
      findsOneWidget,
    );
    expect(jumlahHapus, 0);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(jumlahHapus, 0);

    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Draft'));
    await tester.pumpAndSettle();

    expect(jumlahHapus, 1);
    expect(jumlahDaftar, 2);
    expect(find.text('Draft Return berhasil dihapus.'), findsOneWidget);
    client.close();
  });

  testWidgets('error hapus ditampilkan dan detail tetap terbuka', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/retur')) {
        return http.Response(
          jsonEncode({
            'data': {
              'items': [_returJson(status: 'draft')],
              'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.method == 'DELETE') {
        return http.Response(
          jsonEncode({'message': 'Draft sedang diproses.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'data': _returJson(status: 'draft')}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(client: client);
    await tester.pumpWidget(_roleHost(api, 'retail'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('#RT-42').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Draft'));
    await tester.pumpAndSettle();

    expect(find.text('Draft sedang diproses.'), findsOneWidget);
    expect(find.text('Edit Draft'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    client.close();
  });

  testWidgets('daftar membuka detail terbaru dari ID Return terpilih', (
    tester,
  ) async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/retur')) {
        return http.Response(
          jsonEncode({
            'data': {
              'items': [_returJson()],
              'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path.endsWith('/retur/42')) {
        return http.Response(
          jsonEncode({'data': _returJson()}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final api = ApiClient(client: client)..token = 'test-token';

    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: api,
        child: const MaterialApp(home: ReturListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#RT-42'), findsOneWidget);
    expect(find.text('Toko Utama'), findsOneWidget);
    expect(find.text('Kopi Bubuk · 3'), findsOneWidget);

    await tester.tap(find.text('#RT-42'));
    await tester.pumpAndSettle();

    expect(paths, contains('/api/retur/42'));
    expect(find.text('Detail Return'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Nomor pesanan'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Informasi pesanan'), findsOneWidget);
    expect(find.text('Pesanan-42'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Informasi Return'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Informasi Return'), findsOneWidget);

    client.close();
  });

  testWidgets('tombol Buat Return hanya tampil untuk Retail', (tester) async {
    Future<ApiClient> api() async => ApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {
              'items': [],
              'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 0},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );

    final salesApi = await api();
    await tester.pumpWidget(_roleHost(salesApi, 'sales'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Return'), findsNothing);

    final retailApi = await api();
    await tester.pumpWidget(_roleHost(retailApi, 'retail'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Return'), findsOneWidget);
  });

  testWidgets('filter Sales tanpa Draft dan default ke Diajukan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? requestedPath;
    String? requestedStatus;
    final client = MockClient((request) async {
      requestedPath = request.url.path;
      requestedStatus = request.url.queryParameters['status'];
      expect(request.method, 'GET');
      return http.Response(
        jsonEncode({
          'data': {
            'items': [_returJson(status: 'diajukan')],
            'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 1},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(_roleHost(ApiClient(client: client), 'sales'));
    await tester.pumpAndSettle();

    expect(requestedPath, '/api/retur');
    expect(requestedStatus, 'diajukan');
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Draft'), findsNothing);
    expect(find.text('Diajukan'), findsNWidgets(2));
    expect(find.text('Disetujui'), findsOneWidget);
    expect(find.text('Ditolak'), findsOneWidget);
    expect(find.text('Dijadwalkan'), findsOneWidget);
    expect(find.text('Dijemput'), findsOneWidget);
    final filterDiajukan = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Diajukan').first,
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(filterDiajukan.selected, isTrue);
    expect(find.text('#RT-42'), findsOneWidget);
    expect(find.text('Diajukan'), findsNWidgets(2));
    expect(find.text('Buat Return'), findsNothing);
    client.close();
  });

  testWidgets('filter Sales meminta semua status non-draft dan tiap status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final daftarStatus = [
      'diajukan',
      'disetujui',
      'ditolak',
      'dijadwalkan',
      'dijemput',
    ];
    final statusDiminta = <String?>[];
    final client = MockClient((request) async {
      final status = request.url.queryParameters['status'];
      statusDiminta.add(status);
      final statuses = status == null ? daftarStatus : [status];
      final items = [
        for (var i = 0; i < statuses.length; i++)
          _returJson(status: statuses[i], id: 100 + i),
      ];
      return http.Response(
        jsonEncode({
          'data': {
            'items': items,
            'meta': {
              'halaman': 1,
              'halaman_terakhir': 1,
              'total': items.length,
            },
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(_roleHost(ApiClient(client: client), 'sales'));
    await tester.pumpAndSettle();
    expect(statusDiminta, ['diajukan']);

    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(statusDiminta.last, isNull);
    for (var i = 0; i < daftarStatus.length; i++) {
      expect(find.text('#RT-${100 + i}'), findsOneWidget);
    }

    const filters = {
      'Diajukan': 'diajukan',
      'Disetujui': 'disetujui',
      'Ditolak': 'ditolak',
      'Dijadwalkan': 'dijadwalkan',
      'Dijemput': 'dijemput',
    };
    for (final entry in filters.entries) {
      final filter = find.ancestor(
        of: find.text(entry.key).first,
        matching: find.byType(ChoiceChip),
      );
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(statusDiminta.last, entry.value);
      expect(find.text('#RT-100'), findsOneWidget);
      expect(find.text('#RT-101'), findsNothing);
    }
    client.close();
  });

  testWidgets('filter role selain Sales tetap menyertakan Draft dan Semua', (
    tester,
  ) async {
    for (final role in ['retail', 'admin', 'warehouse']) {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['status'], isNull);
        return http.Response(
          jsonEncode({
            'data': {
              'items': [],
              'meta': {'halaman': 1, 'halaman_terakhir': 1, 'total': 0},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      await tester.pumpWidget(_roleHost(ApiClient(client: client), role));
      await tester.pumpAndSettle();
      expect(find.text('Draft'), findsOneWidget, reason: 'role=$role');
      expect(find.text('Semua'), findsOneWidget, reason: 'role=$role');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }
  });
}

Widget _roleHost(ApiClient api, String role) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role),
    ),
  ],
  child: const MaterialApp(home: ReturListScreen()),
);

Widget _detailHost(ApiClient api, String role) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role),
    ),
  ],
  child: const MaterialApp(home: ReturDetailScreen(returId: 42)),
);

class _AuthProviderForTest extends AuthProvider {
  _AuthProviderForTest(ApiClient api, this.role) : super(api: api);

  final String role;

  @override
  AppUser? get user => AppUser(nama: 'Test', peran: [role]);
}

Map<String, dynamic> _returJson({
  String status = 'diajukan',
  bool lengkap = false,
  int id = 42,
}) => {
  'id': id,
  'nomor': 'RT-$id',
  'status': status,
  'status_label': switch (status) {
    'draft' => 'Draft',
    'disetujui' => 'Disetujui',
    'ditolak' => 'Ditolak',
    _ => 'Diajukan',
  },
  'created_at': '2026-11-03T10:00:00+07:00',
  'pesanan': {'id': 7, 'nomor': 'Pesanan-42'},
  'retailer': {'id': 4, 'kode': 'RTL-04', 'nama_toko': 'Toko Utama'},
  'item': {
    'id': 9,
    'item_pesanan_id': 12,
    'produk_id': 15,
    'produk': {
      'id': 15,
      'kode': 'PRD-15',
      'nama': 'Kopi Bubuk',
      'satuan': 'pcs',
    },
    'qty': 3,
  },
  'alasan': 'Kemasan rusak',
  'jenis_penyelesaian': lengkap ? 'refund' : null,
  'foto_kondisi': lengkap
      ? [
          {
            'id': 1,
            'jenis': 'kondisi_produk',
            'url': '/api/retur/42/foto/1',
            'mime': 'image/png',
          },
        ]
      : [],
  'foto_penjemputan': [],
};
