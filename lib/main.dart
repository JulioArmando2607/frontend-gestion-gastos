import 'package:app_gestion_gastos/pages/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:app_gestion_gastos/pages/home.dart';
import 'package:app_gestion_gastos/pages/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_ES', null);

  final storage = FlutterSecureStorage();
  final token = await storage.read(key: 'token');

  // ✅ válido solo si existe y NO está expirado
  final isLoggedIn = token != null && !JwtDecoder.isExpired(token);

  // Limpia si está vencido
  if (!isLoggedIn) {
    await storage.delete(key: 'token');
  }

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de Gastos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: isLoggedIn ? const DashboardPage() : const LoginPage(),
    );
  }
}
