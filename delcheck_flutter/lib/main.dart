import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('BASE URL = ${AppConfig.baseUrl}');
  runApp(const DelCheckApp());
}

class DelCheckApp extends StatelessWidget {
  const DelCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(api: ctx.read<ApiClient>())..mulai(),
        ),
      ],
      child: MaterialApp(
        title: 'DelCheck',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

/// Menentukan halaman awal: login jika belum ada sesi, beranda jika sudah.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    return switch (status) {
      AuthStatus.memeriksa => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.masuk => const HomeScreen(),
      AuthStatus.keluar => const LoginScreen(),
    };
  }
}