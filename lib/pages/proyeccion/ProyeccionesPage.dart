import 'dart:convert';

import 'package:app_gestion_gastos/api/proyeccion_compartida_service.dart';
import 'package:app_gestion_gastos/api/proyeccion_service.dart';
import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:app_gestion_gastos/pages/proyeccion/ProyeccionMensualPage.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class ProyeccionesPage extends StatefulWidget {
  const ProyeccionesPage({super.key});

  @override
  State<ProyeccionesPage> createState() => _ProyeccionesPageState();
}

class _ProyeccionesPageState extends State<ProyeccionesPage> {
  final ProyeccionService proyeccionService = ProyeccionService();
  final ProyeccionCompartidaService proyeccionCompartidaService =
      ProyeccionCompartidaService();
  static const Color primary = Color(0xFF6C55F9);
  static const Color bg = Color(0xFFF8F3FF);
  static const Color cardLight = Color(0xFFF2EEFF);
  static const Color cardShared = Color(0xFFEAF2FF);
  static const Color textDark = Color(0xFF2D2A45);

  bool loading = true;
  bool backendMisDisponible = true;
  bool backendCompartidasDisponible = true;
  int idUsuarioActual = 0;
  List<_ProyeccionItem> misProyecciones = [];
  List<_ProyeccionItem> compartidas = [];
  final storage = const AppStorage();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => loading = true);
    try {
      if (idUsuarioActual <= 0) {
        idUsuarioActual = await _obtenerIdUsuarioActual();
      }

      final misRes = await proyeccionService.listarMisProyecciones(context);
      if (misRes.statusCode == 200) {
        final decoded = jsonDecode(misRes.body);
        misProyecciones = _parseLista(decoded, shared: false);
        backendMisDisponible = true;
      } else if (misRes.statusCode == 404 || misRes.statusCode == 405) {
        backendMisDisponible = false;
        misProyecciones = [];
      } else {
        misProyecciones = [];
      }

      final compRes = await proyeccionCompartidaService.listarProyeccionesRecibidas(
        context,
        idUsuario: idUsuarioActual,
      );
      if (compRes.statusCode == 200) {
        final decoded = jsonDecode(compRes.body);
        compartidas = _parseListaRecibidas(decoded);
        backendCompartidasDisponible = true;
      } else if (compRes.statusCode == 404 || compRes.statusCode == 405) {
        backendCompartidasDisponible = false;
        compartidas = [];
      } else {
        compartidas = [];
      }
    } catch (_) {
      misProyecciones = [];
      compartidas = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<int> _obtenerIdUsuarioActual() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || JwtDecoder.isExpired(token)) return 0;
      final decoded = JwtDecoder.decode(token);
      return _toInt(decoded['id']);
    } catch (_) {
      return 0;
    }
  }

  List<_ProyeccionItem> _parseLista(dynamic decoded, {required bool shared}) {
    if (decoded is! List) return [];
    return decoded.map<_ProyeccionItem>((raw) {
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return _ProyeccionItem(
        proyeccionId: _toInt(map['proyeccionId'] ?? map['id']),
        ownerUserId: _toInt(
          map['ownerUserId'] ??
              map['idUsuario'] ??
              map['usuarioId'] ??
              map['idUsuarioOrigen'],
        ),
        anio: _toInt(map['anio'] ?? DateTime.now().year),
        mes: _toInt(map['mes'] ?? DateTime.now().month),
        ingresoMensual: _toDouble(map['ingresoMensual']),
        totalGasto: _toDouble(map['totalGasto']),
        ahorroEstimado: _toDouble(map['ahorroEstimado']),
        nombreOrigen: (map['nombreOrigen'] ??
                map['usuarioOrigenNombre'] ??
                map['nombreUsuario'] ??
                '')
            .toString(),
        fechaCompartido: (map['fechaCompartido'] ?? '').toString(),
        shared: shared,
      );
    }).toList();
  }

  List<_ProyeccionItem> _parseListaRecibidas(dynamic decoded) {
    if (decoded is! Map) return [];
    if (_toInt(decoded['codResultado']) != 1) return [];
    final response = decoded['response'];
    if (response is! List) return [];

    final now = DateTime.now();
    return response.map<_ProyeccionItem>((raw) {
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      return _ProyeccionItem(
        proyeccionId: _toInt(map['idProyeccion']),
        ownerUserId: _toInt(map['idPersonaCompartida']),
        anio: now.year,
        mes: now.month,
        ingresoMensual: 0,
        totalGasto: 0,
        ahorroEstimado: 0,
        nombreOrigen: (map['nombrePersonaCompartida'] ?? '').toString(),
        fechaCompartido: (map['fechaCompartido'] ?? '').toString(),
        shared: true,
      );
    }).toList();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardPage()),
              );
            }
          },
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Proyecciones',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _topSummaryCard(),
                  const SizedBox(height: 16),
                  _sectionTitle('Mis proyecciones', Icons.person_rounded),
                  const SizedBox(height: 8),
                  if (!backendMisDisponible || misProyecciones.isEmpty)
                    _miProyeccionActualCard()
                  else
                    ...misProyecciones.map(
                      (p) => _proyeccionCard(
                        item: p,
                        subtitle: 'Tu proyección',
                        onTap: () => _abrirDetalle(p),
                      ),
                    ),
                  const SizedBox(height: 18),
                  _sectionTitle(
                    'Compartidas conmigo',
                    Icons.group_outlined,
                  ),
                  const SizedBox(height: 8),
                  if (!backendCompartidasDisponible)
                    _emptyCard(
                      'Backend de compartidas no disponible aún. '
                      'Falta exponer el endpoint de compartición.',
                    )
                  else if (compartidas.isEmpty)
                    _emptyCard('No tienes proyecciones compartidas.')
                  else
                    ...compartidas.map(
                      (p) => _proyeccionCard(
                        item: p,
                        subtitle: p.nombreOrigen.isNotEmpty
                            ? 'Compartida por ${p.nombreOrigen} '''
                            : 'Proyección compartida',
                        onTap: () => _abrirDetalle(p),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _topSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withValues(alpha: .95), const Color(0xFF8A76FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tus proyecciones',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
           //   _miniBadge('Mías', misProyecciones.length, Colors.white),
              const SizedBox(width: 10),
              _miniBadge('Compartidas', compartidas.length, Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String label, int value, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primary, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
      ],
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: .12)),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade700),
      ),
    );
  }

    Widget _proyeccionCard({
    required _ProyeccionItem item,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final monthName = toBeginningOfSentenceCase(
          DateFormat('MMMM', 'es_ES').format(DateTime(item.anio, item.mes)),
        ) ??
        'Mes';

    final isShared = item.shared;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isShared ? cardShared : cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isShared
              ? const Color(0xFFBFD7FF)
              : primary.withValues(alpha: .22),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(
          '$monthName ${item.anio}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: textDark),
        ),
        subtitle: Text(
          _buildCardSubtitle(item, subtitle),
          style: TextStyle(color: Colors.grey.shade700),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isShared ? const Color(0xFF2A66B2) : primary,
        ),
      ),
    );
  }

  Widget _miProyeccionActualCard() {
    final now = DateTime.now();
    final monthName = toBeginningOfSentenceCase(
          DateFormat('MMMM', 'es_ES').format(DateTime(now.year, now.month)),
        ) ??
        'Mes';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: .22)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const ProyeccionMensualPage(pageTitle: 'Mi proyección'),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        title: Text(
          '$monthName ${now.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, color: textDark),
        ),
        subtitle: Text(
          'Tu proyección actual',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: primary),
      ),
    );
  }

  String _buildCardSubtitle(_ProyeccionItem item, String subtitle) {
    if (item.shared && item.ingresoMensual == 0 && item.totalGasto == 0) {
      final fecha = _formatearFecha(item.fechaCompartido);
      return fecha.isNotEmpty ? '$subtitle\nCompartido: $fecha' : subtitle;
    }
    return '$subtitle\nIngreso: S/ ${item.ingresoMensual.toStringAsFixed(2)} · '
        'Gasto: S/ ${item.totalGasto.toStringAsFixed(2)}';
  }

  String _formatearFecha(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(dt);
  }

  void _abrirDetalle(_ProyeccionItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProyeccionMensualPage(
          ownerUserId: item.ownerUserId > 0 ? item.ownerUserId : null,
          sharedProyeccionId: item.shared ? item.proyeccionId : null,
          initialYear: item.anio,
          initialMonth: item.mes,
          readOnly: item.shared,
          pageTitle: item.shared ? 'Proyección compartida' : 'Mi proyección',
        ),
      ),
    );
  }
}

class _ProyeccionItem {
  _ProyeccionItem({
    required this.proyeccionId,
    required this.ownerUserId,
    required this.anio,
    required this.mes,
    required this.ingresoMensual,
    required this.totalGasto,
    required this.ahorroEstimado,
    required this.nombreOrigen,
    required this.fechaCompartido,
    required this.shared,
  });

  final int proyeccionId;
  final int ownerUserId;
  final int anio;
  final int mes;
  final double ingresoMensual;
  final double totalGasto;
  final double ahorroEstimado;
  final String nombreOrigen;
  final String fechaCompartido;
  final bool shared;
}



