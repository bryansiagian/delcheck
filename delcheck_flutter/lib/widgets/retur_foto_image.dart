import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/retur.dart';
import '../services/retur_service.dart';

/// Menampilkan foto Return melalui endpoint yang memerlukan Bearer token.
class ReturFotoImage extends StatefulWidget {
  const ReturFotoImage({super.key, required this.service, required this.foto});

  final ReturService service;
  final ReturFoto foto;

  @override
  State<ReturFotoImage> createState() => _ReturFotoImageState();
}

class _ReturFotoImageState extends State<ReturFotoImage> {
  late Future<Uint8List> _fotoBytes;

  @override
  void initState() {
    super.initState();
    _muatFoto();
  }

  @override
  void didUpdateWidget(covariant ReturFotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foto.url != widget.foto.url ||
        oldWidget.service != widget.service) {
      _muatFoto();
    }
  }

  void _muatFoto() => _fotoBytes = widget.service.ambilFoto(widget.foto.url);

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: AspectRatio(
      aspectRatio: 1.25,
      child: FutureBuilder<Uint8List>(
        future: _fotoBytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _placeholder(
              Icons.broken_image_outlined,
              'Foto gagal dimuat',
            );
          }
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _placeholder(Icons.broken_image_outlined, 'Foto tidak valid'),
            );
          }
          return _placeholder(
            Icons.image_outlined,
            'Memuat foto…',
            loading: true,
          );
        },
      ),
    ),
  );

  Widget _placeholder(IconData icon, String label, {bool loading = false}) =>
      ColoredBox(
        color: const Color(0xFFE2E8F0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(icon, color: const Color(0xFF64748B), size: 25),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      );
}
