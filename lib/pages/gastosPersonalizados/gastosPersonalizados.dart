import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/CardPersonalizado.dart';
import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/gastosPersonalizadosListaMov.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:app_gestion_gastos/pages/nuevoGastoPersonalizado.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'dart:convert';

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
  final storage = AppStorage();

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

  Future<bool> eliminarMovimiento(int id) async {
    final response = await service.eliminarCardPersonalizado(context, id);
    if (response.statusCode == 200 || response.statusCode == 204) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tarjeta eliminada con éxito')));
      return true;
    } else {
      print('Error al eliminar tarjeta: ${response.statusCode}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar (${response.statusCode})')),
      );
      return false;
    }
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
          title: const Text('Mis Tarjetas'),
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
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Primero ingresa a una tarjeta para agregar movimientos.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text(
                'Ingresa a una tarjeta para agregar movimientos',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary.withOpacity(.45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (movimientos.isEmpty)
              _EmptyState(primary: primary)
            else
              ...List.generate(movimientos.length, (i) {
                final m = movimientos[i];
                return _BalanceCard(
                  colorHex: hexToColor(m.colorHex),
                  saldo: m.saldo,
                  ingresos: m.ingresos,
                  gastos: m.gastos,
                  nombreGasto: m.nombre,
                  idCard: m.id,
                  onIngresar: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GastoPersonalizadoHome(idCard: m.id),
                      ),
                    );
                    if (!mounted) return;
                    obtenerCardPersonalizado();
                  },
                  onEditar: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => NuevoCardPersonalizadoPage(card: m),
                      ),
                    );
                    if (updated == true) {
                      obtenerCardPersonalizado();
                    }
                  },
                  onEliminar: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Eliminar tarjeta'),
                        content: Text('¿Deseas eliminar "${m.nombre}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    final eliminado = await eliminarMovimiento(m.id);
                    if (!eliminado || !mounted) return;
                    setState(() {
                      movimientos.removeWhere((item) => item.id == m.id);
                    });
                    obtenerCardPersonalizado();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tarjeta eliminada')),
                    );
                  },
                );
              }),
                  const SizedBox(height: 100), // 👈 Espacio extra para que el FAB no tape

          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final created = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => const NuevoCardPersonalizadoPage(),
              ),
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
    required this.colorHex,
    required this.saldo,
    required this.ingresos,
    required this.gastos,
    required this.nombreGasto,
    required this.idCard,
    required this.onIngresar,
    required this.onEditar,
    required this.onEliminar,
  });

  final Color colorHex;
  final double saldo, ingresos, gastos;
  final String nombreGasto;
  final int idCard;
  final VoidCallback onIngresar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorHex.withOpacity(.95),
              colorHex.withOpacity(.75),
            ], //colorHex
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
                Expanded(
                  child: Text(
                    nombreGasto,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _cardActionIcon(
                  icon: Icons.login_rounded,
                  tooltip: 'Ingresar',
                  onTap: onIngresar,
                ),
                const SizedBox(width: 6),
                _cardActionIcon(
                  icon: Icons.edit_rounded,
                  tooltip: 'Editar',
                  onTap: onEditar,
                ),
                const SizedBox(width: 6),
                _cardActionIcon(
                  icon: Icons.delete_rounded,
                  tooltip: 'Eliminar',
                  onTap: onEliminar,
                ),
              ],
            ),
            const SizedBox(height: 6),
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
                  child: _stat(
                    'Ingresos',
                    'S/ ${ingresos.toStringAsFixed(2)}',
                  ),
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

  Widget _cardActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(.55)),
      ),
      child: IconButton(
        onPressed: onTap,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        visualDensity: VisualDensity.compact,
        color: Colors.white,
        icon: Icon(icon, size: 16),
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
            'Sin gastos personalizados aún',
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

Color hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) {
    hex = 'FF$hex'; // añadir opacidad completa
  }
  return Color(int.parse(hex, radix: 16));
}

