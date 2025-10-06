import 'dart:convert';

import 'package:app_gestion_gastos/api/services.dart';
import 'package:flutter/material.dart';

class ReporteMensualModal extends StatefulWidget {
  final int idCard;

  const ReporteMensualModal({super.key, required this.idCard});

  @override
  State<ReporteMensualModal> createState() => _ReporteMensualModalState();
}

class _ReporteMensualModalState extends State<ReporteMensualModal> {
  final ApiService service = ApiService();

  List<Map<String, dynamic>> allData = [];
  List<String> anios = [];
  List<String> mesesFiltrados = [];

  String? selectedAnio;
  String? selectedMes;

  bool mostrarDetalle = false;
  String tipoDetalle = '';

  List<Map<String, dynamic>> ingresosYGastos = [];
  List<Map<String, dynamic>> detalleGasto = [];
  List<Map<String, dynamic>> detalleIngreso = [];

  final List<String> meses = [
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listarReporteCard(widget.idCard);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reporte Mensual',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedAnio,
                      decoration: const InputDecoration(labelText: 'AÑO'),
                      items: anios
                          .map(
                            (anio) => DropdownMenuItem(
                              value: anio,
                              child: Text(anio),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedAnio = value);
                        if (value != null) _filtrarMesesYActualizarUI(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: selectedMes,
                      decoration: const InputDecoration(labelText: 'MES'),
                      items: mesesFiltrados.map((mesNum) {
                        final index = int.parse(mesNum) - 1;
                        return DropdownMenuItem(
                          value: mesNum,
                          child: Text(meses[index]),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedMes = value);
                        if (selectedAnio != null && value != null) {
                          _filtrarIngresosYGastos(selectedAnio!, value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ...ingresosYGastos.map(
                (e) => ListTile(
                  title: Text(e['tipo'].toString()),
                  trailing: Text(e['monto'].toString()),
                  onTap: () {
                    setState(() {
                      mostrarDetalle = true;
                      tipoDetalle = e['tipo'].toString();
                    });
                  },
                ),
              ),
              if (mostrarDetalle && tipoDetalle == 'GASTO')
                _buildDetalleTable(detalleGasto, 'Detalle de Gasto'),
              if (mostrarDetalle && tipoDetalle == 'INGRESO')
                _buildDetalleTable(detalleIngreso, 'Detalle de Ingreso'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetalleTable(List<Map<String, dynamic>> detalle, String titulo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Table(
          border: TableBorder.all(),
          children: [
            const TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Item',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Monto',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            ...detalle.map(
              (e) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(e['item'].toString()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(e['monto'].toString()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _listarReporteCard(int idCard) async {
    final resGasto = await service.listarReporteCard(context, idCard);

    if (resGasto.statusCode == 200) {
      final List<dynamic> data = jsonDecode(resGasto.body);
      final List<Map<String, dynamic>> registros = data
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final Set<String> aniosUnicos = registros
          .map((e) => DateTime.parse(e['fecha']).year.toString())
          .toSet();

      setState(() {
        allData = registros;
        anios = aniosUnicos.toList()..sort();
        selectedAnio = anios.first;
      });

      _filtrarMesesYActualizarUI(selectedAnio!);
    }
  }

  void _filtrarMesesYActualizarUI(String anio) {
    final List<Map<String, dynamic>> datosFiltrados = allData
        .where((e) => DateTime.parse(e['fecha']).year.toString() == anio)
        .toList();

    final Set<String> mesesUnicos = datosFiltrados
        .map((e) => DateTime.parse(e['fecha']).month.toString().padLeft(2, '0'))
        .toSet();

    setState(() {
      mesesFiltrados = mesesUnicos.toList()..sort();
      selectedMes = null;
      ingresosYGastos.clear();
      detalleGasto.clear();
      detalleIngreso.clear();
      mostrarDetalle = false;
    });
  }

  void _filtrarIngresosYGastos(String anio, String mes) {
    final datos = allData.where((e) {
      final fecha = DateTime.parse(e['fecha']);
      return fecha.year.toString() == anio &&
          fecha.month.toString().padLeft(2, '0') == mes;
    }).toList();

    final ingresos = datos.where((e) => e['tipo'] == 'INGRESO').toList();
    final gastos = datos.where((e) => e['tipo'] == 'GASTO').toList();

    setState(() {
      detalleIngreso = ingresos;
      detalleGasto = gastos;

      ingresosYGastos = [
        {
          'tipo': 'INGRESO',
          'monto': ingresos.fold<int>(
            0,
            (sum, e) => sum + ((e['monto'] ?? 0) as num).toInt(),
          ),
        },
        {
          'tipo': 'GASTO',
          'monto': gastos.fold<int>(
            0,
            (sum, e) => sum + ((e['monto'] ?? 0) as num).toInt(),
          ),
        },
      ];
      mostrarDetalle = false;
    });
  }
}
