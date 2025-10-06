import 'dart:convert';
import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/CategoriaPersonalizado.dart';
import 'package:app_gestion_gastos/utils/ui_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:intl/intl.dart';

class GastoPersonalizadoRegMovimientoWidget extends StatefulWidget {
  final int idCard;
  final int idMovimiento;

  const GastoPersonalizadoRegMovimientoWidget({
    super.key,
    required this.idCard,
    required this.idMovimiento,
  });
  @override
  State<GastoPersonalizadoRegMovimientoWidget> createState() =>
      _GastoPersonalizadoRegMovimientoWidgetState();
}

class _GastoPersonalizadoRegMovimientoWidgetState
    extends State<GastoPersonalizadoRegMovimientoWidget> {
  // estado
  bool isGasto = true; // por defecto GASTO (como en tu app)
  String tipoMovimiento = 'GASTO';
  DateTime selectedDate = DateTime.now();

  List<CategoriaPersonalizado> categorias = [];
  CategoriaPersonalizado? selectedCategoria;

  final storage = const FlutterSecureStorage();
  final ApiService service = ApiService();

  String nombre = '';
  int idUsuario = 0;
  String email = '';
  int? idCategoriaSeleccionada;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController montoController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();

  // colores de tu tema
  final Color primary = const Color(0xFF6C55F9);
  final Color bg = const Color(0xFFF8F3FF);
  final Color sheet = Colors.white;
  final Color border = const Color(0xFFE6E1FF);

  @override
  void initState() {
    super.initState();
    // Esperar a que el widget se haya montado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarEdit(widget.idMovimiento);
      _cargarCategorias(widget.idCard, tipoMovimiento);
    });
  }

  @override
  void dispose() {
    montoController.dispose();
    descripcionController.dispose();
    super.dispose();
  }

  Future<void> _cargarEdit(int idMovimiento) async {
    if (idMovimiento > 0) {
      showLoadingDialog(context, message: 'Cargando...');
      try {
        final res = await service.obtenerMovimientoPersonalizado(
          context,
          idMovimiento,
        );
        print(res.body);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body); // 👈 Decodificar JSON

          // Acceder a los campos directamente
          final tipo = data['tipo']; // "INGRESO"
          final monto = data['monto']; // 1200.00
          final fecha = data['fecha']; // "2025-10-05"
          final nota = data['nota']; // "Mes setiembre"
          final categoria = data['categoria']; // "Pago mes"
          final idCategoria = data['idCategoria']; // "Pago mes"

          print(
            'Tipo: $tipo, Monto: $monto, Fecha: $fecha, Nota: $nota, Categoría: $categoria, idCategoria: $idCategoria',
          );

          // Aquí puedes asignarlos a tus variables locales si deseas llenar el formulario
          setState(() {
            tipoMovimiento = tipo.toString(); // Por ejemplo
            montoController.text = monto.toString();
            descripcionController.text = nota ?? '';
            selectedDate = DateTime.parse(fecha);
            isGasto = tipo == 'GASTO' ? true : false;
            idCategoriaSeleccionada = idCategoria; // 👈 guardar ID
          });
          _cargarCategorias(widget.idCard, tipoMovimiento);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar movimiento')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
      } finally {
        Navigator.pop(context); // 🔐 Cerrar loader
      }
    }
  }

  Future<void> _cargarCategorias(int idCard, String tipo) async {
    showLoadingDialog(context, message: 'Cargando...');
    try {
      final res = await service.obtenerCategoriaPersonalizadoxTipo(
        context,
        idCard,
        tipo,
      );

      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => CategoriaPersonalizado.fromJson(e))
            .toList();

        CategoriaPersonalizado? categoriaSeleccionada;
        try {
          categoriaSeleccionada = list.firstWhere(
            (c) => c.id == idCategoriaSeleccionada,
          );
        } catch (_) {
          categoriaSeleccionada = list.isNotEmpty ? list.first : null;
        }

        setState(() {
          categorias = list;
          selectedCategoria = categoriaSeleccionada;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cargar categorías')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
    } finally {
      Navigator.pop(context); // 🔐 Cerrar loader
    }
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = await storage.read(key: 'token');
    if (token == null || selectedCategoria == null) return;

    final decoded = JwtDecoder.decode(token);
    idUsuario = decoded['id'];
    nombre = decoded['nombre'];
    email = decoded['sub'];

    final movimiento = {
      "idMovimiento": widget.idMovimiento,
      "idCard": widget.idCard,
      "tipo": tipoMovimiento,
      "monto": double.tryParse(montoController.text) ?? 0.0,
      "descripcion": descripcionController.text.trim(),
      "fecha": selectedDate.toIso8601String().split('T')[0],
      "usuario": idUsuario,
      "categoria": selectedCategoria!.id,
    };

    final res = await service.nuevoGasto(context, movimiento);
    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      Navigator.pop(context, true);
    } else {
      debugPrint('Error registrar: ${res.statusCode}');
      debugPrint('Body: ${res.body}');
    }
  }

  // UI helpers
  InputDecoration _lightInput(String label, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Colors.black87),
      hintStyle: const TextStyle(color: Colors.black45),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    final t = Theme.of(context).copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );

    final size = MediaQuery.of(context).size;
    final sheetHeight = size.height * 0.92;

    return Theme(
      data: t,
      child: Stack(
        children: [
          // panel flotante claro
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: sheetHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: sheet,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 24,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Stack(
                  children: [
                    // contenido scroll
                    SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 12,
                        bottom: 90, // espacio para el botón fijo
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // handle
                            Center(
                              child: Container(
                                width: 48,
                                height: 5,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE8FF),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                            ),
                            // header
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Nuevo gasto',
                                    style: t.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Segmentos: Gasto / Ingreso (en tu tema)
                            Row(
                              children: [
                                _SegmentChip(
                                  label: 'Gasto',
                                  icon: Icons.call_made_rounded,
                                  active: isGasto,
                                  bgActive: primary.withOpacity(.12),
                                  fgActive: primary,
                                  onTap: () {
                                    setState(() {
                                      isGasto = true;
                                      tipoMovimiento = 'GASTO';
                                    });
                                    _cargarCategorias(
                                      widget.idCard,
                                      tipoMovimiento,
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                _SegmentChip(
                                  label: 'Ingreso',
                                  icon: Icons.call_received_rounded,
                                  active: !isGasto,
                                  bgActive: primary.withOpacity(.12),
                                  fgActive: primary,
                                  onTap: () {
                                    setState(() {
                                      isGasto = false;
                                      tipoMovimiento = 'INGRESO';
                                    });
                                    _cargarCategorias(
                                      widget.idCard,
                                      tipoMovimiento,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Monto
                            Text(
                              'Monto',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: montoController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _lightInput('S/ 0.00'),
                              validator: (v) {
                                final d = double.tryParse(
                                  (v ?? '').replaceAll(',', '.'),
                                );
                                if (d == null || d <= 0) {
                                  return 'Ingresa un monto válido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Categoría
                            Text(
                              'Categoría',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<CategoriaPersonalizado>(
                              initialValue: selectedCategoria,
                              items: categorias
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.nombre),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => selectedCategoria = v),
                              decoration: _lightInput(
                                'Selecciona una categoría',
                                prefixIcon: Icons.category_rounded,
                              ),
                              validator: (v) =>
                                  v == null ? 'Selecciona una categoría' : null,
                            ),
                            const SizedBox(height: 14),

                            // Fecha
                            Text(
                              'Fecha',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              readOnly: true,
                              controller: TextEditingController(
                                text: DateFormat(
                                  'dd/MM/yyyy',
                                ).format(selectedDate),
                              ),
                              decoration:
                                  _lightInput(
                                    'Selecciona la fecha',
                                    prefixIcon: Icons.event_rounded,
                                  ).copyWith(
                                    suffixIcon: const Icon(
                                      Icons.expand_more_rounded,
                                    ),
                                  ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (_, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: primary,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() => selectedDate = picked);
                                }
                              },
                            ),
                            const SizedBox(height: 14),

                            Text(
                              'Nota (opcional)',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: descripcionController,
                              maxLines: 3,
                              decoration: _lightInput(
                                'Añade una nota…',
                                prefixIcon: Icons.notes_rounded,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // botón fijo inferior
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                side: BorderSide(color: primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _guardar,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Guardar',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.bgActive,
    required this.fgActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color bgActive;
  final Color fgActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? bgActive : const Color(0xFFF2EEFF);
    final fg = active ? fgActive : Colors.black87;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6E1FF)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
