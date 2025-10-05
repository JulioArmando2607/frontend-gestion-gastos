import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/Movimiento.dart';
import 'package:app_gestion_gastos/clases/MovimientoPersonalizado.dart';
import 'package:app_gestion_gastos/pages/dashboard_page.dart';
import 'package:app_gestion_gastos/pages/editarMovimiento.dart';
import 'package:app_gestion_gastos/pages/gastoPersonalizadoRegMovimiento.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizadosConfiguracion.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:app_gestion_gastos/pages/nuevoMoviento.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
Color hexToColor(String hex) {
  var c = hex.replaceAll('#', '');
  if (c.length == 6) c = 'FF$c'; // alpha por defecto
  if (c.length != 8) throw FormatException('Hex inválido');
  return Color(int.parse(c, radix: 16));
}
Color parseColor(dynamic value, {Color fallback = const Color(0xFF6C63FF)}) {
  if (value == null) return fallback;

  if (value is int) return Color(value);

  if (value is String) {
    var s = value.trim().toUpperCase();
    s = s.replaceAll('#', '');
    if (s.startsWith('0X')) s = s.substring(2);

    // si viene RRGGBB -> agrega alpha
    if (s.length == 6) s = 'FF$s';
    if (s.length == 8) {
      final n = int.parse(s, radix: 16);
      return Color(n);
    }
  }

  return fallback; // o lanza FormatException si prefieres
}
class GastoPersonalizadoHome extends StatefulWidget {
/*  ;*/
  final int idCard;

  GastoPersonalizadoHome({
    super.key,
    required this.idCard,
  });
  @override
  State<GastoPersonalizadoHome> createState() => _GastoPersonalizadoHomeState();
}

class _GastoPersonalizadoHomeState extends State<GastoPersonalizadoHome> {
  String nombre = '';
  int idUsuario = 0;
  String email = '';
  double montoSaldoTotal = 0.0;
  double montoIngresos = 0.0;
  double montoGastos = 0.0;
  List<MovimientoPersonalizado> movimientos = [];
  final ApiService service = ApiService();
  final storage = FlutterSecureStorage();
    Color colorHex="" as Color;
    double saldo= 0.0;
    double ingresos= 0.0;
    double gastos= 0.0;
    String nombreGasto = '';

