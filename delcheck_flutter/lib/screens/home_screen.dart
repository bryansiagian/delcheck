import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/pesanan.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import '../services/produk_service.dart';
import '../services/stok_service.dart';
import 'admin_verifikasi_screen.dart';
import 'buat_pesanan_screen.dart';
import 'pesanan_detail_screen.dart';
import 'pesanan_list_screen.dart';
import 'produk_list_screen.dart';
import 'stok_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Palet Warna Sesuai Tailwind HTML
  static const Color _bgSurface = Color(0xFFF1F5F9);
  static const Color _primary = Color(0xFF2563EB);
  static const Color _primaryDark = Color(0xFF1D4ED8);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);

  bool _memuat = true;

  // Metrik Admin (Pengiriman)
  int _siapDikirim = 0;
  int _bersamaKurir = 0;
  int _dalamJalan = 0;
  int _diterima = 0;

  // Metrik Sales (Pesanan & Akun)
  int _pesananBaruSales = 0;
  int _tokoDisetujui = 0;
  int _tokoMenungguVerifikasi = 0;

  // Metrik Warehouse (Produk & Stock)
  int _totalProdukWarehouse = 0;
  int _produkAktifWarehouse = 0;
  int _stokMenipisWarehouse = 0;
  int _stokHabisWarehouse = 0;

  // Metrik Retail (Pesanan Toko)
  int _retailMenunggu = 0;
  int _retailDalamPerjalanan = 0;
  int _retailDiterima = 0;
  Pesanan? _retailPesananAktif;

  List<Pesanan> _pesananTerbaru = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _muatDataDashboard();
    });
  }

  Future<void> _muatDataDashboard() async {
    if (!mounted) return;
    setState(() => _memuat = true);

    final api = context.read<ApiClient>();
    final user = context.read<AuthProvider>().user;
    final isAdmin = user?.punyaPeran('admin') ?? false;
    final isSales = user?.punyaPeran('sales') ?? false;
    final isWarehouse = user?.punyaPeran('warehouse') ?? false;
    final isRetail = user?.punyaPeran('retail') ?? false;

    try {
      // 1. Data Pesanan untuk Admin, Sales, dan Retail
      if (isAdmin || isSales || isRetail) {
        final res = await api.get('/pesanan?per_page=30');
        final data = res['data'];
        final List rawItems = data is List
            ? data
            : (data is Map && data['items'] is List ? data['items'] : []);

        final listPesanan = rawItems
            .whereType<Map<String, dynamic>>()
            .map(Pesanan.fromJson)
            .toList();

        if (isAdmin) {
          int siap = 0, kurir = 0, jalan = 0, selesai = 0;
          for (final p in listPesanan) {
            final s = p.status.toLowerCase();
            if (s == 'dikonfirmasi') siap++;
            if (s == 'diproses') kurir++;
            if (s == 'dikirim') jalan++;
            if (s == 'diterima' || s == 'selesai') selesai++;
          }
          _siapDikirim = siap;
          _bersamaKurir = kurir;
          _dalamJalan = jalan;
          _diterima = selesai;
        }

        if (isSales) {
          int baru = 0;
          for (final p in listPesanan) {
            if (p.status.toLowerCase().contains('menunggu')) baru++;
          }
          _pesananBaruSales = baru;

          try {
            final adminService = AdminService(api);
            final resMenunggu = await adminService.daftar(status: 'menunggu');
            _tokoMenungguVerifikasi = resMenunggu.total;

            final resDisetujui = await adminService.daftar(status: 'disetujui');
            _tokoDisetujui = resDisetujui.total;
          } catch (_) {}
        }

        if (isRetail) {
          int menunggu = 0, jalan = 0, diterima = 0;
          for (final p in listPesanan) {
            final s = p.status.toLowerCase();
            if (s.contains('menunggu')) {
              menunggu++;
            } else if (s == 'dikirim') {
              jalan++;
            } else if (s == 'diterima' || s == 'selesai') {
              diterima++;
            }
          }
          _retailMenunggu = menunggu;
          _retailDalamPerjalanan = jalan;
          _retailDiterima = diterima;

          // Ambil pesanan berjalan (yang belum diterima / belum dibatalkan)
          final berjalan = listPesanan.where((p) {
            final s = p.status.toLowerCase();
            return s != 'diterima' && s != 'selesai' && s != 'ditolak' && s != 'dibatalkan';
          }).toList();

          _retailPesananAktif = berjalan.isNotEmpty
              ? berjalan.first
              : (listPesanan.isNotEmpty ? listPesanan.first : null);
        }

        _pesananTerbaru = listPesanan.take(3).toList();
      }

      // 2. Data khusus Warehouse (Katalog Produk & Stock)
      if (isWarehouse) {
        try {
          final produkService = ProdukService(api);
          final resProduk = await produkService.daftar(halaman: 1);
          final resProdukAktif =
              await produkService.daftar(status: 'aktif', halaman: 1);
          _totalProdukWarehouse = resProduk.total;
          _produkAktifWarehouse = resProdukAktif.total;
        } catch (_) {}

        try {
          final stokService = StokService(api);
          final resStok = await stokService.daftar(halaman: 1);
          int menipis = 0, habis = 0;
          for (final s in resStok.items) {
            if (s.habis) {
              habis++;
            } else if (s.menipis) {
              menipis++;
            }
          }
          _stokMenipisWarehouse = menipis;
          _stokHabisWarehouse = habis;
        } catch (_) {}
      }
    } catch (_) {
      // Fallback
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _keluar(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar Akun',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari sesi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: _textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yakin == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  void _buka(BuildContext context, Widget layar) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => layar));
    _muatDataDashboard();
  }

  void _bukaPesananRetail(BuildContext context) {
    _buka(
      context,
      const PesananListScreen(
        judul: 'Pesanan Saya',
        bisaBuat: true,
        tampilanRetail: true,
        filter: [
          PesananFilter('Semua', null, icon: Icons.layers_rounded),
          PesananFilter('Menunggu', 'menunggu_konfirmasi_sales',
              icon: Icons.hourglass_top_rounded),
          PesananFilter('Diproses', 'dikonfirmasi,diproses',
              icon: Icons.inventory_2_rounded),
          PesananFilter('Dalam perjalanan', 'dikirim',
              icon: Icons.local_shipping_rounded),
          PesananFilter('Diterima', 'diterima,selesai',
              icon: Icons.check_circle_rounded),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final namaUser = user?.nama ?? 'User';
    final initial = namaUser.isNotEmpty ? namaUser[0].toUpperCase() : 'U';

    final admin = user?.punyaPeran('admin') ?? false;
    final sales = user?.punyaPeran('sales') ?? false;
    final warehouse = user?.punyaPeran('warehouse') ?? false;
    final retail = user?.punyaPeran('retail') ?? false;

    return Scaffold(
      backgroundColor: _bgSurface,
      body: RefreshIndicator(
        color: _primary,
        onRefresh: _muatDataDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ================= 1. HEADER BIRU GRADIENT =================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 48),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_primaryDark, Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(36),
                    bottomRight: Radius.circular(36),
                  ),
                ),
                child: Column(
                  children: [
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.check_circle,
                                      color: _primary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'DelCheck',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _keluar(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Greeting Row
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selamat datang,',
                                style: TextStyle(
                                  color: Color(0xFFDBEAFE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      namaUser,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          retail
                                              ? Icons.storefront_outlined
                                              : (warehouse
                                                  ? Icons.warehouse_rounded
                                                  : (sales
                                                      ? Icons.work_outline_rounded
                                                      : Icons.shield_outlined)),
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          user?.peranUtama ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ================= 2. DASHBOARD KHUSUS RETAIL =================
              if (retail) ...[
                // Overlapping Summary Card 3 Kolom
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildMetricItem(
                            icon: Icons.hourglass_top_rounded,
                            iconColor: const Color(0xFFF97316),
                            bgColor: const Color(0xFFFFEDD5),
                            count: _memuat ? '...' : '$_retailMenunggu',
                            label: 'Menunggu\nkonfirmasi',
                          ),
                          Container(
                              width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.local_shipping_rounded,
                            iconColor: const Color(0xFF4F46E5),
                            bgColor: const Color(0xFFE0E7FF),
                            count: _memuat ? '...' : '$_retailDalamPerjalanan',
                            label: 'Dalam\nperjalanan',
                          ),
                          Container(
                              width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF0D9488),
                            bgColor: const Color(0xFFCCFBF1),
                            count: _memuat ? '...' : '$_retailDiterima',
                            label: 'Diterima',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Section Layanan Retail
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Layanan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Service 1: Pesan Produk (Gradient to Blue-50)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primary.withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.add_shopping_cart_rounded,
                                      color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pesan Produk',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _textDark,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Pilih produk dan kirim pesanan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _buka(context, const BuatPesananScreen()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Mulai memesan',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Service 2: Pesanan Saya (Gradient to Indigo-50)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5).withOpacity(0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded,
                                      color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Pesanan Saya',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: _textDark,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0E7FF),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$_retailDalamPerjalanan sedang dikirim',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF4F46E5),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Pantau status barang diterima',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () => _bukaPesananRetail(context),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primary,
                                  side: const BorderSide(
                                      color: _primary, width: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Lihat pesanan',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section Pesanan Berjalan (Live Order Tracker)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pesanan berjalan',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _bukaPesananRetail(context),
                            child: const Text('Lihat semua',
                                style: TextStyle(
                                    color: _primary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_retailPesananAktif != null)
                        _buildLiveOrderCard(_retailPesananAktif!)
                      else
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 40, color: Color(0xFFCBD5E1)),
                                SizedBox(height: 8),
                                Text(
                                  'Belum ada pesanan yang sedang berjalan.',
                                  style: TextStyle(
                                      color: _textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // ================= 3. DASHBOARD KHUSUS WAREHOUSE =================
              if (warehouse) ...[
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildMetricItem(
                            icon: Icons.inventory_2_rounded,
                            iconColor: _primary,
                            bgColor: const Color(0xFFDBE1FF),
                            count: _memuat ? '...' : '$_totalProdukWarehouse',
                            label: 'Total produk',
                          ),
                          Container(
                              width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.warning_amber_rounded,
                            iconColor: const Color(0xFF9D4300),
                            bgColor: const Color(0xFFFFDBCA),
                            count: _memuat ? '...' : '$_stokMenipisWarehouse',
                            label: 'Stock menipis',
                          ),
                          Container(
                              width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.remove_shopping_cart_rounded,
                            iconColor: const Color(0xFFBA1A1A),
                            bgColor: const Color(0xFFFFDAD6),
                            count: _memuat ? '...' : '$_stokHabisWarehouse',
                            label: 'Stock habis',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Layanan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF004AC6)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.inventory_2_rounded,
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Produk',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: _textDark)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDBE1FF),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$_produkAktifWarehouse produk aktif',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _primary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _buka(context, const ProdukListScreen()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Buka produk',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF656D84), Color(0xFF4D556B)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.layers_rounded,
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Stock',
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: _textDark)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFDBCA),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '${_stokMenipisWarehouse + _stokHabisWarehouse} perlu diperhatikan',
                                          style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF9D4300)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _buka(context, const StokListScreen()),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primary,
                                  side: const BorderSide(
                                      color: _primary, width: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Buka stock',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ================= 4. DASHBOARD KHUSUS SALES =================
              if (sales) ...[
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildMetricItem(
                            icon: Icons.assignment_outlined,
                            iconColor: const Color(0xFFF97316),
                            bgColor: const Color(0xFFFFEDD5),
                            count: _memuat ? '...' : '$_pesananBaruSales',
                            label: 'Pesanan baru',
                          ),
                          Container(
                              width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF0D9488),
                            bgColor: const Color(0xFFCCFBF1),
                            count: _memuat ? '...' : '$_tokoDisetujui',
                            label: 'Disetujui',
                          ),
                          Container(
                              width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.how_to_reg_outlined,
                            iconColor: _primary,
                            bgColor: const Color(0xFFDBEAFE),
                            count:
                                _memuat ? '...' : '$_tokoMenungguVerifikasi',
                            label: 'Menunggu\nverifikasi',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Layanan',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _textDark)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.fact_check_outlined,
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Pesanan',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: _textDark)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFEDD5),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$_pesananBaruSales menunggu konfirmasi',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFF97316)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                          'Periksa dan konfirmasi pesanan dari retail',
                                          style: TextStyle(
                                              fontSize: 12, color: _textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  _buka(
                                    context,
                                    const PesananListScreen(
                                      judul: 'Konfirmasi Pesanan',
                                      tampilkanToko: true,
                                      tampilanSales: true,
                                      filter: [
                                        PesananFilter('Menunggu',
                                            'menunggu_konfirmasi_sales',
                                            icon: Icons.pending_actions_rounded),
                                        PesananFilter('Disetujui',
                                            'dikonfirmasi,diproses,dikirim,diterima,selesai',
                                            icon: Icons.check_circle_rounded),
                                        PesananFilter('Ditolak', 'ditolak',
                                            icon: Icons.cancel_outlined),
                                        PesananFilter('Semua', null,
                                            icon: Icons.layers_rounded),
                                      ],
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Buka pesanan',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.people_alt_outlined,
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Kelola Akun',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: _textDark)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFEDD5),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$_tokoMenungguVerifikasi menunggu verifikasi',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFF97316)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                          'Verifikasi toko baru dan atur status akun retail',
                                          style: TextStyle(
                                              fontSize: 12, color: _textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () =>
                                    _buka(context, const AdminVerifikasiScreen()),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _primary,
                                  side: const BorderSide(
                                      color: _primary, width: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Buka kelola akun',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ================= 5. DASHBOARD KHUSUS ADMIN (PENGIRIMAN) =================
              if (admin) ...[
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _buildMetricItem(
                            icon: Icons.inventory_2_rounded,
                            iconColor: const Color(0xFFF97316),
                            bgColor: const Color(0xFFFFEDD5),
                            count: _memuat ? '...' : '$_siapDikirim',
                            label: 'Siap dikirim',
                          ),
                          Container(
                              width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.person_pin_circle_rounded,
                            iconColor: const Color(0xFF4F46E5),
                            bgColor: const Color(0xFFE0E7FF),
                            count: _memuat ? '...' : '$_bersamaKurir',
                            label: 'Bersama kurir',
                          ),
                          Container(
                              width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.local_shipping_rounded,
                            iconColor: _primary,
                            bgColor: const Color(0xFFDBEAFE),
                            count: _memuat ? '...' : '$_dalamJalan',
                            label: 'Dalam jalan',
                          ),
                          Container(
                              width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                          _buildMetricItem(
                            icon: Icons.check_circle_rounded,
                            iconColor: const Color(0xFF0D9488),
                            bgColor: const Color(0xFFCCFBF1),
                            count: _memuat ? '...' : '$_diterima',
                            label: 'Diterima',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Layanan',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _textDark)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.06),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.local_shipping_rounded,
                                      color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Pengiriman',
                                              style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: _textDark)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFEDD5),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$_siapDikirim perlu dikirim',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFF97316)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                          'Catat pengemudi dan perbarui status pengiriman pesanan',
                                          style: TextStyle(
                                              fontSize: 12, color: _textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  _buka(
                                    context,
                                    const PesananListScreen(
                                      judul: 'Pengiriman',
                                      tampilkanToko: true,
                                      filter: [
                                        PesananFilter('Semua', null,
                                            icon: Icons.layers_rounded),
                                        PesananFilter(
                                            'Siap dikirim', 'dikonfirmasi',
                                            icon: Icons.inventory_2_rounded),
                                        PesananFilter('Bersama kurir', 'diproses',
                                            icon: Icons.person_pin_circle_rounded),
                                        PesananFilter(
                                            'Dalam perjalanan', 'dikirim',
                                            icon: Icons.local_shipping_rounded),
                                        PesananFilter(
                                            'Diterima', 'diterima,selesai',
                                            icon: Icons.check_circle_rounded),
                                      ],
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('Buka pengiriman',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER: Live Order Tracker Card (Retail) ---
  Widget _buildLiveOrderCard(Pesanan p) {
    final statusNorm = p.status.toLowerCase();
    String badgeText = 'Dalam perjalanan';
    Color badgeBg = const Color(0xFFE0E7FF);
    Color badgeColor = const Color(0xFF4F46E5);
    int activeStep = 1;

    if (statusNorm.contains('menunggu')) {
      badgeText = 'Menunggu';
      badgeBg = const Color(0xFFFFEDD5);
      badgeColor = const Color(0xFFF97316);
      activeStep = 1;
    } else if (statusNorm == 'dikonfirmasi' || statusNorm == 'diproses') {
      badgeText = 'Dikonfirmasi';
      badgeBg = const Color(0xFFE0E7FF);
      badgeColor = const Color(0xFF4F46E5);
      activeStep = 2;
    } else if (statusNorm == 'dikirim') {
      badgeText = 'Dalam perjalanan';
      badgeBg = const Color(0xFFDBEAFE);
      badgeColor = _primary;
      activeStep = 3;
    } else if (statusNorm == 'diterima' || statusNorm == 'selesai') {
      badgeText = 'Diterima';
      badgeBg = const Color(0xFFCCFBF1);
      badgeColor = const Color(0xFF0D9488);
      activeStep = 4;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#${p.nomor}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p.dibuat != null ? formatTanggalJam(p.dibuat!) : '',
                    style: const TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4-Step Tracker Retail (Menunggu -> Konfirmasi -> Jalan -> Diterima)
          _buildRetailProgressTracker(activeStep),
          const SizedBox(height: 14),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          Row(
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 15, color: _textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${p.jumlahItem} item',
                    style: const TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 15, color: _textMuted),
                  const SizedBox(width: 4),
                  Text(
                    formatRupiah(p.total),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              InkWell(
                onTap: () => _buka(context, PesananDetailScreen(id: p.id)),
                child: const Text(
                  'Lihat detail ›',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetailProgressTracker(int activeStep) {
    const steps = ['Menunggu', 'Konfirmasi', 'Jalan', 'Diterima'];
    const activeColor = Color(0xFF4F46E5);

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = (index ~/ 2) + 1;
          final isLineActive = stepIndex < activeStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isLineActive ? activeColor : const Color(0xFFE2E8F0),
            ),
          );
        } else {
          final stepIndex = (index ~/ 2) + 1;
          final isPassed = stepIndex <= activeStep;
          final isCurrent = stepIndex == activeStep;

          return Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isPassed ? activeColor : const Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: const Color(0xFFC7D2FE), width: 3)
                      : Border.all(color: Colors.white, width: 2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[index ~/ 2],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isPassed ? FontWeight.bold : FontWeight.w500,
                  color: isPassed ? activeColor : const Color(0xFF94A3B8),
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  // --- WIDGET HELPER: Metrik Box ---
  static Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String count,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: _textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}