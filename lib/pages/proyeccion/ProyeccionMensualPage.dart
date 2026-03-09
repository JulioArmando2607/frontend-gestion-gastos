import 'dart:convert';

import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:app_gestion_gastos/pages/proyeccion/ProyeccionCompartirPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_gestion_gastos/api/proyeccion_compartida_service.dart';
import 'package:app_gestion_gastos/api/proyeccion_service.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:intl/intl.dart';

class ProyeccionMensualPage extends StatefulWidget {
  const ProyeccionMensualPage({
    super.key,
    this.ownerUserId,
    this.sharedProyeccionId,
    this.initialYear,
    this.initialMonth,
    this.readOnly = false,
    this.pageTitle,
  });

  final int? ownerUserId;
  final int? sharedProyeccionId;
  final int? initialYear;
  final int? initialMonth;
  final bool readOnly;
  final String? pageTitle;

  @override
  State<ProyeccionMensualPage> createState() => _ProyeccionMensualPageState();
}

class _ProyeccionMensualPageState extends State<ProyeccionMensualPage> {
  // Constantes
  static const Color primary = Color(0xFF6C55F9);
  static const Color bg = Color(0xFFF8F3FF);
  static const double minIngreso = 0.0;

  // Servicios
  final ProyeccionService proyeccionService = ProyeccionService();
  final ProyeccionCompartidaService proyeccionCompartidaService =
      ProyeccionCompartidaService();
  final storage = const AppStorage();
  final formatter = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

  // Estado
  int yearActual = DateTime.now().year;
  int mesActual = DateTime.now().month;
  double ingresoMes = 0.0;
  double? totalGastosCabecera;
  double? ahorroEstimadoCabecera;
  int idUsuario = 0;
  int usuarioIdAccion = 0;
  List<Map<String, dynamic>> categorias = [];
  bool isLoading = false;
  bool proyeccionCerrada = false;

  var idProyeccionSeleccionada=0;
  bool get _isReadOnlyMode => proyeccionCerrada;
  String get _readOnlyMessage => 'Esta proyección está cerrada';

