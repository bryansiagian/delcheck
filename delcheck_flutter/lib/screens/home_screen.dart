import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'admin_pengguna_screen.dart';
import 'admin_verifikasi_screen.dart';
import 'buat_pesanan_screen.dart';
import 'pesanan_list_screen.dart';
import 'produk_list_screen.dart';
import 'stok_list_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _keluar(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text('Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Keluar')),
        ],
      ),
    );
    if (yakin == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      // AuthGate otomatis kembali ke halaman login.
    }
  }

  void _buka(BuildContext context, Widget layar) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => layar));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final tema = Theme.of(context);

    final admin = user?.punyaPeran('admin') ?? false;
    final warehouse = user?.punyaPeran('warehouse') ?? false;
    final retail = user?.punyaPeran('retail') ?? false;
    final sales = user?.punyaPeran('sales') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => _keluar(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(
                      (user?.nama.isNotEmpty ?? false)
                          ? user!.nama[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Halo,', style: tema.textTheme.bodySmall),
                        Text(user?.nama ?? 'Pengguna',
                            style: tema.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Chip(
                          label: Text(user?.peranUtama ?? '-'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Retail
          if (retail) ...[
            _MenuTile(
              ikon: Icons.add_shopping_cart,
              judul: 'Pesan Produk',
              subjudul: 'Pilih produk dan kirim pesanan',
              onTap: () => _buka(context, const BuatPesananScreen()),
            ),
            _MenuTile(
              ikon: Icons.receipt_long_outlined,
              judul: 'Pesanan Saya',
              subjudul: 'Pantau status dan konfirmasi barang diterima',
              onTap: () => _buka(
                context,
                const PesananListScreen(
                  judul: 'Pesanan Saya',
                  bisaBuat: true,
                  filter: [
                    PesananFilter('Semua', null),
                    PesananFilter('Menunggu', 'menunggu_konfirmasi_sales'),
                    PesananFilter('Diproses', 'dikonfirmasi,diproses'),
                    PesananFilter('Dalam perjalanan', 'dikirim'),
                    PesananFilter('Diterima', 'diterima,selesai'),
                    PesananFilter('Ditolak / batal', 'ditolak,dibatalkan'),
                  ],
                ),
              ),
            ),
          ],

          // ---- Sales
          if (sales)
            _MenuTile(
              ikon: Icons.fact_check_outlined,
              judul: 'Konfirmasi Pesanan',
              subjudul: 'Setujui atau tolak pesanan dari toko',
              onTap: () => _buka(
                context,
                const PesananListScreen(
                  judul: 'Konfirmasi Pesanan',
                  tampilkanToko: true,
                  filter: [
                    PesananFilter('Menunggu', 'menunggu_konfirmasi_sales'),
                    PesananFilter('Disetujui',
                        'dikonfirmasi,diproses,dikirim,diterima,selesai'),
                    PesananFilter('Ditolak', 'ditolak'),
                    PesananFilter('Semua', null),
                  ],
                ),
              ),
            ),

          // ---- Admin
          if (admin) ...[
            _MenuTile(
              ikon: Icons.verified_user_outlined,
              judul: 'Verifikasi Pendaftaran Retail',
              subjudul: 'Setujui atau tolak toko yang mendaftar',
              onTap: () => _buka(context, const AdminVerifikasiScreen()),
            ),
            _MenuTile(
              ikon: Icons.manage_accounts_outlined,
              judul: 'Kelola Pengguna',
              subjudul: 'Aktifkan atau nonaktifkan akun pengguna',
              onTap: () => _buka(context, const AdminPenggunaScreen()),
            ),
          ],

          // ---- Admin dan Warehouse
          if (admin || warehouse) ...[
            _MenuTile(
              ikon: Icons.local_shipping_outlined,
              judul: 'Pengiriman',
              subjudul: 'Atur pengiriman pesanan yang sudah disetujui',
              onTap: () => _buka(
                context,
                const PesananListScreen(
                  judul: 'Pengiriman',
                  tampilkanToko: true,
                  filter: [
                    PesananFilter('Siap kirim', 'dikonfirmasi'),
                    PesananFilter('Bersama kurir', 'diproses'),
                    PesananFilter('Dalam perjalanan', 'dikirim'),
                    PesananFilter('Diterima', 'diterima,selesai'),
                    PesananFilter('Semua', null),
                  ],
                ),
              ),
            ),
            _MenuTile(
              ikon: Icons.inventory_2_outlined,
              judul: 'Produk',
              subjudul: 'Tambah, ubah, dan hapus produk',
              onTap: () => _buka(context, const ProdukListScreen()),
            ),
            _MenuTile(
              ikon: Icons.warehouse_outlined,
              judul: 'Stok',
              subjudul: 'Tambah atau kurangi stok, lihat riwayat',
              onTap: () => _buka(context, const StokListScreen()),
            ),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.ikon,
    required this.judul,
    required this.subjudul,
    required this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String subjudul;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(ikon),
        title: Text(judul),
        subtitle: Text(subjudul),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
