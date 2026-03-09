import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/Movimiento.dart';
import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:app_gestion_gastos/pages/editarMovimiento.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:app_gestion_gastos/pages/nuevoMoviento.dart';
import 'package:app_gestion_gastos/pages/reportes/gastosReportesPage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class Gastosdiarios extends StatefulWidget {
  const Gastosdiarios({super.key});

  @override
  State<Gastosdiarios> createState() => _GastosdiariosState();
}

class _GastosdiariosState extends State<Gastosdiarios> {
  String nombre = '';
  int idUsuario = 0;
  String email = '';
  double montoSaldoTotal = 0.0;
  double montoIngresos = 0.0;
  double montoGastos = 0.0;
  List<Movimiento> movimientos = [];
  final ApiService service = ApiService();
  final storage = AppStorage();

  @override
  void initState() {
    super.initState();
    obtenerDatosDesdeToken();
    obtenerCarResumen();
    obtenerMovimientos(); // 👈 Nuevo
  }

  void obtenerDatosDesdeToken() async {
    String? token = await storage.read(key: 'token');

    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      setState(() {
        nombre = decodedToken['nombre'];
        idUsuario = decodedToken['id'];
        email = decodedToken['sub'];
      });

      print('Nombre: $nombre, ID: $idUsuario, Email: $email');
    }
  }

  void obtenerCarResumen() async {
    final response = await service.cardResumen(context);
    if (response.statusCode == 200) {
      final saldoTotalRaw = jsonDecode(response.body)['saldoTotal'];
      final double saldoTotal = double.parse(saldoTotalRaw.toString());

      final ingresoRaw = jsonDecode(response.body)['totalIngresos'];
      final double ingresoTotal = double.parse(ingresoRaw.toString());

      final gastosRaw = jsonDecode(response.body)['totalGastos'];
      final double gastosTotal = double.parse(gastosRaw.toString());

      setState(() {
        montoSaldoTotal = saldoTotal;
        montoIngresos = ingresoTotal;
        montoGastos = gastosTotal;
      });
    }
  }

  void obtenerMovimientos() async {
    final response = await service.obtenerMovimientos(context);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      print(data);
      setState(() {
        movimientos = data.map((e) => Movimiento.fromJson(e)).toList();
      });
    } else {
      print('Error al obtener movimientos: ${response.statusCode}');
    }
  }

  String getFechaFormateada() {
    DateTime ahora = DateTime.now();
    final locale = 'es_ES'; // Español
    final formatter = DateFormat('EEEE, d \'de\' MMMM', locale);
    return toBeginningOfSentenceCase(formatter.format(ahora)) ?? '';
  }

  // Paleta (igual que el dashboard)
  final Color primary = const Color(0xFF6C55F9);
  final Color bg = const Color(0xFFF8F3FF);

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: bg,
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          foregroundColor: Colors.black87,
          titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
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
          title: const Text('Gastos Diarios'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Cerrar sesión'),
                    content: const Text('¿Deseas salir de tu cuenta?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Salir'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await storage.deleteAll();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // Resumen card
            _BalanceCard(
              primary: primary,
              saldo: montoSaldoTotal,
              ingresos: montoIngresos,
              gastos: montoGastos,
              onTapReportes: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GastosReportesPage(movimientos: movimientos),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            if (movimientos.isEmpty)
              _EmptyState(primary: primary)
            else
              ...List.generate(movimientos.length, (i) {
                final m = movimientos[i];
                final ingreso = m.tipo == 'INGRESO';
                return _MovementTile(
                  titulo: m.descripcion,
                  categoria: m.categoria.nombre,
                  fecha: m.fecha,
                  monto: m.monto,
                  positivo: ingreso,
                  primary: primary,
                  onTap: () async {
                    final created = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EditarMovimientoPage(movimiento: m),
                      ),
                    );

                    if (created == true) {
                      obtenerMovimientos();
                      obtenerCarResumen();
                    }
                  },
                );
              }),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const NuevoMovimientoPage()),
            );

            // Si guardó algo, refresca tu lista/resumen
            if (created == true) {
              obtenerMovimientos();
              obtenerCarResumen();
            }
          },
          backgroundColor: primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ====== Widgets de UI ======

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.primary,
    required this.saldo,
    required this.ingresos,
    required this.gastos,
    required this.onTapReportes,
  });

  final Color primary;
  final double saldo, ingresos, gastos;
  final VoidCallback onTapReportes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary.withOpacity(.95), primary.withOpacity(.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saldo Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onTapReportes,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.dashboard_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'S/ ${saldo.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _stat('Ingresos', 'S/ ${ingresos.toStringAsFixed(2)}'),
                ),
                Expanded(
                  child: _stat(
                    'Gastos',
                    'S/ ${gastos.toStringAsFixed(2)}',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.titulo,
    required this.categoria,
    required this.fecha,
    required this.monto,
    required this.positivo,
    required this.primary,
    this.onTap,
  });

  final String titulo, categoria, fecha;
  final double monto;
  final bool positivo;
  final Color primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amount = '${positivo ? '+ ' : '- '}S/ ${monto.toStringAsFixed(2)}';
    final color = positivo ? Colors.green : Colors.red;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primary.withOpacity(.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  positivo
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      categoria,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    amount,
                    style: TextStyle(fontWeight: FontWeight.w700, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fecha,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.primary});
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 56,
            color: primary.withOpacity(.6),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sin movimientos aún',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            'Agrega tu primer gasto con el botón "Nuevo".',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
