import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:delcheck_flutter/core/api_client.dart';
import 'package:delcheck_flutter/models/app_user.dart';
import 'package:delcheck_flutter/models/retailer_pendaftar.dart';
import 'package:delcheck_flutter/providers/auth_provider.dart';
import 'package:delcheck_flutter/screens/admin_detail_retailer_screen.dart';
import 'package:delcheck_flutter/screens/admin_verifikasi_screen.dart';
import 'package:delcheck_flutter/screens/home_screen.dart';
import 'package:delcheck_flutter/services/register_service.dart';

void main() {
  testWidgets('Home menampilkan verifikasi hanya untuk Sales', (tester) async {
    final statusesByRole = <String, List<String>>{};

    for (final role in ['admin', 'sales', 'retail', 'warehouse']) {
      final statuses = <String>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/pendaftaran-retail')) {
          statuses.add(request.url.queryParameters['status'] ?? '');
          return _jsonResponse(_registrationPage(total: 3));
        }
        return _jsonResponse({
          'data': {
            'items': [],
            'meta': {'total': 0},
          },
        });
      });
      final api = ApiClient(client: client);

      await tester.pumpWidget(_homeHost(api, role));
      await tester.pumpAndSettle();
      statusesByRole[role] = statuses;

      expect(
        find.text('Verifikasi Pendaftaran Retail'),
        role == 'sales' ? findsOneWidget : findsNothing,
        reason: 'role=$role',
      );
      if (role == 'admin') {
        expect(find.text('Menunggu\nverifikasi'), findsNothing);
        expect(find.text('Setujui atau tolak toko mendaftar'), findsNothing);
      }
      if (role == 'sales') {
        expect(
          find.text('Tinjau dan verifikasi pendaftaran Retail.'),
          findsOneWidget,
        );
        expect(find.text('Konfirmasi Pesanan'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      client.close();
    }

    expect(statusesByRole['admin'], isEmpty);
    expect(statusesByRole['sales'], ['menunggu']);
    expect(statusesByRole['retail'], isEmpty);
    expect(statusesByRole['warehouse'], isEmpty);
  });

  testWidgets('Sales membuka daftar Retail dari kartu Home', (tester) async {
    final requestedStatuses = <String>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/pendaftaran-retail')) {
        requestedStatuses.add(request.url.queryParameters['status'] ?? '');
        return _jsonResponse(_registrationPage());
      }
      return _jsonResponse({
        'data': {
          'items': [],
          'meta': {'total': 0},
        },
      });
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_homeHost(api, 'sales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verifikasi Pendaftaran Retail'));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi Pendaftaran'), findsOneWidget);
    expect(requestedStatuses, ['menunggu', 'menunggu']);
    await tester.tap(find.text('Toko Contoh'));
    await tester.pumpAndSettle();
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    client.close();
  });

  testWidgets('Admin tidak dapat membuka daftar melalui screen', (
    tester,
  ) async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount++;
      return _jsonResponse({
        'data': {
          'items': [],
          'meta': {'total': 0},
        },
      });
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_listHost(api, 'admin'));
    await tester.pumpAndSettle();
    expect(
      find.text('Halaman ini hanya dapat diakses oleh Sales.'),
      findsOneWidget,
    );
    expect(requestCount, 0);
    client.close();
  });

  testWidgets('Admin tidak dapat membuka detail melalui screen', (
    tester,
  ) async {
    var requestCount = 0;
    final client = MockClient((_) async {
      requestCount++;
      return _jsonResponse({});
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_detailHost(api, 'admin', _retailer('menunggu')));
    await _openDetail(tester);

    expect(
      find.text('Halaman ini hanya dapat diakses oleh Sales.'),
      findsOneWidget,
    );
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
    expect(requestCount, 0);
    client.close();
  });

  testWidgets('Sales dan Admin sekaligus tidak dapat membuka verifikasi', (
    tester,
  ) async {
    var requestCount = 0;
    final client = MockClient((_) async {
      requestCount++;
      return _jsonResponse({});
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_listHost(api, 'sales', extraRoles: ['admin']));
    await tester.pumpAndSettle();

    expect(
      find.text('Halaman ini hanya dapat diakses oleh Sales.'),
      findsOneWidget,
    );
    expect(requestCount, 0);
    client.close();
  });

  testWidgets('Home tanpa user tidak menampilkan menu verifikasi', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => _jsonResponse({
        'data': {
          'items': [],
          'meta': {'total': 0},
        },
      }),
    );
    final api = ApiClient(client: client);

    await tester.pumpWidget(_homeHost(api, null));
    await tester.pumpAndSettle();

    expect(find.text('Verifikasi Pendaftaran Retail'), findsNothing);
    client.close();
  });

  testWidgets(
    'daftar mempertahankan filter dan pencarian saat memuat halaman',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final page =
            int.tryParse(request.url.queryParameters['page'] ?? '1') ?? 1;
        final status = request.url.queryParameters['status'] ?? 'menunggu';
        final items = page == 1
            ? List.generate(15, (index) => _retailerJson(index + 1, status))
            : [_retailerJson(16, status)];
        return _jsonResponse(
          _registrationPage(items: items, page: page, lastPage: 2),
        );
      });
      final api = ApiClient(client: client);

      await tester.pumpWidget(_listHost(api, 'sales'));
      await tester.pumpAndSettle();
      expect(requests.first.url.queryParameters['status'], 'menunggu');

      await tester.tap(find.text('Disetujui').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ditolak').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Toko dicari');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(requests.last.url.queryParameters['status'], 'ditolak');
      expect(requests.last.url.queryParameters['q'], 'Toko dicari');
      expect(
        requests.map((request) => request.url.queryParameters['status']),
        containsAll(['disetujui', 'ditolak']),
      );

      await tester.drag(find.byType(ListView).last, const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(
        requests.any(
          (request) =>
              request.url.queryParameters['page'] == '2' &&
              request.url.queryParameters['status'] == 'ditolak' &&
              request.url.queryParameters['q'] == 'Toko dicari',
        ),
        isTrue,
      );

      await tester.drag(find.byType(ListView).last, const Offset(0, 4000));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, 500));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['status'], 'ditolak');
      expect(requests.last.url.queryParameters['q'], 'Toko dicari');
      client.close();
    },
  );

  testWidgets('Admin tidak dapat membaca detail pendaftaran', (tester) async {
    var requestCount = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        requestCount++;
        return _jsonResponse({});
      }),
    );

    await tester.pumpWidget(_detailHost(api, 'admin', _retailer('menunggu')));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    expect(
      find.text('Halaman ini hanya dapat diakses oleh Sales.'),
      findsOneWidget,
    );
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Setujui ulang'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
    expect(requestCount, 0);
  });

  testWidgets('Sales melihat tombol sesuai status pendaftaran', (tester) async {
    final api = ApiClient(client: MockClient((_) async => _jsonResponse({})));

    await tester.pumpWidget(_detailHost(api, 'sales', _retailer('menunggu')));
    await tester.pumpAndSettle();
    await _openDetail(tester);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_detailHost(api, 'sales', _retailer('disetujui')));
    await tester.pumpAndSettle();
    await _openDetail(tester);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_detailHost(api, 'sales', _retailer('ditolak')));
    await tester.pumpAndSettle();
    await _openDetail(tester);
    expect(find.text('Setujui ulang'), findsOneWidget);
    expect(find.text('Tolak'), findsNothing);
  });

  testWidgets(
    'Admin dengan role Sales tambahan tetap tidak dapat membuka detail',
    (tester) async {
      final api = ApiClient(client: MockClient((_) async => _jsonResponse({})));

      await tester.pumpWidget(
        _detailHost(api, 'sales', _retailer('menunggu'), extraRoles: ['admin']),
      );
      await tester.pumpAndSettle();
      await _openDetail(tester);

      expect(
        find.text('Halaman ini hanya dapat diakses oleh Sales.'),
        findsOneWidget,
      );
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Tolak'), findsNothing);
    },
  );

  testWidgets('Sales wajib mengisi alasan dan mengirim penolakan', (
    tester,
  ) async {
    http.Request? rejectedRequest;
    final client = MockClient((request) async {
      if (request.method == 'POST') rejectedRequest = request;
      return _jsonResponse({'message': 'Pendaftaran ditolak.'});
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_detailHost(api, 'sales', _retailer('menunggu')));
    await tester.pumpAndSettle();
    await _openDetail(tester);
    await tester.tap(find.text('Tolak'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Tolak'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alasan wajib diisi'), findsOneWidget);
    expect(rejectedRequest, isNull);

    await tester.enterText(find.byType(TextFormField), ' Data tidak sesuai ');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Tolak'),
      ),
    );
    await tester.pumpAndSettle();

    expect(rejectedRequest?.method, 'POST');
    expect(rejectedRequest?.url.path, '/api/admin/pendaftaran-retail/7/tolak');
    expect(jsonDecode(rejectedRequest!.body), {'alasan': 'Data tidak sesuai'});
    client.close();
  });

  testWidgets('Sales menyetujui pendaftaran lewat service yang ada', (
    tester,
  ) async {
    http.Request? approvalRequest;
    final client = MockClient((request) async {
      if (request.method == 'POST') approvalRequest = request;
      return _jsonResponse({'message': 'Pendaftaran disetujui.'});
    });
    final api = ApiClient(client: client);

    await tester.pumpWidget(_detailHost(api, 'sales', _retailer('menunggu')));
    await tester.pumpAndSettle();
    await _openDetail(tester);
    await tester.tap(find.text('Setujui'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Setujui'),
      ),
    );
    await tester.pumpAndSettle();

    expect(approvalRequest?.method, 'POST');
    expect(
      approvalRequest?.url.path,
      '/api/admin/pendaftaran-retail/7/setujui',
    );
    expect(jsonDecode(approvalRequest!.body), isEmpty);
    client.close();
  });

  test(
    'pesan registrasi yang menyebut Admin dinetralkan di UI service',
    () async {
      final client = MockClient(
        (_) async => _jsonResponse({
          'message':
              'Pendaftaran berhasil. Akun Anda menunggu verifikasi Admin.',
        }),
      );
      final service = RegisterService(client: client);

      final message = await service.register(
        RegisterPayload(
          name: 'Pemilik',
          email: 'pemilik@example.test',
          password: 'rahasia123',
          namaToko: 'Toko Contoh',
          alamat: 'Jl. Contoh',
        ),
      );

      expect(
        message,
        'Pendaftaran berhasil. Akun Anda menunggu proses verifikasi.',
      );
      client.close();
    },
  );
}

