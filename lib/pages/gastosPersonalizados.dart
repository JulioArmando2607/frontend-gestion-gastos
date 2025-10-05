import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/CardPersonalizado.dart';
import 'package:app_gestion_gastos/clases/Movimiento.dart';
import 'package:app_gestion_gastos/pages/dashboard_page.dart';
import 'package:app_gestion_gastos/pages/editarMovimiento.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizadosHome.dart';
import 'package:app_gestion_gastos/pages/home.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:app_gestion_gastos/pages/nuevoGastoPersonalizado.dart';
import 'package:app_gestion_gastos/pages/nuevoMoviento.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class GastosPersonalizados extends StatefulWidget {
  const GastosPersonalizados({super.key});

  @override
  State<GastosPersonalizados> createState() => _GastosPersonalizadosState();
}

class _GastosPersonalizadosState extends State<GastosPersonalizados> {
  String nombre = '';
  int idUsuario = 0;
  String email = '';
  double montoSaldoTotal = 0.0;
  double montoIngresos = 0.0;
  double montoGastos = 0.0;
  List<CardPersonalizado> movimientos = [];
  final ApiService service = ApiService();
  final storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    obtenerDatosDesdeToken();
    obtenerCardPersonalizado(); // 👈 Nuevo
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
    final response = await service.obtenerCardPersonalizado(context);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        movimientos = data.map((e) => CardPersonalizado.fromJson(e)).toList();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            ),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          title: const Text('Gastos Personalizadzos'),
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

            const SizedBox(height: 16),
   if (movimientos.isEmpty)
              _EmptyState(primary: primary)
            else
              ...List.generate(movimientos.length, (i) {
                final m = movimientos[i];
            //    final ingreso = m.tipo == 'INGRESO';
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
                      /*
                      final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(builder: (_) => EditarMovimientoPage(movimiento: m)),
                      );

                      // Si guardó algo, refresca tu lista/resumen
                      if (created == true) {
                        obtenerCardPersonalizado();
                        obtenerCarResumen();
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
                      });
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimiento eliminado')));
                    }
                  },
                  child:  _BalanceCard(
                    colorHex: hexToColor(m.colorHex),
                    saldo: m.saldo,
                    ingresos: m.ingresos,
                    gastos: m.gastos,
                    nombreGasto: m.nombre,
                    idCard: m.id,
                  ),

                );
              }),

          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const NuevoCardPersonalizadoPage()),
            );

            // Si guardó algo, refresca tu lista/resumen
            if (created == true) {
              obtenerCardPersonalizado();
             }
          },
          backgroundColor: primary,
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
    required this.colorHex,
    required this.saldo,
    required this.ingresos,
    required this.gastos,
    required this.nombreGasto,
    required this.idCard
  });

  final Color colorHex;
  final double saldo, ingresos, gastos;
  final String nombreGasto;
  final int idCard;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: (){
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => GastoPersonalizadoHome(

            idCard: idCard,
          )),
        );
       },
      child: Card(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorHex.withOpacity(.95), colorHex.withOpacity(.75)],//colorHex
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
              //  const Icon(Icons.account_balance_wallet_rounded, color: Colors.amber),
               // const SizedBox(width: 8),
                Text('${nombreGasto}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 6),
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
          const Text('Sin gastos personalizados aún', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('Agrega tu primer gasto con el botón "Nuevo".', style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

}

Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex'; // añadir opacidad completa
  }
  return Color(int.parse(hex, radix: 16));
}
