import 'dart:convert';
import 'package:app_gestion_gastos/api/enviroment.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ApiService {
  ApiService() : storage = const FlutterSecureStorage();

  final String baseUrl = 'http://${Environment.serverIP}:8081/api';
  final FlutterSecureStorage storage;

  Future<Map<String, String>> _authHeaders(
    BuildContext context, {
    bool jsonBody = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }

    final token = await storage.read(key: 'token');
    print(token);
    // si no hay token o está vencido, salir a Login
    if (token == null || JwtDecoder.isExpired(token)) {
      await _logoutAndGoToLogin(context);
      throw Exception('Token inválido o expirado');
    }
    print(token);
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> _handle401(BuildContext context, http.Response res) async {
    if (res.statusCode == 401) {
      await _logoutAndGoToLogin(context);
      throw Exception('No autorizado (401)');
    }
  }

  Future<void> _logoutAndGoToLogin(BuildContext context) async {
    await storage.deleteAll();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ---------- ENDPOINTS ----------

  Future<http.Response> login(Map<String, String> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    return res;
  }

  Future<http.Response> register(Map<String, String> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    return res;
  }

  Future<http.Response> editarCuenta(
    BuildContext context,
    idUsuario,
    Map<String, String> body,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/usuario/editar/$idUsuario'),
      headers: await _authHeaders(context),

      body: jsonEncode(body),
    );
    return res;
  }

  Future<http.Response> cardResumen(BuildContext context) async {
    final res = await http.get(
      Uri.parse('$baseUrl/movimientos/cardResumen'),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> obtenerMovimientos(BuildContext context) async {
    final res = await http.get(
      Uri.parse('$baseUrl/movimientos/usuario'),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> obtenerCardPersonalizado(BuildContext context) async {
    final res = await http.get(
      Uri.parse('$baseUrl/gastos-personalizados/list-card-personalizados'),
      headers: await _authHeaders(context),
    );
    print(res.body);
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> obtenerCardPersonalizadoxId(
    BuildContext context,
    int id,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/gastos-personalizados/card-personalizado/$id'),
      headers: await _authHeaders(context),
    );
    print(res.body);
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> movimientos(BuildContext context, body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/movimientos'),
      headers: await _authHeaders(context, jsonBody: true),
      body: jsonEncode(body),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> eliminarMovimiento(
    BuildContext context,
    String id,
  ) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/movimientos/$id'),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> eliminarMovimientoP(
    BuildContext context,
    String id,
  ) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/gastos-personalizados/eliminar-movimiento/$id'),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> usuario(BuildContext context, String id) async {
    final res = await http.get(
      Uri.parse('$baseUrl/usuario/$id'),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> obtenerTipoCategoria(
    BuildContext context,
    String tipo,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/categorias/tipo/$tipo'),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> obtenerCategoriaPersonalizadoxTipo(
    BuildContext context,
    int idCard,
    String tipo,
  ) async {
    final res = await http.get(
      Uri.parse(
        '$baseUrl/gastos-personalizados/lista-categoria-personalizado-tipo/$idCard/$tipo',
      ),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> editarMovimiento(
    BuildContext context,
    int id,
    movimiento,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl/movimientos/$id'),
      headers: await _authHeaders(context, jsonBody: true),
      body: jsonEncode(movimiento),
    );
    await _handle401(context, res);
    return res;
  }

  Future crearCardPersonalizado(
    BuildContext context,
    Map<String, String?> body,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/gastos-personalizados/crear-gasto-personalizado'),
      headers: await _authHeaders(context, jsonBody: true),
      body: jsonEncode(body),
    );
    await _handle401(context, res);
    return res;
  }

  Future crearCategoria(BuildContext context, Map<String, String> map) async {
    final res = await http.post(
      Uri.parse('$baseUrl/gastos-personalizados/crear-categoria'),
      headers: await _authHeaders(context, jsonBody: true),
      body: jsonEncode(map),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> listarCategoriaPersonalizado(
    BuildContext context,
    int idCard,
  ) async {
    final res = await http.get(
      Uri.parse(
        '$baseUrl/gastos-personalizados/lista-categoria-personalizado/$idCard',
      ),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> obtenerMovimientosPersonalizados(
    BuildContext context,
    int idCard,
  ) async {
    final res = await http.get(
      Uri.parse(
        '$baseUrl/gastos-personalizados/lista-movimientos-personalizado/$idCard',
      ),
      headers: await _authHeaders(context),
    );
    print(res.body);
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> nuevoGasto(BuildContext context, body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/gastos-personalizados/nuevo-gasto'),
      headers: await _authHeaders(context, jsonBody: true),
      body: jsonEncode(body),
    );
    await _handle401(context, res);
    return res;
  }

  Future<http.Response> listarReporteCard(
    BuildContext context,
    int idCard,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/gastos-personalizados/listar-reporte-card/$idCard'),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

    Future<http.Response> obtenerMovimientoPersonalizado(
    BuildContext context,
    int idMovimiento, 
  ) async {
    final res = await http.get(
      Uri.parse(
        '$baseUrl/gastos-personalizados/obtener-movimiento-personalizado/$idMovimiento',
      ),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }

    Future<http.Response> getDashboardData(
    BuildContext context,
    int anio, int idUsuario, 
  ) async {
    final res = await http.get(
      Uri.parse(
        '$baseUrl/movimientos/listar-dashboard/$anio/$idUsuario',
      ),
      headers: await _authHeaders(context),
    );
    await _handle401(context, res);
    return res;
  }
  
}
