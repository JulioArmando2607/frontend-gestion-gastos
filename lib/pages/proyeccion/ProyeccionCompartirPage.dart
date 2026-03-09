import 'dart:convert';

import 'package:app_gestion_gastos/api/proyeccion_compartida_service.dart';
import 'package:app_gestion_gastos/widgets/email_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProyeccionCompartirPage extends StatefulWidget {
  const ProyeccionCompartirPage({
    super.key,
    required this.ownerUserId,
    required this.anio,
    required this.mes,
    required this.idProyeccionSeleccionada,
  });

  final int ownerUserId;
  final int anio;
  final int mes;
  final int idProyeccionSeleccionada;

  @override
  State<ProyeccionCompartirPage> createState() => _ProyeccionCompartirPageState();
}

class _ProyeccionCompartirPageState extends State<ProyeccionCompartirPage> {
  static const int codOk = 1;
  static const int codValidacion = 1001;
  static const int codUsNoEncontrado = 1003;
  static const int codNoEncontrado = 1004;
  static const int codDuplicado = 1005;
  static const int codError = 1999;

  // Ajusta este enlace a tu web real de registro.
  static const String registroWebUrl = 'https://www.cashlyplus.com/';

  static const Color primary = Color(0xFF6C55F9);
  static const Color bg = Color(0xFFF8F3FF);

  final ProyeccionCompartidaService proyeccionCompartidaService = ProyeccionCompartidaService();
  final TextEditingController correoController = TextEditingController();

  bool loading = true;
  bool backendDisponible = true;
  bool enviando = false;
  List<_CompartidoItem> compartidos = [];

  @override
  void initState() {
    super.initState();
    _cargarCompartidos();
  }

  @override
  void dispose() {
    correoController.dispose();
    super.dispose();
  }

  Future<void> _cargarCompartidos() async {
    setState(() => loading = true);
    try {
      final res = await proyeccionCompartidaService.listarProyeccionesEnviadas(
        context,
        ownerUserId: widget.ownerUserId,
      );
      print(res.body);
      if (res.statusCode == 200) {
        final decoded = _tryDecodeMap(res.bodyBytes);
        final codResultado = _toInt(decoded?['codResultado']);
        final response = decoded?['response'];
        final list = <_CompartidoItem>[];
        final filtrados = <_CompartidoItem>[];

        if (codResultado == codOk && response is List) {
          for (final e in response) {
            if (e is! Map) continue;
            final item = _CompartidoItem.fromMap(e);
            list.add(item);
            if (item.idProyeccion == widget.idProyeccionSeleccionada) {
              filtrados.add(item);
            }
          }
        }

        // Si no hay match exacto por id de proyecciÃ³n, mostramos todos los enviados
        // para no dejar vacÃ­a la lista por desalineaciÃ³n de IDs en backend/frontend.
        compartidos = filtrados.isNotEmpty ? filtrados : list;
        backendDisponible = true;
      } else if (res.statusCode == 404 || res.statusCode == 405) {
        backendDisponible = false;
        compartidos = [];
      }
    } catch (_) {
      compartidos = [];
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _compartir() async {
    final correo = correoController.text.trim().toLowerCase();
    final isEmailValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(correo);
    if (!isEmailValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Correo inválido')));
      return;
    }

    setState(() => enviando = true);
    try {
      final res = await proyeccionCompartidaService.compartirProyeccionPorCorreo(
        context,
        ownerUserId: widget.ownerUserId,
        anio: widget.anio,
        mes: widget.mes,
        correo: correo,
        idProyeccionSeleccionada:widget.idProyeccionSeleccionada
      );

      final decoded = _tryDecodeMap(res.bodyBytes);
      final codResultado = decoded?['codResultado'] as int?;
      final msgResultado = (decoded?['msgResultado'] ?? '').toString();

      if (codResultado == codOk ||
          (codResultado == null &&
              (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204))) {
        correoController.clear();
        await _cargarCompartidos();
        if (!mounted) return;
        await _showInfoDialog(
          title: 'Compartido',
          message: msgResultado.isNotEmpty
              ? msgResultado
              : 'Proyección compartida correctamente.',
        );
      } else if (codResultado == codUsNoEncontrado) {
        if (!mounted) return;
        await _showUsuarioNoEncontradoDialog();
      } else if (codResultado == codDuplicado ||
          codResultado == codValidacion ||
          codResultado == codNoEncontrado ||
          codResultado == codError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msgResultado.isNotEmpty
                  ? msgResultado
                  : 'No se pudo compartir (código $codResultado).',
            ),
          ),
        );
      } else if (res.statusCode == 404 || res.statusCode == 405) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend de compartir aún no disponible')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo compartir (${res.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al compartir')));
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  Map<String, dynamic>? _tryDecodeMap(List<int> bodyBytes) {
    try {
      final raw = utf8.decode(bodyBytes);
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse('$value');
  }

  Future<void> _showInfoDialog({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showUsuarioNoEncontradoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Usuario no registrado'),
        content: const Text(
          'Ese correo aún no está registrado. Puedes compartirle el enlace web para que se registre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: registroWebUrl),
              );
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enlace de registro copiado al portapapeles'),
                ),
              );
            },
            icon: const Icon(Icons.link_rounded),
            label: const Text('Copiar enlace'),
          ),
        ],
      ),
    );
  }

  Future<void> _revocar(String correo) async {
    try {
      final res = await proyeccionCompartidaService.revocarCompartidoPorCorreo(
        context,
        ownerUserId: widget.ownerUserId,
        anio: widget.anio,
        mes: widget.mes,
        correo: correo,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        await _cargarCompartidos();
      } else if (res.statusCode == 404 || res.statusCode == 405) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backend de revocar aún no disponible')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo revocar (${res.statusCode})')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al revocar acceso')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Compartir proyección',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primary.withValues(alpha: .2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Compartir por correo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      EmailAutocompleteField(
                        controller: correoController,
                        decoration: InputDecoration(
                          hintText: 'correo@ejemplo.com',
                          filled: true,
                          fillColor: const Color(0xFFF7F4FF),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: enviando ? null : _compartir,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: enviando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: const Text('Compartir'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Personas con acceso',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (!backendDisponible)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'El backend para compartir aún no está habilitado.',
                      ),
                    ),
                  )
                else if (compartidos.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Aún no compartiste esta proyección.'),
                    ),
                  )
                else
                  ...compartidos.map(
                    (p) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        title: Text(
                          p.nombre.isNotEmpty ? p.nombre : p.correo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${p.correo}\n${_formatFechaCompartido(p.fechaCompartido)}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Revocar acceso',
                          onPressed: () => _revocar(p.correo),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

String _formatFechaCompartido(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}

class _CompartidoItem {
  const _CompartidoItem({
    required this.idProyeccion,
    required this.idCompartir,
    required this.nombre,
    required this.correo,
    required this.fechaCompartido,
  });

  final int idProyeccion;
  final int idCompartir;
  final String nombre;
  final String correo;
  final String fechaCompartido;

  factory _CompartidoItem.fromMap(Map<dynamic, dynamic> map) {
    int toInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return _CompartidoItem(
      idProyeccion: toInt(map['idProyeccion']),
      idCompartir: toInt(map['idCompartir']),
      nombre: (map['nombrePersonaCompartida'] ?? '').toString(),
      correo: (map['correoPersonaCompartida'] ?? '').toString(),
      fechaCompartido: (map['fechaCompartido'] ?? '').toString(),
    );
  }
}




