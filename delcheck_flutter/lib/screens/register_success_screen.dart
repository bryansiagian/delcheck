import 'package:flutter/material.dart';

class RegisterSuccessScreen extends StatelessWidget {
  final String message;
  const RegisterSuccessScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 96, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Pendaftaran terkirim',
                  style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(
                '$message\n\nAnda baru bisa masuk setelah akun diverifikasi oleh admin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Kembali ke login'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
