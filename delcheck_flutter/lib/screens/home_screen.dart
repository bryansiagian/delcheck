import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../models/retailer_pendaftar.dart';
import '../providers/auth_provider.dart';
import '../services/admin_service.dart';
import 'admin_pengguna_screen.dart';
import 'admin_verifikasi_screen.dart';
import 'buat_pesanan_screen.dart';
import 'pesanan_list_screen.dart';
import 'produk_list_screen.dart';
import 'stok_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Warna sesuai Tailwind HTML
  static const Color _bgScreen = Color(0xFFF1F5F9);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _bluePrimary = Color(0xFF2563EB);

  bool _memuatData = true;
  int _totalMenunggu = 0;
  int _totalPerluDikirim = 0;
  int _totalStokMenipis = 0;
  List<RetailerPendaftar> _pendaftarTerbaru = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _muatDataRingkasan();
    });
  }

  /// Mengambil data hitungan riil dari API Laravel
  Future<void> _muatDataRingkasan() async {
    if (!mounted) return;
    setState(() => _memuatData = true);

    final api = context.read<ApiClient>();
    final user = context.read<AuthProvider>().user;
    final isAdmin = user?.punyaPeran('admin') ?? false;
    final isWarehouse = user?.punyaPeran('warehouse') ?? false;

    int menunggu = 0;
    int perluKirim = 0;
    int stokMenipis = 0;
    List<RetailerPendaftar> pendaftar = [];

    try {
      // 1. Ambil data Retailer Menunggu Verifikasi (Khusus Admin)
      if (isAdmin) {
        try {
          final adminService = AdminService(api);
          final resRetail = await adminService.daftar(status: 'menunggu');
          menunggu = resRetail.total;
          pendaftar = resRetail.items;
        } catch (_) {}
      }

      // 2. Ambil data Pesanan yang Perlu Dikirim (status: dikonfirmasi)
      try {
        final resPesanan = await api.get('/pesanan?status=dikonfirmasi');
        final data = resPesanan['data'];
        if (data is Map && data['meta'] != null && data['meta']['total'] != null) {
          perluKirim = int.tryParse('${data['meta']['total']}') ?? 0;
        } else if (data is List) {
          perluKirim = data.length;
        } else if (data is Map && data['items'] is List) {
          perluKirim = (data['items'] as List).length;
        }
      } catch (_) {}

      // 3. Ambil data Stok Menipis
      if (isAdmin || isWarehouse) {
        try {
          final resStok = await api.get('/stok');
          final data = resStok['data'];
          final List listStok = data is List
              ? data
              : (data is Map && data['items'] is List ? data['items'] : []);

          // Hitung barang yang stoknya <= 10 atau field stok_menipis
          stokMenipis = listStok.where((item) {
            if (item is Map) {
              final stok = int.tryParse('${item['stok'] ?? item['jumlah'] ?? 999}') ?? 999;
              final minimal = int.tryParse('${item['stok_minimum'] ?? 10}') ?? 10;
              return stok <= minimal;
            }
            return false;
          }).length;
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _totalMenunggu = menunggu;
          _totalPerluDikirim = perluKirim;
          _totalStokMenipis = stokMenipis;
          _pendaftarTerbaru = pendaftar;
          _memuatData = false;
        });
      }
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

  Future<void> _buka(BuildContext context, Widget layar) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => layar));
    // Setelah kembali dari layar mana pun, refresh data summary
    _muatDataRingkasan();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final namaUser = user?.nama ?? 'Admin Distributor';
    final initial = namaUser.isNotEmpty ? namaUser[0].toUpperCase() : 'A';
    final roleName = user?.peranUtama.toUpperCase() ?? 'ADMIN SISTEM';

    final admin = user?.punyaPeran('admin') ?? true;
    final warehouse = user?.punyaPeran('warehouse') ?? false;
    final retail = user?.punyaPeran('retail') ?? false;

    return Scaffold(
      backgroundColor: _bgScreen,
      body: RefreshIndicator(
        color: _bluePrimary,
        onRefresh: _muatDataRingkasan,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ================= 1. HEADER DENGAN GRADIENT =================
              Container(
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 56),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1D4ED8),
                      Color(0xFF2563EB),
                      Color(0xFF3B82F6),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    // Top Bar: Logo & Logout Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.2)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.check_circle,
                                      color: _bluePrimary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PORTAL ${user?.peranUtama.toUpperCase() ?? "ADMIN"}',
                                  style: TextStyle(
                                    color: Colors.blue.shade100,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Text(
                                  'DelCheck',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Tombol Logout
                        InkWell(
                          onTap: () => _keluar(context),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Greeting Row
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: _bluePrimary,
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
                              Text(
                                'Selamat datang,',
                                style: TextStyle(
                                  color: Colors.blue.shade100,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                namaUser,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.verified_user_rounded,
                                            size: 11, color: Color(0xFFFDBA74)),
                                        const SizedBox(width: 4),
                                        Text(
                                          roleName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• Sesi Aktif',
                                    style: TextStyle(
                                      color: Colors.blue.shade100.withOpacity(0.8),
                                      fontSize: 10,
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

              // ================= 2. SUMMARY CARD (DATA REAL DARI API) =================
              Transform.translate(
                offset: const Offset(0, -32),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.08),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildSummaryItem(
                          icon: Icons.how_to_reg_rounded,
                          iconColor: const Color(0xFFF97316),
                          bgColor: const Color(0xFFFFEDD5),
                          count: _memuatData ? '...' : '$_totalMenunggu',
                          label: 'Menunggu\nverifikasi',
                        ),
                        Container(width: 1, height: 38, color: const Color(0xFFF1F5F9)),
                        _buildSummaryItem(
                          icon: Icons.local_shipping_rounded,
                          iconColor: _bluePrimary,
                          bgColor: const Color(0xFFDBEAFE),
                          count: _memuatData ? '...' : '$_totalPerluDikirim',
                          label: 'Perlu\ndikirim',
                        ),
                        Container(width: 1, height: 38, color: const Color(0xFFF1F5F9)),
                        _buildSummaryItem(
                          icon: Icons.warning_amber_rounded,
                          iconColor: const Color(0xFF0D9488),
                          bgColor: const Color(0xFFCCFBF1),
                          count: _memuatData ? '...' : '$_totalStokMenipis',
                          label: 'Stok\nmenipis',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ================= KONTEN BODY MENU =================
              Transform.translate(
                offset: const Offset(0, -16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Submenu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Menu pengelolaan',
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
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '5 Layanan',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _bluePrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // FEATURED CARD: Verifikasi Pendaftaran Retail
                      if (admin)
                        _buildFeaturedCard(
                          context: context,
                          totalMenunggu: _totalMenunggu,
                          onTap: () =>
                              _buka(context, const AdminVerifikasiScreen()),
                        ),

                      const SizedBox(height: 14),

                      // 2-COLUMN GRID CARDS
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          // Card 1: Kelola Akun
                          if (admin)
                            _buildGridCard(
                              icon: Icons.people_outline_rounded,
                              iconColor: const Color(0xFF2563EB),
                              iconBg: const Color(0xFFDBEAFE),
                              title: 'Kelola Akun',
                              desc: 'Aktifkan atau nonaktifkan akun',
                              onTap: () =>
                                  _buka(context, const AdminPenggunaScreen()),
                            ),

                          // Card 2: Pengiriman
                          if (admin || warehouse)
                            _buildGridCard(
                              icon: Icons.local_shipping_outlined,
                              iconColor: const Color(0xFF4F46E5),
                              iconBg: const Color(0xFFE0E7FF),
                              title: 'Pengiriman',
                              desc: 'Atur pengiriman pesanan',
                              onTap: () => _buka(
                                context,
                                const PesananListScreen(
                                  judul: 'Pengiriman',
                                  tampilkanToko: true,
                                  filter: [
                                    PesananFilter('Semua', null, icon: Icons.layers_rounded),
                                    PesananFilter('Siap dikirim', 'dikonfirmasi', icon: Icons.inventory_2_rounded),
                                    PesananFilter('Bersama kurir', 'diproses', icon: Icons.person_pin_circle_rounded),
                                    PesananFilter('Dalam perjalanan', 'dikirim', icon: Icons.local_shipping_rounded),
                                    PesananFilter('Diterima', 'diterima,selesai', icon: Icons.check_circle_rounded),
                                  ],
                                ),
                              ),
                            ),

                          // Card 3: Produk
                          if (admin || warehouse)
                            _buildGridCard(
                              icon: Icons.inventory_2_outlined,
                              iconColor: const Color(0xFFEA580C),
                              iconBg: const Color(0xFFFFEDD5),
                              title: 'Produk',
                              desc: 'Tambah, ubah, hapus produk',
                              onTap: () =>
                                  _buka(context, const ProdukListScreen()),
                            ),

                          // Card 4: Stok
                          if (admin || warehouse)
                            _buildGridCard(
                              icon: Icons.warehouse_outlined,
                              iconColor: const Color(0xFF0D9488),
                              iconBg: const Color(0xFFCCFBF1),
                              title: 'Stok',
                              desc: 'Atur stok & lihat riwayat',
                              onTap: () =>
                                  _buka(context, const StokListScreen()),
                            ),

                          // Card Tambahan (Khusus Retail jika ada)
                          if (retail)
                            _buildGridCard(
                              icon: Icons.add_shopping_cart_rounded,
                              iconColor: const Color(0xFF2563EB),
                              iconBg: const Color(0xFFDBEAFE),
                              title: 'Pesan Produk',
                              desc: 'Pilih produk retail',
                              onTap: () =>
                                  _buka(context, const BuatPesananScreen()),
                            ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ================= 3. SECTION AKTIVITAS TERBARU =================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aktivitas terbaru',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                          TextButton(
                            onPressed: _muatDataRingkasan,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Row(
                              children: [
                                Text(
                                  'Perbarui',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _bluePrimary,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.refresh_rounded,
                                    size: 16, color: _bluePrimary),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Card Aktivitas Real / Dinamis
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_pendaftarTerbaru.isNotEmpty) ...[
                              _buildActivityRow(
                                icon: Icons.person_add_alt_1_rounded,
                                iconBg: const Color(0xFFFFEDD5),
                                iconColor: const Color(0xFFEA580C),
                                title:
                                    '${_pendaftarTerbaru.first.namaToko} mendaftar sebagai retail',
                                time: 'Menunggu persetujuan',
                                hasDot: true,
                              ),
                              const Divider(
                                  height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
                            ],
                            _buildActivityRow(
                              icon: Icons.local_shipping_rounded,
                              iconBg: const Color(0xFFDBEAFE),
                              iconColor: _bluePrimary,
                              title: '$_totalPerluDikirim pesanan menunggu proses kirim',
                              time: 'Status siap diproses',
                            ),
                            const Divider(
                                height: 24, thickness: 1, color: Color(0xFFF1F5F9)),
                            _buildActivityRow(
                              icon: Icons.inventory_rounded,
                              iconBg: const Color(0xFFCCFBF1),
                              iconColor: const Color(0xFF0D9488),
                              title: '$_totalStokMenipis produk dalam stok kritis',
                              time: 'Periksa persediaan gudang',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Footer App Info
                      const Center(
                        child: Text(
                          'DelCheck v1.0 • Sistem Logistik & Distribusi B2B',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPER: 3 Kolom Summary ---
  static Widget _buildSummaryItem({
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
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
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER: Featured Wide Card ---
  Widget _buildFeaturedCard({
    required BuildContext context,
    required int totalMenunggu,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFFEDD5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFB923C), Color(0xFFF97316)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF97316).withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verifikasi Pendaftaran Retail',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const Text(
                    'Setujui atau tolak toko mendaftar',
                    style: TextStyle(fontSize: 11, color: _textMuted),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDD5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                            radius: 3, backgroundColor: Color(0xFFF97316)),
                        const SizedBox(width: 5),
                        Text(
                          '$totalMenunggu menunggu',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC2410C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER: 2-Column Square Cards ---
  Widget _buildGridCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_outward_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: _textMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER: Activity Row ---
  static Widget _buildActivityRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String time,
    bool hasDot = false,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(fontSize: 10, color: _textMuted),
              ),
            ],
          ),
        ),
        if (hasDot)
          const CircleAvatar(
            radius: 3.5,
            backgroundColor: Color(0xFFF97316),
          ),
      ],
    );
  }
}