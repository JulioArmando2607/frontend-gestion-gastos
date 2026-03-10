import 'dart:convert';
import 'dart:math' as math;
import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/pages/editarCuenta.dart';
import 'package:app_gestion_gastos/pages/gastosDiarios.dart';
import 'package:app_gestion_gastos/pages/gastosPersonalizados/gastosPersonalizados.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:app_gestion_gastos/pages/proyeccion/ProyeccionesPage.dart';
import 'package:flutter/material.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final primary = const Color(0xFF6C55F9);
  final bg = const Color(0xFFF8F3FF);
  final storage = AppStorage();
  String nombre = '';
  final ApiService service = ApiService();
  int idUsuario = 0;

  late int _year;
  int _month = DateTime.now().month;

  // Demo: trae tus datos reales según (year, month)
  double gastoMes = 0;
  double proyeccionMes = 0;
  double avance = 0.2;

  bool mostrarBtnProyeccion = false; // 20% solo de ejemplo

  @override
  void initState() {
    super.initState();
    obtenerDatosDesdeToken();
    _year = DateTime.now().year;
    _fetchData();
    _validarBotones();
  }

  void _onPickMonth(int m) {
    setState(() => _month = m);
    _fetchData();
  }

  void _onPickYear(int y) {
    setState(() => _year = y);
    _fetchData();
  }

  void _fetchData() async {
    try {
      // Assuming `service` provides the method to fetch data from API
      final response = await service.getDashboardData(
        context,
        _year,
        _month,
      ); // Adjust the service method as needed

      if (response.statusCode == 200) {
        print(response.body);
        final List<dynamic> data = jsonDecode(response.body);

        // Process and update dashboard data
        double totalGasto = 0;
        double totalProyeccion = 0;
        if (data.isNotEmpty) {
          for (var item in data) {
            totalGasto += item['gastoTotal'] ?? 0;
            totalProyeccion +=
                item['ingresoTotal'] ?? 0; // If you have this field
          }

          final ratio = totalProyeccion > 0
              ? (totalGasto / totalProyeccion)
              : 0.0;
          setState(() {
            gastoMes = totalGasto;
            proyeccionMes = totalProyeccion;
            avance = ratio.isFinite ? ratio : 0.0;
          });
        } else {
          setState(() {
            gastoMes = 0;
            proyeccionMes = 0;
            avance = 0; // Update this formula as needed
          });
        }
      }
    } catch (error) {
      print("Error fetching data: $error");
      // Handle the error
    }
  }

  Future<void> obtenerDatosDesdeToken() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null || JwtDecoder.isExpired(token)) return;

      final decodedToken = JwtDecoder.decode(token);
      final tokenNombre = (decodedToken['nombre'] ?? '').toString();
      final tokenId = decodedToken['id'];
      final parsedId = tokenId is int ? tokenId : int.tryParse('$tokenId') ?? 0;

      if (!mounted) return;
      setState(() {
        nombre = tokenNombre;
        idUsuario = parsedId;
      });

      if (parsedId > 0) {
        await getUsuario(parsedId.toString());
      }
    } catch (e) {
      debugPrint('Error en obtenerDatosDesdeToken: $e');
    }
  }

  Future<void> getUsuario(String id) async {
    try {
      final response = await service.usuario(context, id);
      if (response.statusCode != 200) return;

      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      final nombreApi = (data['nombre'] as String? ?? '').trim();

      if (!mounted || nombreApi.isEmpty) return;
      setState(() {
        nombre = nombreApi;
      });
    } catch (e) {
      debugPrint('Error en getUsuario: $e');
    }
  }

  String getFechaFormateada() {
    DateTime ahora = DateTime.now();
    final locale = 'es_ES'; // Español
    final formatter = DateFormat('EEEE, d \'de\' MMMM', locale);
    return toBeginningOfSentenceCase(formatter.format(ahora)) ?? '';
  }

  Future<void> _validarBotones() async {
   // setState(() => _isLoading = true);
    try {
      mostrarBtnProyeccion = await service.mostrarBotonHabilitado(
        'BT002_PROYEC_DH',
        context,
      );
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    } finally {
      if (mounted) {
        //setState(() => _isLoading = false);
      }
    }
  }
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        automaticallyImplyLeading:
            false, // 👈 evita que Flutter ponga la flecha por defecto,
        backgroundColor: bg,
        title: Text(
          getFechaFormateada(), // Ej: Lunes, 29 de Julio
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout), // <- ícono correcto para cerrar sesión
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              // Confirmación opcional
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Cerrar sesión'),
                  content: Text('¿Estás seguro de que deseas cerrar sesión?'),
                  actions: [
                    TextButton(
                      child: Text('Cancelar'),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    TextButton(
                      child: Text('Salir'),
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await storage.deleteAll(); // Borra todos los datos guardados
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Hola, $nombre', style: const TextStyle(fontSize: 23)),
                  ),
                  IconButton(
                    tooltip: 'Datos personales',
                    icon: const Icon(Icons.person_outline),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditarCuentaPage(),
                        ),
                      );
                      if (!mounted) return;
                      await obtenerDatosDesdeToken();
                    },
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Año + botón para resumen
              Row(
                children: [
                  _YearDropdown(
                    year: _year,
                    onChanged: _onPickYear,
                    color: primary,
                  ),
                  const Spacer(),
                  _PillButton(
                    label: 'Resumen por mes',
                    color: const Color(0xFFEDE8FF),
                    textColor: primary,
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Selector de meses (scrollable)
              _MonthScrollable(
                months: months,
                selected: _month,
                onSelected: _onPickMonth,
                color: primary,
              ),
              const SizedBox(height: 12),

              // Card circular
              const SizedBox(height: 12),
              Center(
                child: _CircularStat(
                  primary: primary,
                  gastoMes: gastoMes,
                  proyeccionMes: proyeccionMes,
                  progress: avance, // 0..1
                ),
              ),

              const SizedBox(height: 24),

              // Tarjetas de navegación
              _NavTile(
                icon: Icons.account_balance_wallet_rounded,
                iconBg: const Color(0xFFFFEB6D),
                title: 'Gastos Diarios',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Gastosdiarios()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _NavTile(
                icon: Icons.tune_rounded,
                iconBg: const Color(0xFFE6C8FF),
                title: 'Gastos Personalizados',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GastosPersonalizados(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              if(mostrarBtnProyeccion)_NavTile(
                icon: Icons.calendar_month,
                iconBg: const Color(0xFFD8D2FE),
                title: 'Proyeccion Mensual',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProyeccionesPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 28),

              /*  // Botón grande "+"
              Center(
                child: GestureDetector(
                  onTap: () {/* crear nuevo */},
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE6E1FF), width: 10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12, blurRadius: 18, offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.add, size: 48, color: primary),
                  ),
                ),
              ),*/
            ],
          ),
        ),
      ),
    );
  }
}

