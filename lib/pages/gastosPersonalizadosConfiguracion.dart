import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_gestion_gastos/api/services.dart';

class CategoriasPage extends StatefulWidget {

  final int idCard;

  CategoriasPage({
    super.key,
    required this.idCard,
  });
  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();

  final ApiService service = ApiService();

  // colores/tema
  final Color primary = const Color(0xFF6C55F9);
  final Color bg = const Color(0xFFF8F3FF);
  final Color border = const Color(0xFFE6E1FF);

  // estado
  bool isGasto = true;             // por defecto GASTO (como en tu app)
  String tipoMovimiento = 'GASTO';

  bool _cargando = false;
  List<Map<String, dynamic>> _categorias = [];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  InputDecoration _input(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Colors.black87),
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

  Future<void> _cargarCategorias() async {
    try {
      setState(() => _cargando = true);
      final res = await service.listarCategoriaPersonalizado(context,widget.idCard); // GET /categorias
      final data = json.decode(res.body) as List;
      _categorias = data
          .map((e) => {
        "id": e["id"],
        "nombre": e["nombre"],
      })
          .toList();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar las categorías')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _crearCategoria() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nombre = _nombreCtrl.text.trim();
    try {
      setState(() => _cargando = true);
      final res = await service.crearCategoria(context,
          {"idCard":widget.idCard.toString(),"nombre": nombre, "tipoMovimiento":tipoMovimiento}); // POST /categorias
      if (res.statusCode == 200 || res.statusCode == 201) {
        // si el backend devuelve la categoría creada:
        final created = json.decode(res.body);
        setState(() {
          _categorias.insert(0, {
            "id": created["id"],
            "nombre": created["nombre"],
          });
        });
        _nombreCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoría creada')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${res.statusCode}')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo crear la categoría')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme);

    final theme = Theme.of(context).copyWith(
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

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Categorías')),
        body: RefreshIndicator(
          onRefresh: _cargarCategorias,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Card de creación (un solo input)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              _cargarCategorias();
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
                              _cargarCategorias();
                            },
                          ),
                        ],
                      ),
                      Text('Nueva categoría',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: _input('Nombre de categoría', icon: Icons.category_rounded),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _crearCategoria(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingresa un nombre'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _cargando ? null : _crearCategoria,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Agregar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Lista
              Row(
                children: [
                  Text('Listado', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (_cargando) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 8),
              if (_categorias.isEmpty && !_cargando)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Aún no hay categorías. ¡Crea la primera!'),
                )
              else
                ..._categorias.map((c) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.label_rounded),
                    title: Text(c['nombre'] ?? ''),
                    // Si luego quieres eliminar/editar:
                    // trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
                  ),
                )),
            ],
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

