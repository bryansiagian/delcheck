# 05 — Dokumentasi Frontend Flutter

## Bootstrap, state, dan login

`lib/main.dart`: `main()` memanggil `WidgetsFlutterBinding.ensureInitialized()` lalu `runApp(DelCheckApp())`. `DelCheckApp` membungkus tree dengan `MultiProvider`: satu `ApiClient`, satu `AuthProvider` yang menjalankan `mulai()`. `MaterialApp` memakai Material 3 dan tema seed indigo. `AuthGate` membaca `AuthProvider.status` dengan `context.watch`: `memeriksa` → spinner, `masuk` → `HomeScreen`, `keluar` → `LoginScreen`.

`AuthProvider` (`providers/auth_provider.dart`) adalah `ChangeNotifier`, menyimpan `AuthStatus`, `AppUser?`, `ApiClient`, `AuthService`, secure storage. `mulai()` membaca key `auth_token`, mengisi token client, meminta `/auth/me`, atau membersihkan sesi; `login(identitas,password)` menerima token, menulis secure storage, mendapat user, lalu notify; `logout()` mencoba revoke server kemudian selalu membersihkan sesi lokal. Callback `ApiClient.onUnauthorized` membersihkan sesi saat 401.

`ApiClient` (`core/api_client.dart`) mengirim `Accept`/`Content-Type: application/json`, Authorization Bearer jika token ada, timeout 20 detik. `get/post/put/delete` mengembalikan `Map<String,dynamic>`, `_send` parsing JSON, mengecek HTTP status dan memetakan timeout/socket/client errors ke `ApiException`. `RegisterService` adalah pengecualian: menggunakan `http.Client` sendiri dan parser error sendiri.

## Pemetaan screen

| Screen | Class/state penting | Data/service dan perilaku |
|---|---|---|
| `screens/home_screen.dart` | `HomeScreen`, `_HomeScreenState` | Ringkasan retailer menunggu melalui `AdminService`; produk/order/stok ringkasan melalui API. Navigasi berdasarkan role; menu verifikasi dan akun Admin, Pengiriman/Produk/Stok Admin/Warehouse, Pesan Produk Retail |
| `screens/login_screen.dart` | `LoginScreen`, `_LoginScreenState` | Form + controller; validasi lokal, AuthProvider.login, error ditampilkan; mendorong `RegisterScreen` |
| `screens/register_screen.dart` | `RegisterScreen`, state wilayah berjenjang | `RegisterService.fetchWilayah` provinsi/kota/kecamatan; submit payload kemudian `RegisterSuccessScreen` |
| `screens/register_success_screen.dart` | Stateless | Pesan keberhasilan; kembali ke root dengan `popUntil` |
| `screens/admin_verifikasi_screen.dart` | Stateful; `_muatAwal`, `_muatLagi`, `_gantiStatus`, `_onCari`, `_buka` | `AdminService.daftar`, pagination scroll 200px, debounce 500ms, request id cegah stale response; detail menerima `RetailerPendaftar` |
| `screens/admin_detail_retailer_screen.dart` | Stateful; `_setujui`, `_tolak`, `_jalankan` | Menerima object `retailer` dari list; setujui konfirmasi, tolak dialog alasan, service admin, pop(true) agar list refresh. Detail endpoint `show` tidak dipanggil dari screen ini |
| `screens/admin_pengguna_screen.dart` | Stateful; `_muatAwal`, `_muatLagi`, `_ubahStatus` | Search/role/status, pagination, dialog aktivasi/deaktivasi, API `PenggunaService`; mencegah toggle self dari UI dan backend |
| `screens/produk_list_screen.dart`, `produk_form_screen.dart` | list dan form produk | `ProdukService.daftar/tambah/ubah/hapus`; screen CRUD sesuai permission server |
| `screens/stok_list_screen.dart`, `stok_detail_screen.dart` | list/detail | `StokService`; pencarian, filter menipis, mutasi dan histori paginasi |
| `screens/pesanan_list_screen.dart`, `pesanan_detail_screen.dart`, `buat_pesanan_screen.dart` | list/detail/create | `PesananService`; filter status, pagination; aksi menyesuaikan role-status; sheet pengiriman reusable |

## Model JSON

Model Dart manual parse JSON tanpa generator: `AppUser`, `Pengguna`, `RetailerPendaftar` (juga `SalesUser`), `Wilayah`, `Produk`, `StokProduk`, `MutasiStok`, `Pesanan`, `ItemPesanan`, `PengirimanPesanan`. Beberapa parser toleran fallback nama field. Waktu `Pengguna` diubah ke local; parser retailer/pesanan memakai `DateTime.tryParse` tanpa normalisasi seragam.

## Konsep Flutter dengan contoh repo

- `StatefulWidget`: screen yang punya state lokal; `createState()` membuat objek `State` terpisah.
- `BuildContext`: digunakan untuk `context.read<ApiClient>()`, `context.watch<AuthProvider>()`, Theme/Navigator/SnackBar.
- `initState()`: pada daftar verifikasi membuat service, menautkan scroll listener, menjalankan `_muatAwal()`.
- `dispose()`: screen membuang controller/scroll/timer agar resource tak tertahan.
- `setState()`: mengganti flag loading, error, item, filter; menyebabkan build ulang.
- `Future`, `async/await`: service HTTP asynchronous; screen menunggu hasil tanpa memblokir UI.
- Provider: dependency global untuk ApiClient dan auth; `ChangeNotifier` memicu listener UI.
- Navigator: `Navigator.push(MaterialPageRoute(...))`, detail menerima object atau ID; hasil detail list memakai `Navigator.pop(true)`.
- controller/scroll/debounce: `TextEditingController`, `ScrollController`, `Timer(Duration(milliseconds:500))` dipakai pada daftar verifikasi.
- JSON: `jsonDecode` dan factory `fromJson`, bukan code generation.
- Error: catch `ApiException`, cek mounted sebelum update state sesudah await.

**[KESIMPULAN ANALISIS]** Tidak ditemukan `FutureBuilder`, `Consumer` pada screen yang diperiksa, ataupun state management global untuk data bisnis selain auth. Pola utama adalah service + local state.
