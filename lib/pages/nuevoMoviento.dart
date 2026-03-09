import 'dart:convert';
import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/Categoria.dart';
import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class NuevoMovimientoPage extends StatefulWidget {
  const NuevoMovimientoPage({super.key});

  @override
  State<NuevoMovimientoPage> createState() => _NuevoMovimientoPageState();
}

class _NuevoMovimientoPageState extends State<NuevoMovimientoPage> {
  // estado
  bool isGasto = true;             // por defecto GASTO (como en tu app)
  String tipoMovimiento = 'GASTO';
  DateTime selectedDate = DateTime.now();

  List<Categoria> categorias = [];
  Categoria? selectedCategoria;

  final storage = const AppStorage();
  final ApiService service = ApiService();

  String nombre = '';
  int idUsuario = 0;
  String email = '';

  final _formKey = GlobalKey<FormState>();
  final TextEditingController montoController = TextEditingController();
  final TextEditingController descripcionController = TextEditingController();
  final TextEditingController fechaController = TextEditingController();

  // colores de tu tema
  final Color primary = const Color(0xFF6C55F9);
  final Color bg = const Color(0xFFF8F3FF);
  final Color sheet = Colors.white;
  final Color border = const Color(0xFFE6E1FF);

  @override
  void initState() {
    super.initState();
    _sincronizarFecha();
    _cargarCategorias(tipoMovimiento);
  }

  @override
  void dispose() {
    montoController.dispose();
    descripcionController.dispose();
    fechaController.dispose();
    super.dispose();
  }

  String _formatearFecha(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  void _sincronizarFecha() {
    fechaController.text = _formatearFecha(selectedDate);
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
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
      setState(() {
        selectedDate = picked;
        _sincronizarFecha();
      });
    }
  }

  Future<void> _cargarCategorias(String tipo) async {
    final res = await service.obtenerTipoCategoria(context, tipo);
    if (res.statusCode == 200) {
      final list = (jsonDecode(res.body) as List)
          .map((e) => Categoria.fromJson(e))
          .toList();
      setState(() {
        categorias = list;
        selectedCategoria = categorias.isNotEmpty ? categorias.first : null;
      });
    }
  }

  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final token = await storage.read(key: 'token');
    if (token == null || selectedCategoria == null) return;
    if (!mounted) return;

    final decoded = JwtDecoder.decode(token);
    idUsuario = decoded['id'];
    nombre = decoded['nombre'];
    email  = decoded['sub'];

    final movimiento = {
      "tipo": tipoMovimiento,
      "monto": double.tryParse(montoController.text) ?? 0.0,
      "descripcion": descripcionController.text.trim(),
      "fecha": selectedDate.toIso8601String().split('T')[0],
      "usuario": {"id": idUsuario},
      "categoria": {"id": selectedCategoria!.id},
    };

    final res = await service.movimientos(context, movimiento);
    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimiento registrado con éxito')),
      );
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
    final media = MediaQuery.of(context);

    final t = Theme.of(context).copyWith(
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
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
    );

    final size = media.size;
    final sheetHeight = size.height * 0.92;

    return Theme(
      data: t,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
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
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
                    ],
                  ),
                );
                if (confirm == true) {
                  await storage.deleteAll();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bg, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: 0.92,
              child: Container(
                height: sheetHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: sheet,
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
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
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                                        'Nuevo movimiento',
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
                                      bgActive: primary.withValues(alpha: .12),
                                      fgActive: primary,
                                      onTap: () {
                                        setState(() {
                                          isGasto = true;
                                          tipoMovimiento = 'GASTO';
                                        });
                                        _cargarCategorias('GASTO');
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    _SegmentChip(
                                      label: 'Ingreso',
                                      icon: Icons.call_received_rounded,
                                      active: !isGasto,
                                      bgActive: primary.withValues(alpha: .12),
                                      fgActive: primary,
                                      onTap: () {
                                        setState(() {
                                          isGasto = false;
                                          tipoMovimiento = 'INGRESO';
                                        });
                                        _cargarCategorias('INGRESO');
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
                                  decoration: _lightInput(
                                    'S/ 0.00',
                                    prefixIcon: Icons.attach_money_rounded,
                                  ),
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
                                DropdownButtonFormField<Categoria>(
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
                                  controller: fechaController,
                                  decoration: _lightInput(
                                    'Selecciona la fecha',
                                    prefixIcon: Icons.event_rounded,
                                  ).copyWith(
                                    suffixIcon: const Icon(
                                      Icons.expand_more_rounded,
                                    ),
                                  ),
                                  onTap: _seleccionarFecha,
                                ),
                                const SizedBox(height: 14),

                                // Nota
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
                      ),

                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          12,
                          20,
                          20 + media.padding.bottom,
                        ),
                        decoration: BoxDecoration(
                          color: sheet,
                          border: Border(
                            top: BorderSide(color: border.withValues(alpha: .7)),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12000000),
                              blurRadius: 10,
                              offset: Offset(0, -2),
                            ),
                          ],
                        ),
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
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
          ),
        ),
      ),
    );
  }
}

// chip de segmento en tema claro
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
              Text(label,
                  style:
                  TextStyle(color: fg, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}


