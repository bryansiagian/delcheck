import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../models/pesanan.dart';
import '../models/retur.dart';
import '../services/pesanan_service.dart';
import '../services/retur_service.dart';
import '../widgets/retur_foto_image.dart';

class ReturBuatDraftScreen extends StatefulWidget {
  const ReturBuatDraftScreen({super.key, this.returId, this.imagePicker});

  final int? returId;

  @visibleForTesting
  final ImagePicker? imagePicker;

  @override
  State<ReturBuatDraftScreen> createState() => _ReturBuatDraftScreenState();
}

class _ReturBuatDraftScreenState extends State<ReturBuatDraftScreen> {
  static const _maksFoto = 5;
  static const _maksUkuranFoto = 10 * 1024 * 1024;
  static const _ekstensiGambar = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};
  static const _mimeGambar = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/bmp',
    'image/x-ms-bmp',
    'image/webp',
  };

  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _alasanCtrl = TextEditingController();
  final List<XFile> _fotoKondisi = [];
  late final PesananService _pesananService;
  late final ReturService _returService;
  late final ImagePicker _imagePicker;

  Pesanan? _pesananDipilih;
  Pesanan? _detailPesanan;
  ItemPesanan? _itemDipilih;
  Retur? _draftAwal;
  List<ReturFoto> _fotoLama = const [];
  String? _jenisPenyelesaian;
  String? _errorDetail;
  String? _errorDraft;
  String? _errorFoto;
  bool _memuatDraft = false;
  bool _memuatDetail = false;
  bool _memilihFoto = false;
  bool _menyimpan = false;
  bool _bolehKeluar = false;
  bool _konfirmasiKeluarTampil = false;

  bool get _adaIsian =>
      _pesananDipilih != null ||
      _itemDipilih != null ||
      _qtyCtrl.text.trim().isNotEmpty ||
      _alasanCtrl.text.trim().isNotEmpty ||
      _jenisPenyelesaian != null ||
      _fotoKondisi.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _pesananService = PesananService(api);
    _returService = ReturService(api);
    _imagePicker = widget.imagePicker ?? ImagePicker();
    if (widget.returId != null) {
      _memuatDraft = true;
      _muatDraft();
    }
  }

  Future<void> _muatDraft() async {
    final id = widget.returId;
    if (id == null) return;
    setState(() {
      _memuatDraft = true;
      _errorDraft = null;
    });
    try {
      final retur = await _returService.detail(id);
      if (!retur.isDraft) {
        throw ApiException(
          status: 409,
          message: 'Return ini sudah bukan draft dan tidak dapat diedit.',
        );
      }
      final pesananId = retur.pesanan?.id;
      if (pesananId == null || retur.item == null) {
        throw ApiException(
          message: 'Data pesanan atau item Return tidak tersedia.',
        );
      }
      final pesanan = await _pesananService.detail(pesananId);
      if (!mounted) return;
      ItemPesanan? item;
      for (final kandidat in pesanan.items) {
        if (kandidat.id == retur.item!.itemPesananId) {
          item = kandidat;
          break;
        }
      }
      setState(() {
        _draftAwal = retur;
        _fotoLama = retur.fotoKondisi;
        _pesananDipilih = pesanan;
        _detailPesanan = pesanan;
        _itemDipilih = item;
        _qtyCtrl.text = '${retur.item!.qty}';
        _alasanCtrl.text = retur.alasan ?? '';
        _jenisPenyelesaian = retur.jenisPenyelesaian;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorDraft = e.message);
    } finally {
      if (mounted) setState(() => _memuatDraft = false);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _alasanCtrl.dispose();
    super.dispose();
  }

  Future<void> _pilihPesanan() async {
    final pesanan = await showModalBottomSheet<Pesanan>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PilihPesananSheet(service: _pesananService),
    );
    if (pesanan == null || !mounted) return;

    setState(() {
      _pesananDipilih = pesanan;
      _detailPesanan = null;
      _itemDipilih = null;
      _errorDetail = null;
      _memuatDetail = true;
    });
    try {
      final detail = await _pesananService.detail(pesanan.id);
      if (!mounted) return;
      if (detail.status != 'diterima') {
        setState(() {
          _pesananDipilih = null;
          _errorDetail =
              'Status pesanan berubah. Return hanya dapat dibuat dari pesanan yang diterima.';
        });
        return;
      }
      setState(() => _detailPesanan = detail);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorDetail = e.message);
    } finally {
      if (mounted) setState(() => _memuatDetail = false);
    }
  }

  Future<void> _muatUlangDetail() async {
    final pesanan = _pesananDipilih;
    if (pesanan == null) return;
    setState(() {
      _memuatDetail = true;
      _errorDetail = null;
    });
    try {
      final detail = await _pesananService.detail(pesanan.id);
      if (!mounted) return;
      if (detail.status != 'diterima') {
        setState(() {
          _pesananDipilih = null;
          _detailPesanan = null;
          _itemDipilih = null;
          _errorDetail =
              'Status pesanan sudah berubah. Pilih pesanan diterima lainnya.';
        });
      } else {
        setState(() => _detailPesanan = detail);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorDetail = e.message);
    } finally {
      if (mounted) setState(() => _memuatDetail = false);
    }
  }

  Future<void> _tambahFoto(ImageSource source) async {
    if (_menyimpan || _memilihFoto) return;
    final sisa = _maksFoto - _fotoKondisi.length;
    if (sisa <= 0) {
      _tampilkanErrorFoto('Maksimal $_maksFoto foto kondisi produk.');
      return;
    }

    setState(() {
      _memilihFoto = true;
      _errorFoto = null;
    });
    try {
      final List<XFile> hasil;
      if (source == ImageSource.gallery) {
        if (sisa == 1) {
          final foto = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            requestFullMetadata: false,
          );
          hasil = foto == null ? const [] : [foto];
        } else {
          hasil = await _imagePicker.pickMultiImage(
            limit: sisa,
            requestFullMetadata: false,
          );
        }
      } else {
        final foto = await _imagePicker.pickImage(
          source: source,
          requestFullMetadata: false,
        );
        hasil = foto == null ? const [] : [foto];
      }

      if (!mounted || hasil.isEmpty) return;
      final diterima = <XFile>[];
      String? pesanValidasi;
      for (final foto in hasil) {
        if (_fotoKondisi.any((pilihan) => pilihan.path == foto.path) ||
            diterima.any((pilihan) => pilihan.path == foto.path)) {
          continue;
        }
        if (_fotoKondisi.length + diterima.length >= _maksFoto) {
          pesanValidasi = 'Maksimal $_maksFoto foto kondisi produk.';
          break;
        }
        final pesan = _validasiFoto(foto);
        if (pesan != null) {
          pesanValidasi ??= pesan;
          continue;
        }
        diterima.add(foto);
      }
      if (!mounted) return;
      setState(() {
        _fotoKondisi.addAll(diterima);
        _errorFoto = pesanValidasi;
      });
      if (pesanValidasi != null) _pesan(pesanValidasi);
    } on PlatformException {
      _tampilkanErrorFoto(
        source == ImageSource.camera
            ? 'Kamera tidak dapat dibuka. Periksa izin kamera lalu coba lagi.'
            : 'Galeri tidak dapat dibuka. Coba lagi.',
      );
    } catch (_) {
      _tampilkanErrorFoto('Foto tidak dapat dibaca. Pilih foto lain.');
    } finally {
      if (mounted) setState(() => _memilihFoto = false);
    }
  }

  String? _validasiFoto(XFile foto) {
    final ekstensi = foto.path.split('.').last.toLowerCase();
    final mime = foto.mimeType?.split(';').first.trim().toLowerCase();
    if (!_ekstensiGambar.contains(ekstensi) ||
        (mime != null && !_mimeGambar.contains(mime))) {
      return 'Format foto tidak didukung. Gunakan JPG, PNG, GIF, BMP, atau WebP.';
    }

    try {
      final ukuran = File(foto.path).lengthSync();
      if (ukuran == 0) return 'File foto kosong atau tidak dapat dibaca.';
      if (ukuran > _maksUkuranFoto) return 'Setiap foto maksimal 10 MB.';
    } on FileSystemException {
      return 'File foto tidak dapat dibaca. Pilih foto lain.';
    } catch (_) {
      return 'File foto tidak dapat dibaca. Pilih foto lain.';
    }
    return null;
  }

  void _hapusFoto(XFile foto) {
    setState(() {
      _fotoKondisi.removeWhere((pilihan) => pilihan.path == foto.path);
      _errorFoto = null;
    });
  }

  void _tampilkanErrorFoto(String pesan) {
    if (mounted) setState(() => _errorFoto = pesan);
    _pesan(pesan);
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_pesananDipilih == null || _detailPesanan == null) {
      _pesan('Pilih pesanan yang sudah diterima.');
      return;
    }
    if (_itemDipilih == null) {
      _pesan('Pilih satu item produk dari pesanan.');
      return;
    }
    if (_detailPesanan?.status != 'diterima') {
      _pesan('Pesanan harus berstatus diterima untuk mengubah Draft Return.');
      return;
    }
    setState(() => _menyimpan = true);
    try {
      final fotosBaru = _fotoKondisi.map((foto) => File(foto.path)).toList();
      final returLama = _draftAwal;
      if (returLama == null) {
        await _returService.buatDraft(
          pesananId: _pesananDipilih!.id,
          itemPesananId: _itemDipilih!.id,
          qty: int.parse(_qtyCtrl.text.trim()),
          alasan: _alasanCtrl.text.trim(),
          jenisPenyelesaian: _jenisPenyelesaian,
          fotoKondisi: fotosBaru,
        );
      } else {
        await _returService.perbaruiDraft(
          returLama.id,
          data: {
            'pesanan_id': _pesananDipilih!.id,
            'item_pesanan_id': _itemDipilih!.id,
            'qty': int.parse(_qtyCtrl.text.trim()),
            'alasan': _alasanCtrl.text.trim(),
            'jenis_penyelesaian': _jenisPenyelesaian,
          },
          fotoKondisi: fotosBaru.isEmpty ? null : fotosBaru,
        );
      }
      if (mounted) {
        setState(() => _bolehKeluar = true);
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _bolehKeluar = false;
      });
      _pesan(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _bolehKeluar = false;
      });
      _pesan('Draft Return gagal disimpan. Silakan coba lagi.');
    }
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _tanganiKembali(bool didPop, Object? result) async {
    if (didPop ||
        !_adaIsian ||
        _menyimpan ||
        _memilihFoto ||
        _konfirmasiKeluarTampil) {
      return;
    }
    _konfirmasiKeluarTampil = true;
    final tinggalkan = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tinggalkan form?'),
        content: const Text('Isian draft yang belum disimpan akan hilang.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Lanjut mengisi'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tinggalkan'),
          ),
        ],
      ),
    );
    _konfirmasiKeluarTampil = false;
    if (tinggalkan == true && mounted) {
      setState(() => _bolehKeluar = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, false);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_adaIsian || _bolehKeluar,
    onPopInvokedWithResult: _tanganiKembali,
    child: Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          widget.returId == null ? 'Buat Draft Return' : 'Edit Draft Return',
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _memuatDraft
          ? const Center(child: CircularProgressIndicator())
          : _errorDraft != null
          ? _draftGagal()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _bagian(
                    judul: '1. Pilih pesanan diterima',
                    isi: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _menyimpan || _memilihFoto
                              ? null
                              : _pilihPesanan,
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(
                            _pesananDipilih == null
                                ? 'Pilih pesanan'
                                : 'Ganti pesanan',
                          ),
                        ),
                        if (_pesananDipilih case final pesanan?) ...[
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFDBEAFE),
                              child: Icon(
                                Icons.receipt_long,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            title: Text(pesanan.nomor),
                            subtitle: Text(
                              '${pesanan.dibuat == null ? 'Tanggal tidak tersedia' : formatTanggalJam(pesanan.dibuat!)} · ${pesanan.jumlahItem} item',
                            ),
                            trailing: const Icon(
                              Icons.check_circle,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          if (_detailPesanan?.status != 'diterima')
                            const Text(
                              'Pesanan ini tidak lagi berstatus diterima. Pilih pesanan diterima untuk menyimpan perubahan.',
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (_memuatDetail)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorDetail != null)
                    _bagian(
                      judul: 'Item pesanan',
                      isi: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorDetail!,
                            style: const TextStyle(color: Color(0xFFB91C1C)),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _pesananDipilih == null
                                ? _pilihPesanan
                                : _muatUlangDetail,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    )
                  else if (_detailPesanan != null)
                    _bagian(
                      judul: '2. Pilih satu item produk',
                      isi: _detailPesanan!.items.isEmpty
                          ? const Text('Item pesanan tidak tersedia.')
                          : IgnorePointer(
                              ignoring: _menyimpan,
                              child: RadioGroup<int>(
                                groupValue: _itemDipilih?.id,
                                onChanged: (id) {
                                  if (id == null) return;
                                  setState(() {
                                    _itemDipilih = _detailPesanan!.items
                                        .firstWhere((item) => item.id == id);
                                  });
                                },
                                child: Column(
                                  children: [
                                    for (final item in _detailPesanan!.items)
                                      RadioListTile<int>(
                                        value: item.id,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(item.namaProduk),
                                        subtitle: Text(
                                          'Pembelian: ${formatAngka(item.qty)}${item.satuan.isEmpty ? '' : ' ${item.satuan}'}',
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  _bagian(
                    judul: '3. Rincian Return',
                    isi: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _qtyCtrl,
                          enabled: !_menyimpan,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Kuantitas Return',
                            helperText:
                                'Masukkan jumlah unit yang ingin di-Return.',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final qty = int.tryParse(value?.trim() ?? '');
                            if (qty == null || qty <= 0) {
                              return 'Kuantitas harus berupa bilangan bulat lebih dari 0.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _alasanCtrl,
                          enabled: !_menyimpan,
                          minLines: 3,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Alasan Return',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) => (value?.trim().isEmpty ?? true)
                              ? 'Alasan wajib diisi.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Jenis penyelesaian (opsional)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        IgnorePointer(
                          ignoring: _menyimpan,
                          child: RadioGroup<String>(
                            groupValue: _jenisPenyelesaian,
                            onChanged: (value) => setState(() {
                              _jenisPenyelesaian = value;
                            }),
                            child: const Column(
                              children: [
                                RadioListTile<String>(
                                  value: 'refund',
                                  title: Text('Pengembalian dana'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                                RadioListTile<String>(
                                  value: 'replacement',
                                  title: Text('Penggantian produk'),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _bagian(
                    judul: '4. Foto kondisi produk (opsional)',
                    isi: _fotoWidget(),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
      bottomNavigationBar: _memuatDraft || _errorDraft != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: FilledButton.icon(
                  onPressed: _menyimpan || _memilihFoto ? null : _simpan,
                  icon: _menyimpan
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _menyimpan
                        ? 'Menyimpan…'
                        : _memilihFoto
                        ? 'Memproses foto…'
                        : widget.returId == null
                        ? 'Simpan Draft'
                        : 'Simpan Perubahan',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ),
            ),
    ),
  );

  Widget _fotoWidget() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_fotoLama.isNotEmpty) ...[
        const Text('Foto tersimpan saat ini'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 350 ? 1 : 2;
            final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final foto in _fotoLama)
                  SizedBox(
                    width: width,
                    child: ReturFotoImage(
                      key: ValueKey('lama-${foto.id}'),
                      service: _returService,
                      foto: foto,
                    ),
                  ),
              ],
            );
          },
        ),
        if (_fotoKondisi.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'Foto yang baru dipilih akan menggantikan seluruh foto lama saat disimpan.',
            style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
      ],
      Text('${_fotoKondisi.length} dari $_maksFoto foto dipilih'),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _menyimpan || _memilihFoto || _fotoKondisi.length >= _maksFoto
                  ? null
                  : () => _tambahFoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Galeri'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed:
                  _menyimpan || _memilihFoto || _fotoKondisi.length >= _maksFoto
                  ? null
                  : () => _tambahFoto(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Kamera'),
            ),
          ),
        ],
      ),
      if (_fotoKondisi.length >= _maksFoto)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Batas maksimal 5 foto sudah tercapai.',
            style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
          ),
        ),
      if (_memilihFoto) ...[
        const SizedBox(height: 6),
        const LinearProgressIndicator(),
      ],
      if (_errorFoto != null) ...[
        const SizedBox(height: 6),
        Text(
          _errorFoto!,
          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
        ),
      ],
      if (_fotoKondisi.isNotEmpty) ...[
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 350 ? 1 : 2;
            final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final foto in _fotoKondisi)
                  SizedBox(
                    width: width,
                    child: _FotoDraftTile(
                      key: ValueKey(foto.path),
                      foto: foto,
                      onRemove: _menyimpan || _memilihFoto
                          ? null
                          : () => _hapusFoto(foto),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ],
  );

  Widget _draftGagal() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 12),
          Text(_errorDraft!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _muatDraft,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba lagi'),
          ),
        ],
      ),
    ),
  );

  Widget _bagian({required String judul, required Widget isi}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              judul,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            isi,
          ],
        ),
      ),
    ),
  );
}