  @override
  void initState() {
    super.initState();
    obtenerDatosDesdeToken();
    obtenerCardPersonalizado();
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

  void obtenerCardPersonalizado() async {
    final response = await service.obtenerCardPersonalizadoxId(context,widget.idCard);
    if (response.statusCode == 200) {
      print(response.body);
      final saldoTotalRaw = jsonDecode(response.body)['saldo'];
      final double saldoTotal = double.parse(saldoTotalRaw.toString());

      final ingresoRaw = jsonDecode(response.body)['ingresos'];
      final double ingresoTotal = double.parse(ingresoRaw.toString());

      final gastosRaw = jsonDecode(response.body)['gastos'];
      final double gastosTotal = double.parse(gastosRaw.toString());

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final colorHexRaw = data['colorHex'];           // puede ser "#6C63FF"
      final Color colorh = parseColor(colorHexRaw);   // listo para usar


      setState(() {
        montoSaldoTotal = saldoTotal;
        montoIngresos = ingresoTotal;
        montoGastos = gastosTotal;
         colorHex=colorh;
        final double saldo= 0.0;
        final double ingresos= 0.0;
        final double gastos= 0.0;
        final String nombreGasto = '';
      });
/*saldo: m.saldo,
                    ingresos: m.ingresos,
                    gastos: m.gastos,
                    nombreGasto: m.nombre,
                    idCard: m.id,*/
    } else {
      print('Error al obtener movimientos: ${response.statusCode}');
    }
  }

  void obtenerMovimientos() async {
    final response = await service.obtenerMovimientosPersonalizados(context,widget.idCard);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        movimientos = data.map((e) => MovimientoPersonalizado.fromJson(e)).toList();
      });
    } else {
      print('Error al obtener movimientos: ${response.statusCode}');
    }
  }

  eliminarMovimiento(id) async {
    final response = await service.eliminarMovimiento(context, id.toString());
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Movimiento eliminado con éxito')));
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
 // final Color primary = ;
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const GastosPersonalizados()),
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: Text(nombreGasto),
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
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await storage.deleteAll();
                  if (!mounted) return;
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
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
              primary: colorHex,
              saldo: montoSaldoTotal,
              ingresos: montoIngresos,
              gastos: montoGastos,
            ),
            const SizedBox(height: 16),

            if (movimientos.isEmpty)
              _EmptyState(primary:  colorHex)
            else
              ...List.generate(movimientos.length, (i) {
                final m = movimientos[i];
                final ingreso = m.tipo == 'INGRESO';
                return Dismissible(
                  key: Key(m.id.toString()),
                  background: _dismissBg(Colors.blue, Icons.edit_rounded, Alignment.centerLeft),
                  secondaryBackground: _dismissBg(Colors.red, Icons.delete_rounded, Alignment.centerRight),
                  confirmDismiss: (dir) async {
                    if (dir == DismissDirection.endToStart) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Confirmar eliminación'),
                          content: const Text('¿Eliminar este movimiento?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
                          ],
                        ),
                      );
                      return ok ?? false;
                    } else {

                      /*  final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => EditarMovimientoPage(movimiento: m)),
                      );

                      // Si guardó algo, refresca tu lista/resumen
                      if (created == true) {
                        obtenerMovimientos();
                        obtenerCardPersonalizado();
                      }

                        Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => EditarMovimientoPage(movimiento: m)),
                      ); */
                      return false;
                    }
                  },
                  onDismissed: (dir) async {
                    if (dir == DismissDirection.endToStart) {
                      await eliminarMovimiento(m.id);
                      setState(() {
                        movimientos.removeAt(i);
                        obtenerCardPersonalizado();
                        obtenerMovimientos();
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimiento eliminado')));
                    }
                  },
                  child: _MovementTile(
                    titulo: m.descripcion,
                    categoria: m.categoria,
                    fecha: m.fecha,
                    monto: m.monto,
                    positivo: ingreso,
                    primary:  colorHex,
                  ),
                );
              }),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final opcion = await showModalBottomSheet<String>(
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (context) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.monetization_on_rounded, color: Colors.green),
                        title: const Text('Registrar movimiento'),
                        onTap: () => Navigator.pop(context, 'movimiento'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.category_rounded, color: Colors.blue),
                        title: const Text('Registrar categoría'),
                        onTap: () => Navigator.pop(context, 'categoria'),
                      ),
                    ],
                  ),
                );
              },
            );

            // Dependiendo de la opción
            if (opcion == 'movimiento') {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) =>  GastoPersonalizadoRegMovimientoPage(idCard: widget.idCard,)),
              );
              if (created == true) {
                obtenerMovimientos();
                obtenerCardPersonalizado();
              }
            } else if (opcion == 'categoria') {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) =>  CategoriasPage(idCard: widget.idCard)),
              );
              // refrescar categorías si es necesario
            }
          },
          backgroundColor: colorHex,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),

      ),
    );
  }

  Widget _dismissBg(Color c, IconData icon, Alignment align) => Container(
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(22)),
    child: Icon(icon, color: Colors.white),
  );
}

// ====== Widgets de UI ======

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.primary,
    required this.saldo,
    required this.ingresos,
    required this.gastos,
  });

  final Color primary;
  final double saldo, ingresos, gastos;

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
            Row(children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Text('Saldo Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text('S/ ${saldo.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _stat('Ingresos', 'S/ ${ingresos.toStringAsFixed(2)}')),
                Expanded(child: _stat('Gastos', 'S/ ${gastos.toStringAsFixed(2)}', alignEnd: true)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
  });

  final String titulo, categoria, fecha;
  final double monto;
  final bool positivo;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final amount = (positivo ? '+ ' : '- ') + 'S/ ${monto.toStringAsFixed(2)}';
    final color = positivo ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: primary.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(positivo ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(categoria, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(fecha, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ],
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
          Icon(Icons.receipt_long_rounded, size: 56, color: primary.withOpacity(.6)),
          const SizedBox(height: 12),
          const Text('Sin movimientos aún', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('Agrega tu primer gasto con el botón "Nuevo".', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

}