// =============== Widgets de soporte =================

class _MonthScrollable extends StatefulWidget {
  const _MonthScrollable({
    required this.months,
    required this.selected, // 1..12
    required this.onSelected,
    required this.color,
  });

  final List<String> months;
  final int selected;
  final ValueChanged<int> onSelected;
  final Color color;

  @override
  State<_MonthScrollable> createState() => _MonthScrollableState();
}

class _MonthScrollableState extends State<_MonthScrollable> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(covariant _MonthScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;

    final idx = (widget.selected - 1).clamp(0, widget.months.length - 1);
    // Cada item tiene aproximadamente 100px de ancho (ajusta según tu diseño)
    const itemWidth = 100.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetPosition =
        (idx * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    _scrollController.animateTo(
      targetPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.6),
        borderRadius: BorderRadius.circular(28),
      ),
      child: ListView.separated(
        controller: _scrollController, // IMPORTANTE
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        itemCount: widget.months.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final isSel = widget.selected == i + 1;
          return GestureDetector(
            onTap: () => widget.onSelected(i + 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? widget.color.withOpacity(.9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(
                  widget.months[i],
                  style: TextStyle(
                    color: isSel ? Colors.white : Colors.black87,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _YearDropdown extends StatelessWidget {
  const _YearDropdown({
    required this.year,
    required this.onChanged,
    required this.color,
  });

  final int year;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Rango de años (ajusta a gusto)
    final now = DateTime.now().year;
    final years = List<int>.generate(7, (i) => now - 3 + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButton<int>(
        value: year,
        underline: const SizedBox.shrink(),
        iconEnabledColor: color,
        items: years
            .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _CircularStat extends StatelessWidget {
  const _CircularStat({
    required this.primary,
    required this.gastoMes,
    required this.proyeccionMes,
    required this.progress,
  });

  final Color primary;
  final double gastoMes;
  final double proyeccionMes;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // fondo
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _RingPainter(
                progress: 1,
                color: primary.withOpacity(.12),
                stroke: 16,
              ),
            ),
          ),
          // progreso
          SizedBox(
            width: 220,
            height: 220,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0, 1)),
              duration: const Duration(milliseconds: 700),
              builder: (_, val, __) => CustomPaint(
                painter: _RingPainter(
                  progress: val,
                  color: primary,
                  stroke: 16,
                ),
              ),
            ),
          ),
          // textos
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Gasto del Mes', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                'S/ ${gastoMes.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              /*
              const SizedBox(height: 8),
              Text(
                'Proyección\nS/ ${proyeccionMes.toStringAsFixed(1)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: primary, fontWeight: FontWeight.w600),
              ),*/
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.stroke,
  });
  final double progress; // 0..1
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final start = -math.pi * 3 / 4; // arranque 225°
    final sweep = math.pi * 1.5 * progress; // 270° máximo
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect.deflate(stroke / 2), start, sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEDE8FF),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.purple.shade700),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
