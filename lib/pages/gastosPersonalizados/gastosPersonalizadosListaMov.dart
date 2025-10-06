import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/MovimientoPersonalizado.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/ReporteMensualModal.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/gastoPersonalizadoRegMovimiento.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/gastosPersonalizados.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/Config/gastosPersonalizadosConfiguracion.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:app_gestion_gastos/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

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

  const GastoPersonalizadoHome({super.key, required this.idCard});
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
  Color colorHex = const Color(0xFF6C63FF); // color por defecto

  // Color colorHex = "" as Color;
  double saldo = 0.0;
  double ingresos = 0.0;
  double gastos = 0.0;
  String nombreGasto = '';

  bool isCategoria = false;
  String nombreCard = '';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      obtenerDatosDesdeToken();
      obtenerCardPersonalizado();
      obtenerMovimientos();
      _cargarCategorias(widget.idCard);
    });
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
    // 🔹 Mostrar loading
    showLoadingDialog(context, message: 'Cargando datos...');

    try {
      final response = await service.obtenerCardPersonalizadoxId(
        context,
        widget.idCard,
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == "null") {
          print("⚠️ Respuesta vacía o null");
          return;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        //nombre
        // print("data 2222");

        print(data);

        final nombre = data['nombre'].toString();

        final saldoTotal = double.parse(data['saldo'].toString());
        final ingresoTotal = double.parse(data['ingresos'].toString());
        final gastosTotal = double.parse(data['gastos'].toString());
        final colorHexRaw = data['colorHex'];
        final Color colorh = parseColor(colorHexRaw ?? "#000000");

        setState(() {
          nombreCard = nombre;
          montoSaldoTotal = saldoTotal;
          montoIngresos = ingresoTotal;
          montoGastos = gastosTotal;
          colorHex = colorh;
        });
      } else {
        print('❌ Error al obtener movimientos: ${response.statusCode}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al obtener movimientos')));
      }
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
    } finally {
      // 🔹 Cerrar loading siempre
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  void obtenerMovimientos() async {
    final response = await service.obtenerMovimientosPersonalizados(
      context,
      widget.idCard,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        movimientos = data
            .map((e) => MovimientoPersonalizado.fromJson(e))
            .toList();
      });
    } else {
      print('Error al obtener movimientos: ${response.statusCode}');
    }
  }

  eliminarMovimiento(id) async {
    final response = await service.eliminarMovimientoP(context, id.toString());
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
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
          title: Text(nombreCard),
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
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
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
              primary: colorHex,
              saldo: montoSaldoTotal,
              ingresos: montoIngresos,
              gastos: montoGastos,
            ),
            const SizedBox(height: 16),

            if (movimientos.isEmpty)
              _EmptyState(primary: colorHex)
            else
              ...List.generate(movimientos.length, (i) {
                final m = movimientos[i];
                final ingreso = m.tipo == 'INGRESO';
                return Dismissible(
                  key: Key(m.id.toString()),
                  background: _dismissBg(
                    Colors.blue,
                    Icons.edit_rounded,
                    Alignment.centerLeft,
                  ),
                  secondaryBackground: _dismissBg(
                    Colors.red,
                    Icons.delete_rounded,
                    Alignment.centerRight,
                  ),
                  confirmDismiss: (dir) async {
                    if (dir == DismissDirection.endToStart) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Confirmar eliminación'),
                          content: const Text('¿Eliminar este movimiento?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                      return ok ?? false;
                    } else if (dir == DismissDirection.startToEnd) {
                      final creado = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => GastoPersonalizadoRegMovimientoWidget(
                          idCard: widget.idCard,
                          idMovimiento: m.id,
                        ),
                      );

                      if (creado == true) {
                        obtenerCardPersonalizado();
                        obtenerMovimientos();
                      }
                      //  return false;
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Movimiento eliminado')),
                      );
                    }
                  },
                  child: _MovementTile(
                    titulo: m.descripcion,
                    categoria: m.categoria,
                    fecha: m.fecha,
                    monto: m.monto,
                    positivo: ingreso,
                    primary: colorHex,
                  ),
                );
              }),
            const SizedBox(
              height: 100,
            ), // 👈 Espacio extra para que el FAB no tape
          ],
        ),
        floatingActionButton: SpeedDial(
          icon: Icons.add,
          activeIcon: Icons.close,
          backgroundColor: colorHex,
          foregroundColor: Colors.white,
          spacing: 10,
          spaceBetweenChildren: 6,
          children: [
            SpeedDialChild(
              child: const Icon(
                Icons.monetization_on_rounded,
                color: Colors.green,
              ),
              label: 'Registrar movimiento',
              onTap: () async {
                if (!isCategoria) {
                  await showDialog(
                    context: context,
                    builder: (ctx) => const AlertDialog(
                      title: Text('No hay categorías'),
                      content: Text(
                        'Primero debes registrar al menos una categoría.',
                      ),
                    ),
                  );
                  return;
                }

                final creado = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => GastoPersonalizadoRegMovimientoWidget(
                    idCard: widget.idCard,
                    idMovimiento: 0,
                  ),
                );

                if (creado == true) {
                  obtenerCardPersonalizado();
                  obtenerMovimientos();
                }
              },
            ),
            SpeedDialChild(
              child: const Icon(Icons.category_rounded, color: Colors.blue),
              label: 'Registrar categoría',
              onTap: () {
                //async
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  isScrollControlled: true,
                  builder: (context) => CategoriasPage(idCard: widget.idCard),
                );
              },
            ),
            SpeedDialChild(
              child: const Icon(
                Icons.insert_chart_rounded,
                color: Colors.orange,
              ),
              label: 'Ver reporte mensual',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  isScrollControlled: true,
                  //  builder: (_) => ReporteMensualModal(idCard: widget.idCard),
                  builder: (context) =>
                      ReporteMensualModal(idCard: widget.idCard),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cargarCategorias(int idCard) async {
    final resGasto = await service.obtenerCategoriaPersonalizadoxTipo(
      context,
      idCard,
      "GASTO",
    );

    // Buscar categorías de tipo INGRESO
    final resIngreso = await service.obtenerCategoriaPersonalizadoxTipo(
      context,
      idCard,
      "INGRESO",
    );

    // Verificar si alguna tiene contenido
    if (resGasto.statusCode == 200) {
      final listGasto = jsonDecode(resGasto.body) as List;
      if (listGasto.isNotEmpty) {
        isCategoria = true;
      }
    }

    if (resIngreso.statusCode == 200) {
      final listIngreso = jsonDecode(resIngreso.body) as List;
      if (listIngreso.isNotEmpty) {
        isCategoria = true;
      }
    }

    // DEBUG opcional
    print('¿Hay alguna categoría?: $isCategoria');
  }

  Widget _dismissBg(Color c, IconData icon, Alignment align) => Container(
    alignment: align,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(22),
    ),
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
            Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(
                  'Saldo Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
  });

  final String titulo, categoria, fecha;
  final double monto;
  final bool positivo;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final amount = '${positivo ? '+ ' : '- '}S/ ${monto.toStringAsFixed(2)}';
    final color = positivo ? Colors.green : Colors.red;

    return Card(
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
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
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
