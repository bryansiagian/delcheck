import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'admin_verifikasi_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final tema = Theme.of(context);

    final admin = user?.punyaPeran('admin') ?? false;
    final warehouse = user?.punyaPeran('warehouse') ?? false;

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
          // Menu per peran. Menu yang belum punya onTap menampilkan "belum dihubungkan".
          if (admin)
            _MenuTile(
              ikon: Icons.verified_user_outlined,
              judul: 'Verifikasi Pendaftaran Retail',
              subjudul: 'Setujui atau tolak toko yang mendaftar',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminVerifikasiScreen()),
              ),
            ),
          // Admin dan Warehouse sama-sama mengelola produk dan stok.
          if (admin || warehouse) ...[
            _MenuTile(
              ikon: Icons.inventory_2_outlined,
              judul: 'Produk',
              subjudul: 'Tambah, ubah, dan hapus produk',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProdukListScreen()),
              ),
            ),
            _MenuTile(
              ikon: Icons.warehouse_outlined,
              judul: 'Stok',
              subjudul: 'Tambah atau kurangi stok, lihat riwayat',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StokListScreen()),
              ),
            ),
          ],
          if (user?.punyaPeran('retail') ?? false)
            const _MenuTile(
              ikon: Icons.storefront_outlined,
              judul: 'Toko Saya',
              subjudul: 'Segera hadir',
            ),
          if (user?.punyaPeran('sales') ?? false)
            const _MenuTile(
              ikon: Icons.people_outline,
              judul: 'Toko Binaan',
              subjudul: 'Segera hadir',
            ),
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
    this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String subjudul;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(ikon),
        title: Text(judul),
        subtitle: Text(subjudul),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap ??
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur ini belum dihubungkan.')),
              );
            },
      ),
    );
  }
}