class _FotoDraftTile extends StatelessWidget {
  const _FotoDraftTile({super.key, required this.foto, required this.onRemove});

  final XFile foto;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: AspectRatio(
      aspectRatio: 1.35,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(foto.path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Color(0xFFE2E8F0),
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFF64748B),
                  size: 32,
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onRemove,
                tooltip: 'Hapus foto',
                icon: const Icon(Icons.close_rounded),
                color: Colors.white,
                iconSize: 20,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PilihPesananSheet extends StatefulWidget {
  const _PilihPesananSheet({required this.service});

  final PesananService service;

  @override
  State<_PilihPesananSheet> createState() => _PilihPesananSheetState();
}

class _PilihPesananSheetState extends State<_PilihPesananSheet> {
  final _scroll = ScrollController();
  final List<Pesanan> _pesanan = [];
  int _halaman = 0;
  int _halamanTerakhir = 1;
  int _total = 0;
  bool _memuat = true;
  bool _memuatLagi = false;
  String? _error;

  bool get _adaLagi => _halaman < _halamanTerakhir;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _muatAwal();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 180) {
      _muatLagi();
    }
  }

  Future<void> _muatAwal() async {
    setState(() {
      _memuat = true;
      _error = null;
    });
    try {
      final page = await widget.service.daftar(status: 'diterima', halaman: 1);
      if (!mounted) return;
      setState(() {
        _pesanan
          ..clear()
          ..addAll(page.items.where((p) => p.status == 'diterima'));
        _halaman = page.halaman;
        _halamanTerakhir = page.halamanTerakhir;
        _total = page.total;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _memuat = false);
    }
  }

  Future<void> _muatLagi() async {
    if (_memuat || _memuatLagi || !_adaLagi) return;
    setState(() => _memuatLagi = true);
    try {
      final page = await widget.service.daftar(
        status: 'diterima',
        halaman: _halaman + 1,
      );
      if (!mounted) return;
      setState(() {
        _pesanan.addAll(page.items.where((p) => p.status == 'diterima'));
        _halaman = page.halaman;
        _halamanTerakhir = page.halamanTerakhir;
        _total = page.total;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _memuatLagi = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * 0.78,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Pilih pesanan diterima',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$_total pesanan',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
        Expanded(child: _konten()),
      ],
    ),
  );

  Widget _konten() {
    if (_memuat && _pesanan.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _pesanan.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _muatAwal,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }
    if (_pesanan.isEmpty) {
      return RefreshIndicator(
        onRefresh: _muatAwal,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Center(child: Text('Tidak ada pesanan berstatus diterima.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _muatAwal,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        itemCount: _pesanan.length + (_adaLagi ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == _pesanan.length) {
            return const Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final pesanan = _pesanan[index];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              onTap: () => Navigator.pop(context, pesanan),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDBEAFE),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF2563EB),
                ),
              ),
              title: Text(pesanan.nomor),
              subtitle: Text(
                '${pesanan.dibuat == null ? 'Tanggal tidak tersedia' : formatTanggalJam(pesanan.dibuat!)} · ${pesanan.jumlahItem} item',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}
