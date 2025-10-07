import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProyeccionMensualPage extends StatefulWidget {
  const ProyeccionMensualPage({super.key});

  @override
  State<ProyeccionMensualPage> createState() => _ProyeccionMensualPageState();
}

class _ProyeccionMensualPageState extends State<ProyeccionMensualPage> {
  final primary = const Color(0xFF6C55F9);
  final bg = const Color(0xFFF8F3FF);

  int yearActual = DateTime.now().year;
  int mesActual = DateTime.now().month;
  int ingresoMes = 2000;

  // Categorías de ejemplo
  List<Map<String, dynamic>> categorias = [
    {'nombre': 'Prestamo efectivo', 'monto': 0, 'color': Colors.grey.shade300},
    {'nombre': 'Pasajes', 'monto': 0, 'color': Colors.grey.shade300},
    {'nombre': 'Alimentos casa', 'monto': 0, 'color': Colors.grey.shade300},
    {'nombre': 'Prestamo colegio', 'monto': 0, 'color': Colors.grey.shade300},
    {'nombre': 'Pago Falabella', 'monto': 0, 'color': Colors.yellow.shade300},
    {'nombre': 'Pago Oh', 'monto': 0, 'color': Colors.orange.shade300},
    {'nombre': 'Pago Movistar', 'monto': 0, 'color': Colors.green.shade400},
    {'nombre': 'Servicios Basicos', 'monto': 0, 'color': Colors.grey.shade300},
    {'nombre': 'Teléfono', 'monto': 0, 'color': Colors.yellow.shade200},
  ];

  void _editarMonto(int index) async {
    final controller = TextEditingController(
      text: categorias[index]['monto'].toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar ${categorias[index]['nombre']}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final monto = int.tryParse(controller.text) ?? 0;
              Navigator.pop(context, monto);
            },
            child: Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        categorias[index]['monto'] = result;
      });
    }
  }

  void _crearCategoria() async {
    final nombreController = TextEditingController();
    final montoController = TextEditingController(text: '0');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nueva Categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nombre de categoría',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: montoController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: 'S/ ',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nombreController.text.isNotEmpty) {
                Navigator.pop(context, {
                  'nombre': nombreController.text,
                  'monto': int.tryParse(montoController.text) ?? 0,
                });
              }
            },
            child: Text('Crear'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        categorias.add({
          'nombre': result['nombre'],
          'monto': result['monto'],
          'color': Colors.grey.shade300,
        });
      });
    }
  }

  void _cerrarProyeccion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cerrar Proyección'),
        content: Text(
          '¿Estás seguro de cerrar esta proyección?\n\nNo podrás actualizar ni crear nuevas categorías después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Aquí guardarías la proyección en tu API
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proyección cerrada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigator.pop(context); // Opcional: volver al dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = categorias.fold(0, (sum, cat) => sum + (cat['monto'] as int));
    final ahorroEstimado = ingresoMes - total;

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
        title: Text(
          'Proyección Mensual',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primary,
        onPressed: _crearCategoria,
        icon: Icon(Icons.add),
        label: Text('Nueva Categoría'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selectores de Año y Mes
            _HeaderCard(
              yearActual: yearActual,
              mesActual: mesActual,
              ingresoMes: ingresoMes,
              primary: primary,
              onYearChanged: (y) => setState(() => yearActual = y),
              onMesChanged: (m) => setState(() => mesActual = m),
              onIngresoChanged: (i) => setState(() => ingresoMes = i),
            ),

            const SizedBox(height: 16),

            // Nota informativa
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

            // Lista de categorías
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categorías de Gasto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${categorias.length} categorías',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ...categorias.asMap().entries.map((entry) {
              final index = entry.key;
              final cat = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CategoriaItem(
                  nombre: cat['nombre'],
                  monto: cat['monto'],
                  color: cat['color'],
                  onTap: () => _editarMonto(index),
                  onDelete: () {
                    setState(() {
                      categorias.removeAt(index);
                    });
                  },
                ),
              );
            }),

            const SizedBox(height: 24),

            // Resumen
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
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _ResumenRow('Total Gastos', total, primary),
                  Divider(height: 24, thickness: 1),
                  _ResumenRow(
                    'Ahorro Estimado',
                    ahorroEstimado,
                    ahorroEstimado >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Botón de cerrar proyección
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
                icon: Icon(Icons.lock),
                label: Text(
                  'Cerrar Proyección',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 80), // Espacio para el FAB
          ],
        ),
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
    required this.onYearChanged,
    required this.onMesChanged,
    required this.onIngresoChanged,
  });

  final int yearActual;
  final int mesActual;
  final int ingresoMes;
  final Color primary;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<int> onMesChanged;
  final ValueChanged<int> onIngresoChanged;

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
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Selector de Año
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Año:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: primary.withOpacity(0.3)),
                ),
                child: DropdownButton<int>(
                  value: yearActual,
                  underline: SizedBox.shrink(),
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
                  onChanged: (v) {
                    if (v != null) onYearChanged(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selector de Mes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mes:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<int>(
                  value: mesActual,
                  underline: SizedBox.shrink(),
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
                  onChanged: (v) {
                    if (v != null) onMesChanged(v);
                  },
                  selectedItemBuilder: (context) {
                    return months.map((month) {
                      return Text(
                        month,
                        style: TextStyle(
                          color: Colors.white,
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
          Divider(),
          const SizedBox(height: 12),

          // Ingreso
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ingreso Mensual:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              GestureDetector(
                onTap: () async {
                  final controller = TextEditingController(
                    text: ingresoMes.toString(),
                  );
                  final result = await showDialog<int>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Editar Ingreso'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
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
                          child: Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final monto = int.tryParse(controller.text) ?? 0;
                            Navigator.pop(ctx, monto);
                          },
                          child: Text('Guardar'),
                        ),
                      ],
                    ),
                  );
                  if (result != null) onIngresoChanged(result);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'S/ $ingresoMes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 16, color: Colors.green.shade700),
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
    required this.onTap,
    required this.onDelete,
  });

  final String nombre;
  final int monto;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(nombre),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.folder, size: 20, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nombre,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
              Text(
                'S/ $monto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
  const _ResumenRow(this.label, this.amount, this.color);

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        Text(
          'S/ $amount',
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