  @override
  void initState() {
    super.initState();
    if (widget.initialYear != null) {
      yearActual = widget.initialYear!;
    }
    if (widget.initialMonth != null) {
      mesActual = widget.initialMonth!;
    }
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
      final dynamic tokenId = decodedToken['id'];
      final int usuarioToken = tokenId is num
          ? tokenId.toInt()
          : int.tryParse(tokenId?.toString() ?? '') ?? 0;

      setState(() {
        usuarioIdAccion = usuarioToken;
        idUsuario = widget.ownerUserId ?? usuarioToken;
      });

      if (idUsuario == 0 || usuarioIdAccion == 0) {
        _mostrarError('ID de usuario inválido');
        return;
      }

      final sharedId = widget.sharedProyeccionId ?? 0;
      if (widget.readOnly && sharedId > 0) {
        await _cargarDetalleProyeccionCompartida(sharedId);
        await _cargarCategoriasCompartidas(sharedId);
      } else {
        await _cargarDetalleProyeccion(idUsuario, yearActual, mesActual);
        await _cargarCategorias(idUsuario, yearActual, mesActual);
      }
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
    if (_isReadOnlyMode) {
      _mostrarError(_readOnlyMessage);
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

      final res = await proyeccionService.insertUpdateProyeccion(
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
    proyeccionCerrada = false;
    idProyeccionSeleccionada= 0;
    try {
      final res = await proyeccionService.getObtenerDetalleProyeccion(
        context,
        idUsuario,
        anio,
        mes,
      );
      print(res.body);
      if (res.statusCode == 200) {
        final resp = jsonDecode(res.body);

        if (resp['response'] != null) {
          setState(() {
            ingresoMes = (resp['response']['ingresoMensual'] ?? 0.0).toDouble();
            totalGastosCabecera = _toDouble(resp['response']['totalGasto']);
            ahorroEstimadoCabecera = _toDouble(resp['response']['ahorroEstimado']);
            proyeccionCerrada = resp['response']['estado']=='CERRADA' ? true : false;
            idProyeccionSeleccionada = resp['response']['id'];
          });
        } else {
          setState(() {
            ingresoMes = 0.0;
            totalGastosCabecera = null;
            ahorroEstimadoCabecera = null;
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


  Future<void> _cargarDetalleProyeccionCompartida(int idProyeccion) async {
    idProyeccionSeleccionada = 0;
    try {
      final res = await proyeccionCompartidaService.getVerProyeccionCompartida(context, idProyeccion);
      if (res.statusCode == 200) {
        final resp = jsonDecode(res.body);
        final response = resp['response'];
        if (response is Map) {
          setState(() {
            ingresoMes = _toDouble(response['ingresoMensual']);
            totalGastosCabecera = _toDouble(response['totalGastos']);
            ahorroEstimadoCabecera = _toDouble(response['ahorroEstimado']);
            yearActual = _toInt(response['anio']) == 0
                ? yearActual
                : _toInt(response['anio']);
            mesActual = _toInt(response['mes']) == 0
                ? mesActual
                : _toInt(response['mes']);
            proyeccionCerrada =
                (response['estado']?.toString().toUpperCase() ?? '') == 'CERRADA';
            idProyeccionSeleccionada = _toInt(response['id']) == 0
                ? idProyeccion
                : _toInt(response['id']);
          });
        }
      } else {
        throw Exception('Error ${res.statusCode}');
      }
    } catch (e) {
      _mostrarError('Error al cargar cabecera compartida: $e');
    }
  }
  Future<void> _cargarCategorias(int idUsuario, int anio, int mes) async {
    setState(() => isLoading = true);

    try {
      final res = await proyeccionService.getObtenerCategoriasProyeccion(
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


  Future<void> _cargarCategoriasCompartidas(int idProyeccion) async {
    setState(() => isLoading = true);

    try {
      final res = await proyeccionCompartidaService.getDetalleProyeccionCompartida(context, idProyeccion);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final rawList = _extraerListaDetalleCompartido(decoded);

        if (rawList.isEmpty) {
          if (mounted) setState(() => categorias = []);
          return;
        }

        final nuevaLista = rawList.map<Map<String, dynamic>>((raw) {
          final item = (raw is Map)
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};

          return {
            'categoriaId': item['categoriaId'] ?? item['idCategoria'],
            'proyeccionId': item['proyeccionId'] ?? idProyeccion,
            'ordenCategoria': item['ordenCategoria'],
            'estado': item['estado'],
            'nombre': (item['nombreCategoria'] ??
                    item['categoriaNombre'] ??
                    item['nombre'] ??
                    item['descripcion'] ??
                    '')
                .toString(),
            'monto': _toDouble(
              item['montoCategoria'] ??
                  item['montoProyectado'] ??
                  item['monto'] ??
                  item['montoGasto'] ??
                  item['montoPlanificado'] ??
                  item['valor'],
            ),
            'totalGasto': _toDouble(item['totalGasto'] ?? item['totalGastos']),
            'ahorroEstimado': _toDouble(item['ahorroEstimado']),
            'ingresoMensual': _toDouble(item['ingresoMensual']),
            'color': _parseHexColor(item['colorCategoria'] ?? item['color']),
            'mes': item['mes'] ?? mesActual,
            'anio': item['anio'] ?? yearActual,
          };
        }).toList();

        if (mounted) {
          setState(() => categorias = nuevaLista);
        }
      } else {
        throw Exception('Error ${res.statusCode}');
      }
    } catch (e) {
      _mostrarError('Error al cargar detalle compartido: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<dynamic> _extraerListaDetalleCompartido(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is! Map) return const [];

    final response = decoded['response'];
    if (response is List) return response;
    if (response is Map) {
      for (final key in const [
        'detalle',
        'detalles',
        'categorias',
        'items',
        'lista',
        'response',
      ]) {
        final value = response[key];
        if (value is List) return value;
      }
    }

    for (final key in const ['detalle', 'detalles', 'categorias', 'items', 'lista']) {
      final value = decoded[key];
      if (value is List) return value;
    }

    return const [];
  }
  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
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
    if (_isReadOnlyMode) {
      _mostrarError(_readOnlyMessage);
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

      await _editarMontoCategoriaEnAPI(body);
    }
  }

  Future<void> _editarMontoCategoriaEnAPI(Map<String, dynamic> categoria) async {
    setState(() => isLoading = true);
    try {
      final bool esProyeccionCompartida =
          widget.readOnly && (widget.sharedProyeccionId ?? 0) > 0;

      final colorValue = categoria['color'];
      final String colorHex = colorValue is Color
          ? '#${colorValue.value.toRadixString(16).substring(2).toUpperCase()}'
          : (categoria['colorCategoria']?.toString() ?? '#E0E0E0');
      final montoCategoria = _toDouble(
        categoria['monto'] ?? categoria['montoCategoria'],
      );
      final idCategoria = _toInt(categoria['idCategoria'] ?? categoria['categoriaId']);

      final res = esProyeccionCompartida
          ? await proyeccionCompartidaService.editarMontoCategoriaCompartida(
              context,
              usuarioIdAccion: usuarioIdAccion,
              idProyeccion: idProyeccionSeleccionada > 0
                  ? idProyeccionSeleccionada
                  : (widget.sharedProyeccionId ?? 0),
              idCategoria: idCategoria,
              montoCategoria: montoCategoria,
            )
          : await proyeccionService.editarMontoCategoriaProyeccion(
              context,
              idUsuario,
              {
                'idCategoria': idCategoria,
                'nombreCategoria':
                    categoria['nombre'] ?? categoria['nombreCategoria'],
                'montoCategoria': montoCategoria,
                'colorCategoria': colorHex,
                'anio': yearActual,
                'mes': mesActual,
                'ingresoMensual': ingresoMes,
              },
            );

      if (res.statusCode == 200) {
        _mostrarExito('Monto actualizado exitosamente');
        if (esProyeccionCompartida) {
          final sharedId = idProyeccionSeleccionada > 0
              ? idProyeccionSeleccionada
              : (widget.sharedProyeccionId ?? 0);
          await _cargarDetalleProyeccionCompartida(sharedId);
          await _cargarCategoriasCompartidas(sharedId);
        } else {
          await _cargarCategorias(idUsuario, yearActual, mesActual);
        }
      } else {
        throw Exception('Error ${res.statusCode}');
      }
    } catch (e) {
      _mostrarError('Error al actualizar monto: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _crearCategoria() async {
    if (widget.readOnly || _isReadOnlyMode) {
      _mostrarError(_readOnlyMessage);
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
          title: const Text('Nueva Categoria'),
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

      final res = await proyeccionService.guardarProyeccionCategoria(
        context,
        idUsuario,
        body,
      );

      if (res.statusCode == 200) {
        _mostrarExito('Categoria guardada exitosamente');
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
    if (_isReadOnlyMode) {
      _mostrarError(_readOnlyMessage);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmar eliminacion'),
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
        // AquÃ­ deberÃ­as llamar al servicio de eliminaciÃ³n
        // final res = await service.eliminarCategoria(context, categorias[index]['categoriaId']);

        // Por ahora solo elimino localmente
        setState(() => categorias.removeAt(index));
        _mostrarExito('Categoria eliminada');

        await _cargarCategorias(idUsuario, yearActual, mesActual);
      } catch (e) {
        _mostrarError('Error al eliminar: $e');
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _cerrarProyeccion() async {
    if (_isReadOnlyMode) {
      _mostrarError(_readOnlyMessage);
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
        // AquÃ­ deberÃ­as llamar al servicio para cerrar la proyecciÃ³n
        final res = await proyeccionService.cerrarProyeccion(
          context,
          idUsuario,
          yearActual,
          mesActual,
        );
        final decoded = _tryDecodeMap(res.bodyBytes);
        final codResultado = decoded?['codResultado'] as int?;
        final msgResultado = (decoded?['msgResultado'] ?? '').toString();

        if (res.statusCode == 200 && codResultado == 1) {
          setState(() => proyeccionCerrada = true);
          _mostrarExito(
            msgResultado.isNotEmpty ? msgResultado : 'Proyección cerrada',
          );
        } else {
          _mostrarError(
            msgResultado.isNotEmpty
                ? msgResultado
                : 'No se pudo cerrar la proyección (${res.statusCode})',
          );
        }
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
    final double totalCalculado = categorias.fold(
      0.0,
      (sum, cat) => sum + (cat['monto'] as double),
    );
    final bool usarCabeceraCompartida =
        widget.readOnly && (widget.sharedProyeccionId ?? 0) > 0;
    final double total = usarCabeceraCompartida && totalGastosCabecera != null
        ? totalGastosCabecera!
        : totalCalculado;
    final double ahorroEstimado =
        usarCabeceraCompartida && ahorroEstimadoCabecera != null
        ? ahorroEstimadoCabecera!
        : (ingresoMes - total);

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
        title: Text(
          widget.pageTitle ?? 'Proyección Mensual',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!widget.readOnly)
            if(idProyeccionSeleccionada != 0)
            IconButton(
              tooltip: 'Compartir',
              onPressed: () {
                if (idUsuario <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Aún no se pudo identificar la proyección'),
                    ),
                  );
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProyeccionCompartirPage(
                      idProyeccionSeleccionada: idProyeccionSeleccionada,
                      ownerUserId: idUsuario,
                      anio: yearActual,
                      mes: mesActual,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded),
            ),
        ],
      ),
      floatingActionButton: (widget.readOnly || _isReadOnlyMode)
          ? null
          : FloatingActionButton.extended(
              backgroundColor: primary,
              onPressed: _crearCategoria,
              icon: const Icon(Icons.add),
              label: const Text('Nueva Categoria'),
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
                  bloquearAnio: widget.readOnly,
                  bloquearMes: widget.readOnly,
                  bloquearIngreso: widget.readOnly || _isReadOnlyMode,
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
                          'El ingreso debe actualizarse cada mes segun corresponda',
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

                if (!_isReadOnlyMode)
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


  Map<String, dynamic>? _tryDecodeMap(List<int> bodyBytes) {
    try {
      final raw = utf8.decode(bodyBytes);
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }}

// ============ WIDGETS DE SOPORTE ============

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.yearActual,
    required this.mesActual,
    required this.ingresoMes,
    required this.primary,
    required this.formatter,
    required this.bloquearAnio,
    required this.bloquearMes,
    required this.bloquearIngreso,
    required this.onYearChanged,
    required this.onMesChanged,
    required this.onIngresoChanged,
  });

  final int yearActual;
  final int mesActual;
  final double ingresoMes;
  final Color primary;
  final NumberFormat formatter;
  final bool bloquearAnio;
  final bool bloquearMes;
  final bool bloquearIngreso;
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
                  onChanged: bloquearAnio
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
                  color: bloquearMes ? Colors.grey.shade300 : primary,
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
                  onChanged: bloquearMes
                      ? null
                      : (v) {
                          if (v != null) onMesChanged(v);
                        },
                  selectedItemBuilder: (context) {
                    return months.map((month) {
                      return Text(
                        month,
                        style: TextStyle(
                          color: bloquearMes
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
                onTap: bloquearIngreso
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
                    color: bloquearIngreso
                        ? Colors.grey.shade200
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: bloquearIngreso
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
                          color: bloquearIngreso
                              ? Colors.grey.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        bloquearIngreso ? Icons.lock : Icons.edit,
                        size: 16,
                        color: bloquearIngreso
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
            title: const Text('Confirmar eliminacion'),
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