Widget _homeHost(ApiClient api, String? role) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role),
    ),
  ],
  child: const MaterialApp(home: HomeScreen()),
);

Widget _listHost(
  ApiClient api,
  String role, {
  List<String> extraRoles = const [],
}) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role, extraRoles: extraRoles),
    ),
  ],
  child: const MaterialApp(home: AdminVerifikasiScreen()),
);

Widget _detailHost(
  ApiClient api,
  String role,
  RetailerPendaftar retailer, {
  List<String> extraRoles = const [],
}) => MultiProvider(
  providers: [
    Provider<ApiClient>.value(value: api),
    ChangeNotifierProvider<AuthProvider>.value(
      value: _AuthProviderForTest(api, role, extraRoles: extraRoles),
    ),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => AdminDetailRetailerScreen(retailer: retailer),
            ),
          ),
          child: const Text('Buka detail'),
        ),
      ),
    ),
  ),
);

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.text('Buka detail'));
  await tester.pumpAndSettle();
}

class _AuthProviderForTest extends AuthProvider {
  _AuthProviderForTest(this.api, this.role, {this.extraRoles = const []})
    : super(api: api);

  final ApiClient api;
  final String? role;
  final List<String> extraRoles;

  @override
  AppUser? get user => role == null
      ? null
      : AppUser(nama: 'Test', peran: [role!, ...extraRoles]);
}

RetailerPendaftar _retailer(String status) => RetailerPendaftar(
  id: 7,
  kode: 'RTL-000007',
  namaToko: 'Toko Contoh',
  namaPemilik: 'Pemilik Contoh',
  alamat: 'Jl. Contoh',
  email: 'toko@example.test',
  status: status,
  dibuat: DateTime(2026, 11, 4),
);

Map<String, dynamic> _registrationPage({
  List<Map<String, dynamic>>? items,
  int page = 1,
  int total = 1,
  int lastPage = 1,
}) => {
  'data': {
    'items': items ?? [_retailerJson(7, 'menunggu')],
    'meta': {'halaman': page, 'halaman_terakhir': lastPage, 'total': total},
  },
};

Map<String, dynamic> _retailerJson(int id, String status) => {
  'id': id,
  'kode': 'RTL-${id.toString().padLeft(6, '0')}',
  'nama_toko': id == 7 ? 'Toko Contoh' : 'Toko $id',
  'nama_pemilik': 'Pemilik $id',
  'alamat': 'Jl. Contoh',
  'email': 'toko$id@example.test',
  'status_verifikasi': status,
  'created_at': '2026-11-04T10:00:00+07:00',
};

http.Response _jsonResponse(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);
