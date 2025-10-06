import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:app_gestion_gastos/api/services.dart';

class NuevoCardPersonalizadoPage extends StatefulWidget {
  const NuevoCardPersonalizadoPage({super.key});

  @override
  State<NuevoCardPersonalizadoPage> createState() => _NuevoCardPersonalizadoPageState();
}

class _NuevoCardPersonalizadoPageState extends State<NuevoCardPersonalizadoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: '#6C63FF'); // default

  String? _moneda = 'PEN';

  final ApiService service = ApiService();

  // Tema de tu app
  final Color primary = const Color(0xFF6C55F9);
  final Color bg = const Color(0xFFF8F3FF);
  final Color sheet = Colors.white;
  final Color border = const Color(0xFFE6E1FF);

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  // ===== UI helpers =====
  InputDecoration _input(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
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

  String _normalizeHex(String value) {
    final v = value.trim().toUpperCase();
    final withHash = v.startsWith('#') ? v : '#$v';
    return withHash;
  }

  bool _isValidHex(String value) {
    final hex = _normalizeHex(value);
    return RegExp(r'^#([A-F0-9]{6})$').hasMatch(hex);
  }

  Color _hexToColor(String value) {
    final hex = _normalizeHex(value).substring(1);
    return Color(int.parse('FF$hex', radix: 16));
  }

  Future<void> _pickPresetColor() async {
    final presets = [
      '#6C63FF', '#7C4DFF', '#8B5CF6', '#22C55E',
      '#EF4444', '#F59E0B', '#06B6D4', '#111827'
    ];
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elegir color'),
        content: Wrap(
          spacing: 10, runSpacing: 10,
          children: presets.map((h) {
            return GestureDetector(
              onTap: () { setState(() => _colorCtrl.text = h); Navigator.pop(context); },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _hexToColor(h),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  // ===== Guardar =====
  Future<void> _guardar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final hex = _normalizeHex(_colorCtrl.text);
    if (!_isValidHex(hex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Color inválido. Usa formato #RRGGBB')),
      );
      return;
    }

    final body = {
      'nombre': _nombreCtrl.text.trim(),
      'descripcion': _descCtrl.text.trim(),
      'moneda': _moneda,          // p.ej. 'PEN'
      'colorHex': hex,           // p.ej. '#6C63FF'
    };

    final res = await service.crearCardPersonalizado(context, body);
    if (!mounted) return;

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card personalizado creado')),
      );
      Navigator.pop(context, true); // avisa éxito al caller
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${res.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    final t = Theme.of(context).copyWith(
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
    );

    final size = MediaQuery.of(context).size;
    final sheetHeight = size.height * 0.92;

    return Theme(
      data: t,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bg, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: sheetHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: sheet,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, -10)),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 90),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 48, height: 5,
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE8FF),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('Nuevo card personalizado',
                                        style: t.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // nombre
                                Text('Nombre', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nombreCtrl,
                                  decoration: _input('Ej. Gastos Personalizados', icon: Icons.badge_rounded),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                                ),
                                const SizedBox(height: 14),

                                // descripcion
                                Text('Descripción', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _descCtrl,
                                  maxLines: 3,
                                  decoration: _input('Mi tablero de gastos especiales', icon: Icons.notes_rounded),
                                ),
                                const SizedBox(height: 14),

                                // moneda
                                Text('Moneda', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _moneda,
                                  items: const [
                                    DropdownMenuItem(value: 'PEN', child: Text('PEN - Sol peruano')),
                                    DropdownMenuItem(value: 'USD', child: Text('USD - Dólar')),
                                    DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                                  ],
                                  onChanged: (v) => setState(() => _moneda = v),
                                  decoration: _input('Selecciona moneda', icon: Icons.payments_rounded),
                                  validator: (v) => v == null ? 'Selecciona una moneda' : null,
                                ),
                                const SizedBox(height: 14),

                                // color_hex
                                Text('Color (HEX)', style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _colorCtrl,
                                        decoration: _input('#RRGGBB', icon: Icons.palette_rounded),
                                        onChanged: (_) => setState(() {}),
                                        validator: (v) => (v == null || !_isValidHex(v))
                                            ? 'Usa formato #RRGGBB'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: _pickPresetColor,
                                      child: Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: _isValidHex(_colorCtrl.text)
                                              ? _hexToColor(_colorCtrl.text)
                                              : Colors.grey.shade300,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // botones
                        Positioned(
                          left: 20, right: 20, bottom: 20,
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primary,
                                    side: BorderSide(color: primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    elevation: 0,
                                  ),
                                  child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700)),
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
        ),
      ),
    );
  }
}
