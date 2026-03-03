import 'dart:convert';

import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_gestion_gastos/api/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:intl/intl.dart';

class ProyeccionMensualPage extends StatefulWidget {
  const ProyeccionMensualPage({super.key});

  @override
  State<ProyeccionMensualPage> createState() => _ProyeccionMensualPageState();
}

class _ProyeccionMensualPageState extends State<ProyeccionMensualPage> {
  // Constantes
  static const Color primary = Color(0xFF6C55F9);
  static const Color bg = Color(0xFFF8F3FF);
  static const int maxYearsRange = 7;
  static const int yearOffset = 3;
  static const double minIngreso = 0.0;

  // Servicios
  final ApiService service = ApiService();
  final storage = const FlutterSecureStorage();
  final formatter = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

  // Estado
  int yearActual = DateTime.now().year;
  int mesActual = DateTime.now().month;
  double ingresoMes = 0.0;
  int idUsuario = 0;
  List<Map<String, dynamic>> categorias = [];
  bool isLoading = false;
  bool proyeccionCerrada = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await obtenerDatosDesdeToken();
  }

  Future<void> obtenerDatosDesdeToken() async {
    setState(() => isLoading = true);

    try {
      String? token = await storage.read(key: 'token');

      if (token == null) {
        _mostrarError('No se encontró el token de autenticación');
        return;
      }

      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      setState(() {
        idUsuario = decodedToken['id'] ?? 0;
      });

      if (idUsuario == 0) {
        _mostrarError('ID de usuario inválido');
        return;
      }

      await _cargarDetalleProyeccion(idUsuario, yearActual, mesActual);
      await _cargarCategorias(idUsuario, yearActual, mesActual);
    } catch (e) {
      _mostrarError('Error al obtener datos del usuario: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _insertUpdateProyeccion(
    int idUsuario,
    int anio,
    int mes,
    double ingreso, {
    double? totalGasto,
    double? ahorroEstimado,
  }) async {
    if (proyeccionCerrada) {
      _mostrarError('Esta proyección está cerrada');
      return;
    }

    if (ingreso < minIngreso) {
      _mostrarError(
        'El ingreso debe ser mayor o igual a ${formatter.format(minIngreso)}',
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final double totalGastoFinal =
          totalGasto ??
          categorias.fold(0.0, (sum, cat) => sum + (cat['monto'] as double));
      final double ahorroEstimadoFinal =
          ahorroEstimado ?? (ingreso - totalGastoFinal);

      final res = await service.insertUpdateProyeccion(
        context,
        idUsuario,
        anio,
        mes,
        ingreso,
        totalGastoFinal,
        ahorroEstimadoFinal,
      );

      if (res.statusCode == 200) {
        final resp = jsonDecode(res.body);
        debugPrint('Proyección actualizada: $resp');
        await _cargarDetalleProyeccion(idUsuario, anio, mes);
        await _cargarCategorias(idUsuario, anio, mes);
      } else {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      _mostrarError('Error al actualizar proyección: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _cargarDetalleProyeccion(
    int idUsuario,
    int anio,
    int mes,
  ) async {
    try {
      final res = await service.getObtenerDetalleProyeccion(
        context,
        idUsuario,
        anio,
        mes,
      );

      if (res.statusCode == 200) {
        final resp = jsonDecode(res.body);

        if (resp['response'] != null) {
          setState(() {
            ingresoMes = (resp['response']['ingresoMensual'] ?? 0.0).toDouble();
            proyeccionCerrada = resp['response']['cerrado'] ?? false;
          });
        } else {
          setState(() {
            ingresoMes = 0.0;
            proyeccionCerrada = false;
          });
        }
      } else {
        throw Exception('Error ${res.statusCode}');
      }
    } catch (e) {
      _mostrarError('Error al cargar detalle de proyección: $e');
    }
  }

  Future<void> _cargarCategorias(int idUsuario, int anio, int mes) async {
    setState(() => isLoading = true);

    try {
      final res = await service.getObtenerCategoriasProyeccion(
        context,
        idUsuario,
        anio,
        mes,
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);

        if (decoded is! List) {
          throw Exception('Formato inesperado de respuesta');
        }

        final nuevaLista = decoded.map<Map<String, dynamic>>((raw) {
          final item = (raw is Map)
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};

          return {
            'categoriaId': item['categoriaId'],
            'proyeccionId': item['proyeccionId'],
            'ordenCategoria': item['ordenCategoria'],
            'estado': item['estado'],
            'nombre': (item['nombreCategoria'] ?? '') as String,
            'monto': _toDouble(item['montoCategoria']),
            'totalGasto': _toDouble(item['totalGasto']),
            'ahorroEstimado': _toDouble(item['ahorroEstimado']),
            'ingresoMensual': _toDouble(item['ingresoMensual']),
            'color': _parseHexColor(item['colorCategoria']),
            'mes': item['mes'],
            'anio': item['anio'],
          };
        }).toList();

        if (mounted) {
          setState(() => categorias = nuevaLista);
        }
      } else {
        throw Exception('Error ${res.statusCode}');
      }
    } catch (e) {
      _mostrarError('Error al cargar categorías: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  Color _parseHexColor(dynamic v) {
    try {
      if (v is! String || v.trim().isEmpty) return Colors.grey.shade300;

      final hex = v.trim().replaceAll('#', '').toUpperCase();
      final buffer = StringBuffer();

      if (hex.length == 6) buffer.write('FF');
      buffer.write(hex);

      if (buffer.length != 8) return Colors.grey.shade300;

      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.grey.shade300;
    }
  }

  Future<void> _editarMonto(int index) async {
    if (proyeccionCerrada) {
      _mostrarError('Esta proyección está cerrada');
      return;
    }

    final resultado = await _mostrarDialogMonto(
      titulo: 'Editar ${categorias[index]['nombre']}',
      valorInicial: categorias[index]['monto'],
    );

    if (resultado != null && resultado > 0) {
      final body = {
        "anio": yearActual,
        "nombreCategoria": categorias[index]['nombre'],
        "mes": mesActual,
        "idCategoria": categorias[index]['categoriaId'],
        "montoCategoria": resultado,
        "color": categorias[index]['color'],
      };

      await _guardarCategoriaEnAPI(body);
    }
  }

  Future<void> _crearCategoria() async {
    if (proyeccionCerrada) {
      _mostrarError('Esta proyección está cerrada');
      return;
    }

    final nombreController = TextEditingController();
    final montoController = TextEditingController(text: '0');
    Color colorSeleccionado = Colors.grey.shade300;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Nueva Categoría'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nombre de categoría',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: montoController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: 'S/ ',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'Color:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      final colors = [
                        Colors.grey.shade300,
                        Colors.yellow.shade300,
                        Colors.orange.shade300,
                        Colors.green.shade400,
                        Colors.blue.shade300,
                        Colors.purple.shade300,
                        Colors.red.shade300,
                        Colors.pink.shade300,
                        Colors.teal.shade300,
                      ];

                      await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text('Seleccionar Color'),
                          content: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: colors.map((color) {
                              return GestureDetector(
                                onTap: () {
                                  setStateDialog(
                                    () => colorSeleccionado = color,
                                  );
                                  Navigator.pop(ctx);
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black26,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorSeleccionado,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final nombre = nombreController.text.trim();
                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es requerido')),
                  );
                  return;
                }

                Navigator.pop(context, {
                  'nombre': nombre,
                  'monto': double.tryParse(montoController.text) ?? 0.0,
                  'color': colorSeleccionado,
                });
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await _guardarCategoriaEnAPI(result);
    }
  }

  Future<void> _guardarCategoriaEnAPI(Map<String, dynamic> categoria) async {
    setState(() => isLoading = true);

    try {
      String colorHex =
          '#${categoria['color'].value.toRadixString(16).substring(2).toUpperCase()}';

      final body = {
        'idCategoria': categoria["idCategoria"],
        'nombreCategoria': categoria['nombre'] ?? categoria['nombreCategoria'],
        'montoCategoria': categoria['monto'] ?? categoria["montoCategoria"],
        'colorCategoria': colorHex,
        'anio': yearActual,
        'mes': mesActual,
        'ingresoMensual': ingresoMes,
      };

      final res = await service.guardarProyeccionCategoria(
        context,
        idUsuario,
        body,
      );

      if (res.statusCode == 200) {
        _mostrarExito('Categoría guardada exitosamente');
        await _cargarCategorias(idUsuario, yearActual, mesActual);
      } else {
        throw Exception('Error ${res.statusCode}');
      }
    } catch (e) {
      _mostrarError('Error al guardar la categoría: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _eliminarCategoria(int index) async {
    if (proyeccionCerrada) {
      _mostrarError('Esta proyección está cerrada');
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Deseas eliminar la categoría "${categorias[index]['nombre']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => isLoading = true);

      try {
        // Aquí deberías llamar al servicio de eliminación
        // final res = await service.eliminarCategoria(context, categorias[index]['categoriaId']);

        // Por ahora solo elimino localmente
        setState(() => categorias.removeAt(index));
        _mostrarExito('Categoría eliminada');

        await _cargarCategorias(idUsuario, yearActual, mesActual);
      } catch (e) {
        _mostrarError('Error al eliminar: $e');
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _cerrarProyeccion() async {
    if (proyeccionCerrada) {
      _mostrarError('Esta proyección ya está cerrada');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Proyección'),
        content: const Text(
          '¿Estás seguro de cerrar esta proyección?\n\n'
          'No podrás actualizar ni crear nuevas categorías después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => isLoading = true);

      try {
        // Aquí deberías llamar al servicio para cerrar la proyección
        // final res = await service.cerrarProyeccion(context, idUsuario, yearActual, mesActual);

        setState(() => proyeccionCerrada = true);
        _mostrarExito('Proyección cerrada exitosamente');
      } catch (e) {
        _mostrarError('Error al cerrar proyección: $e');
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<double?> _mostrarDialogMonto({
    required String titulo,
    required double valorInicial,
  }) async {
    final controller = TextEditingController(
      text: valorInicial.toStringAsFixed(2),
    );

    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: 'Monto',
            prefixText: 'S/ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final monto = double.tryParse(controller.text) ?? 0.0;
              Navigator.pop(context, monto);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double total = categorias.fold(
      0.0,
      (sum, cat) => sum + (cat['monto'] as double),
    );
    final double ahorroEstimado = ingresoMes - total;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardPage()),
          ),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Proyección Mensual',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: proyeccionCerrada
          ? null
          : FloatingActionButton.extended(
              backgroundColor: primary,
              onPressed: _crearCategoria,
              icon: const Icon(Icons.add),
              label: const Text('Nueva Categoría'),
            ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (proyeccionCerrada)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Proyección cerrada - No se pueden hacer cambios',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                _HeaderCard(
                  yearActual: yearActual,
                  mesActual: mesActual,
                  ingresoMes: ingresoMes,
                  primary: primary,
                  formatter: formatter,
                  bloqueado: proyeccionCerrada,
                  onYearChanged: (y) {
                    setState(() => yearActual = y);
                    _cargarDetalleProyeccion(idUsuario, yearActual, mesActual);
                    _cargarCategorias(idUsuario, yearActual, mesActual);
                  },
                  onMesChanged: (m) {
                    setState(() => mesActual = m);
                    _cargarDetalleProyeccion(idUsuario, yearActual, m);
                    _cargarCategorias(idUsuario, yearActual, m);
                  },
                  onIngresoChanged: (i) {
                    setState(() => ingresoMes = i);
                    _insertUpdateProyeccion(
                      idUsuario,
                      yearActual,
                      mesActual,
                      ingresoMes,
                    );
                  },
                ),

                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El ingreso debe actualizarse cada mes según corresponda',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Categorías de Gasto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${categorias.length} categorías',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (categorias.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay categorías',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea tu primera categoría de gasto',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...categorias.asMap().entries.map((entry) {
                    final index = entry.key;
                    final cat = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _CategoriaItem(
                        nombre: cat['nombre'],
                        monto: cat['monto'],
                        color: cat['color'],
                        formatter: formatter,
                        onTap: () => _editarMonto(index),
                        onDelete: () => _eliminarCategoria(index),
                      ),
                    );
                  }),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary.withOpacity(0.1), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _ResumenRow('Total Gastos', total, primary, formatter),
                      const Divider(height: 24, thickness: 1),
                      _ResumenRow(
                        'Ahorro Estimado',
                        ahorroEstimado,
                        ahorroEstimado >= 0 ? Colors.green : Colors.red,
                        formatter,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (!proyeccionCerrada)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _cerrarProyeccion,
                      icon: const Icon(Icons.lock),
                      label: const Text(
                        'Cerrar Proyección',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============ WIDGETS DE SOPORTE ============

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.yearActual,
    required this.mesActual,
    required this.ingresoMes,
    required this.primary,
    required this.formatter,
    required this.bloqueado,
    required this.onYearChanged,
    required this.onMesChanged,
    required this.onIngresoChanged,
  });

  final int yearActual;
  final int mesActual;
  final double ingresoMes;
  final Color primary;
  final NumberFormat formatter;
  final bool bloqueado;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMesChanged;
  final ValueChanged<double> onIngresoChanged;

  @override
  Widget build(BuildContext context) {
    final months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final now = DateTime.now().year;
    final years = List<int>.generate(7, (i) => now - 3 + i);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Año:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primary.withOpacity(0.3)),
                ),
                child: DropdownButton<int>(
                  value: yearActual,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Colors.white,
                  items: years.map((y) {
                    return DropdownMenuItem(
                      value: y,
                      child: Text(
                        y.toString(),
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: bloqueado
                      ? null
                      : (v) {
                          if (v != null) onYearChanged(v);
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mes:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: bloqueado ? Colors.grey.shade300 : primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: mesActual,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Colors.white,
                  iconEnabledColor: Colors.white,
                  items: List.generate(12, (i) => i + 1).map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(
                        months[m - 1],
                        style: TextStyle(
                          color: mesActual == m ? Colors.white : primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: bloqueado
                      ? null
                      : (v) {
                          if (v != null) onMesChanged(v);
                        },
                  selectedItemBuilder: (context) {
                    return months.map((month) {
                      return Text(
                        month,
                        style: TextStyle(
                          color: bloqueado
                              ? Colors.grey.shade600
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ingreso Mensual:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              GestureDetector(
                onTap: bloqueado
                    ? null
                    : () async {
                        final controller = TextEditingController(
                          text: ingresoMes.toStringAsFixed(2),
                        );
                        final result = await showDialog<double>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: const Text('Editar Ingreso'),
                            content: TextField(
                              controller: controller,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Ingreso',
                                prefixText: 'S/ ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  final monto =
                                      double.tryParse(controller.text) ?? 0.0;
                                  Navigator.pop(ctx, monto);
                                },
                                child: const Text('Guardar'),
                              ),
                            ],
                          ),
                        );
                        if (result != null) onIngresoChanged(result);
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: bloqueado
                        ? Colors.grey.shade200
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: bloqueado
                          ? Colors.grey.shade400
                          : Colors.green.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        formatter.format(ingresoMes),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: bloqueado
                              ? Colors.grey.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        bloqueado ? Icons.lock : Icons.edit,
                        size: 16,
                        color: bloqueado
                            ? Colors.grey.shade700
                            : Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoriaItem extends StatelessWidget {
  const _CategoriaItem({
    required this.nombre,
    required this.monto,
    required this.color,
    required this.formatter,
    required this.onTap,
    required this.onDelete,
  });

  final String nombre;
  final double monto;
  final Color color;
  final NumberFormat formatter;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(nombre + monto.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Confirmar eliminación'),
            content: Text('¿Deseas eliminar la categoría "$nombre"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                formatter.format(monto),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit, size: 18, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumenRow extends StatelessWidget {
  const _ResumenRow(this.label, this.amount, this.color, this.formatter);

  final String label;
  final double amount;
  final Color color;
  final NumberFormat formatter;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Text(
          formatter.format(amount),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
