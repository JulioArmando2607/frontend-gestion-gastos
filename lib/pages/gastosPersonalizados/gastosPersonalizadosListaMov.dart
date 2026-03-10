import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/MovimientoPersonalizado.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/ReporteMensualModal.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/gastoPersonalizadoRegMovimiento.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/gastosPersonalizados.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:app_gestion_gastos/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
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
  final storage = AppStorage();
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
    // Mostrar loading
    showLoadingDialog(context, message: 'Cargando datos...');

    try {
      final response = await service.obtenerCardPersonalizadoxId(
        context,
        widget.idCard,
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == "null") {
          print("Respuesta vacía o null");
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
        print('Error al obtener movimientos: ${response.statusCode}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al obtener movimientos')));
      }
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
    } finally {
      // Cerrar loading siempre
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
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GastosPersonalizados(),
                  ),
                );
              }
            },
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
            _BalanceCard(
              primary: colorHex,
              saldo: montoSaldoTotal,
              ingresos: montoIngresos,
              gastos: montoGastos,
              onReporte: _abrirReporteMensual,
              onAgregarCategoria: () {
                _abrirAgregarCategoriaRapido();
              },
            ),
            const SizedBox(height: 16),
            if (movimientos.isEmpty)
              _EmptyState(primary: colorHex)
            else
              ...List.generate(movimientos.length, (i) {
                final m = movimientos[i];
                final ingreso = m.tipo == 'INGRESO';
                return _MovementTile(
                  titulo: m.descripcion,
                  categoria: m.categoria,
                  fecha: m.fecha,
                  monto: m.monto,
                  positivo: ingreso,
                  primary: colorHex,
                  onEdit: () async {
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
                  },
                  onDelete: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Eliminar movimiento'),
                        content: const Text(
                          '¿Estás seguro de eliminar este movimiento?',
                        ),
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

                    await eliminarMovimiento(m.id);
                    if (!mounted) return;
                    setState(() {
                      movimientos.removeWhere((mov) => mov.id == m.id);
                    });
                    obtenerCardPersonalizado();
                    obtenerMovimientos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Movimiento eliminado')),
                    );
                  },
                );
              }),
            const SizedBox(height: 100),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: colorHex,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar movimiento'),
          onPressed: () async {
            await _cargarCategorias(widget.idCard);

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
      ),
    );
  }

  Future<void> _cargarCategorias(int idCard) async {
    isCategoria = false;
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

  Future<void> _abrirAgregarCategoriaRapido() async {
    final nombreCtrl = TextEditingController();
    String tipoMovimiento = 'GASTO';
    bool guardando = false;
    bool cargandoCategorias = true;
    bool yaCargoCategorias = false;
    bool huboCambios = false;
    List<Map<String, dynamic>> categoriasRegistradas = [];

    Future<void> cargarCategoriasModal(void Function(void Function()) setModalState) async {
      setModalState(() => cargandoCategorias = true);
      try {
        final resGasto = await service.obtenerCategoriaPersonalizadoxTipo(
          context,
          widget.idCard,
          'GASTO',
        );
        final resIngreso = await service.obtenerCategoriaPersonalizadoxTipo(
          context,
          widget.idCard,
          'INGRESO',
        );

        final List<Map<String, dynamic>> lista = [];
        if (resGasto.statusCode == 200) {
          final data = jsonDecode(resGasto.body) as List;
          for (final item in data) {
            final map = Map<String, dynamic>.from(item);
            lista.add({
              'id': map['id'],
              'nombre': (map['nombre'] ?? 'Sin nombre').toString(),
              'tipo': 'GASTO',
            });
          }
        }
        if (resIngreso.statusCode == 200) {
          final data = jsonDecode(resIngreso.body) as List;
          for (final item in data) {
            final map = Map<String, dynamic>.from(item);
            lista.add({
              'id': map['id'],
              'nombre': (map['nombre'] ?? 'Sin nombre').toString(),
              'tipo': 'INGRESO',
            });
          }
        }

        setModalState(() {
          categoriasRegistradas = lista;
          cargandoCategorias = false;
        });
      } catch (_) {
        setModalState(() => cargandoCategorias = false);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            if (!yaCargoCategorias) {
              yaCargoCategorias = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!ctx.mounted) return;
                cargarCategoriasModal(setModalState);
              });
            }
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agregar categoría',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Crea una categoría para organizar mejor tus movimientos.',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de categoría',
                      hintText: 'Ejemplo: Comida, Transporte',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tipo de categoría',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Gasto'),
                          selected: tipoMovimiento == 'GASTO',
                          onSelected: (_) =>
                              setModalState(() => tipoMovimiento = 'GASTO'),
                          avatar: Icon(
                            Icons.trending_down_rounded,
                            size: 18,
                            color: tipoMovimiento == 'GASTO'
                                ? Colors.white
                                : Colors.red.shade600,
                          ),
                          selectedColor: Colors.red.shade500,
                          labelStyle: TextStyle(
                            color: tipoMovimiento == 'GASTO'
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Ingreso'),
                          selected: tipoMovimiento == 'INGRESO',
                          onSelected: (_) =>
                              setModalState(() => tipoMovimiento = 'INGRESO'),
                          avatar: Icon(
                            Icons.trending_up_rounded,
                            size: 18,
                            color: tipoMovimiento == 'INGRESO'
                                ? Colors.white
                                : Colors.green.shade700,
                          ),
                          selectedColor: Colors.green.shade600,
                          labelStyle: TextStyle(
                            color: tipoMovimiento == 'INGRESO'
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Categorías registradas',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: cargandoCategorias
                        ? const Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : categoriasRegistradas.isEmpty
                            ? Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Aún no tienes categorías. Crea la primera arriba.',
                                      style: TextStyle(color: Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: categoriasRegistradas.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 10),
                                itemBuilder: (_, i) {
                                  final c = categoriasRegistradas[i];
                                  final esGasto = c['tipo'] == 'GASTO';
                                  return Row(
                                    children: [
                                      Icon(
                                        esGasto
                                            ? Icons.trending_down_rounded
                                            : Icons.trending_up_rounded,
                                        size: 16,
                                        color: esGasto
                                            ? Colors.red.shade500
                                            : Colors.green.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          c['nombre']?.toString() ?? 'Sin nombre',
                                        ),
                                      ),
                                      Text(
                                        c['tipo'].toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        tooltip: 'Eliminar categoría',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        onPressed: () async {
                                          final idCategoria =
                                              (c['id'] is num)
                                                  ? (c['id'] as num).toInt()
                                                  : int.tryParse(
                                                        c['id']?.toString() ?? '',
                                                      ) ??
                                                      0;
                                          if (idCategoria == 0) return;

                                          final confirmar = await showDialog<bool>(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Eliminar categoría'),
                                              content: Text(
                                                '¿Deseas eliminar "${c['nombre']}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  child: const Text('Eliminar'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmar != true) return;

                                          setModalState(() => guardando = true);
                                          final resDelete = await service
                                              .eliminarCategoriaPersonalizada(
                                                context,
                                                idCategoria,
                                              );
                                          setModalState(() => guardando = false);

                                          if (resDelete.statusCode == 200 ||
                                              resDelete.statusCode == 204) {
                                            huboCambios = true;
                                            await cargarCategoriasModal(
                                              setModalState,
                                            );
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Categoría eliminada'),
                                              ),
                                            );
                                          } else {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'No se pudo eliminar (${resDelete.statusCode})',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: guardando ? null : () => Navigator.pop(ctx),
                          child: const Text('Cerrar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: guardando
                              ? null
                              : () async {
                                  final nombre = nombreCtrl.text.trim();
                                  if (nombre.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Escribe un nombre para la categoría.'),
                                      ),
                                    );
                                    return;
                                  }

                                  setModalState(() => guardando = true);
                                  final res = await service.crearCategoria(context, {
                                    'idCard': widget.idCard.toString(),
                                    'nombre': nombre,
                                    'tipoMovimiento': tipoMovimiento,
                                  });
                                  setModalState(() => guardando = false);

                                  if (res.statusCode == 200 || res.statusCode == 201) {
                                    nombreCtrl.clear();
                                    huboCambios = true;
                                    await cargarCategoriasModal(setModalState);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Categoría creada')),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No se pudo crear la categoría (${res.statusCode})',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: guardando
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Agregar categoría'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (huboCambios) {
      if (!mounted) return;
      await _cargarCategorias(widget.idCard);
    }
  }

  void _abrirReporteMensual() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReporteMensualPage(idCard: widget.idCard),
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
    this.onReporte,
    this.onAgregarCategoria,
  });

  final Color primary;
  final double saldo, ingresos, gastos;
  final VoidCallback? onReporte;
  final VoidCallback? onAgregarCategoria;

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
            if (onReporte != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onAgregarCategoria != null)
                    OutlinedButton.icon(
                      onPressed: onAgregarCategoria,
                      icon: const Icon(Icons.category_rounded, size: 18),
                      label: const Text('Agregar categoría'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(.8)),
                      ),
                    ),
                  if (onAgregarCategoria != null) const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onReporte,
                    icon: const Icon(Icons.insert_chart_rounded, size: 18),
                    label: const Text('Reporte'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(.8)),
                    ),
                  ),
                ],
              ),
            ],
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
    required this.onEdit,
    required this.onDelete,
  });

  final String titulo, categoria, fecha;
  final double monto;
  final bool positivo;
  final Color primary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amount = '${positivo ? '+ ' : '- '}S/ ${monto.toStringAsFixed(2)}';
    final color = positivo ? Colors.green : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            Row(
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: primary,
                    border: Border.all(color: primary),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: onEdit,
                    tooltip: 'Editar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: primary,//primary.withOpacity(.08),
                    border: Border.all(color: primary.withOpacity(.45)),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: onDelete,
                    tooltip: 'Eliminar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    color: Colors.white,
                    icon: const Icon(Icons.delete_rounded, size: 18),
                  ),
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
            'Agrega tu primer ingreso o gasto con el botón "Nuevo +".',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

