import 'dart:convert';

import 'package:app_gestion_gastos/api/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReporteMensualPage extends StatefulWidget {
  const ReporteMensualPage({super.key, required this.idCard});

  final int idCard;

  @override
  State<ReporteMensualPage> createState() => _ReporteMensualPageState();
}

class _ReporteMensualPageState extends State<ReporteMensualPage> {
  final ApiService service = ApiService();
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
  );

  List<Map<String, dynamic>> allData = [];
  List<String> anios = [];
  List<String> mesesFiltrados = [];

  String? selectedAnio;
  String? selectedMes;

  bool isLoading = true;
  String? errorMessage;

  List<Map<String, dynamic>> detalleGasto = [];
  List<Map<String, dynamic>> detalleIngreso = [];

  final List<String> meses = const [
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

  double get totalIngresos => detalleIngreso.fold<double>(
    0,
    (sum, e) => sum + _toDouble(e['monto']),
  );

  double get totalGastos => detalleGasto.fold<double>(
    0,
    (sum, e) => sum + _toDouble(e['monto']),
  );

  double get balance => totalIngresos - totalGastos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte mensual'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _listarReporteCard(widget.idCard),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (errorMessage != null) _buildErrorCard(errorMessage!),
                  if (errorMessage == null && selectedMes == null)
                    _buildHintCard('Selecciona un mes para ver el detalle.'),
                  if (errorMessage == null && selectedMes != null) ...[
                    _buildSummaryCards(),
                    const SizedBox(height: 16),
                    _buildDetalleSection(
                      titulo: 'Ingresos',
                      color: Colors.green,
                      detalle: detalleIngreso,
                    ),
                    const SizedBox(height: 12),
                    _buildDetalleSection(
                      titulo: 'Gastos',
                      color: Colors.red,
                      detalle: detalleGasto,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: const Row(
        children: [
          Icon(Icons.insights_rounded),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Revisa tus ingresos y gastos por mes con mayor detalle.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedAnio,
            decoration: const InputDecoration(labelText: 'Año'),
            items: anios
                .map(
                  (anio) => DropdownMenuItem(
                    value: anio,
                    child: Text(anio),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => selectedAnio = value);
              _filtrarMesesYActualizarUI(value);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedMes,
            decoration: const InputDecoration(labelText: 'Mes'),
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
    );
  }

  Widget _buildSummaryCards() {
    final balanceColor = balance >= 0 ? Colors.teal : Colors.orange;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _summaryCard('Ingresos', totalIngresos, Colors.green),
        _summaryCard('Gastos', totalGastos, Colors.red),
        _summaryCard('Balance', balance, balanceColor),
      ],
    );
  }

  Widget _summaryCard(String label, double value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            _currency.format(value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalleSection({
    required String titulo,
    required Color color,
    required List<Map<String, dynamic>> detalle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 12),
              const SizedBox(width: 8),
              Text(
                '$titulo',//(${detalle.length})
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (detalle.isEmpty)
            Text(
              'Sin registros en este mes.',
              style: TextStyle(color: Colors.grey.shade600),
            )
          else
            ...detalle.map((e) {
              final item = _itemName(e);
              final monto = _currency.format(_toDouble(e['monto']));
              final fecha = _formatFecha(e['fecha']?.toString());
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(item),
                subtitle: Text(fecha),
                trailing: Text(
                  monto,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHintCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text),
    );
  }

  Widget _buildErrorCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Future<void> _listarReporteCard(int idCard) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final res = await service.listarReporteCard(context, idCard);
      if (res.statusCode != 200) {
        setState(() {
          errorMessage = 'No se pudo cargar el reporte (${res.statusCode}).';
          isLoading = false;
        });
        return;
      }

      final List<dynamic> data = jsonDecode(res.body);
      final registros = data.map((e) => Map<String, dynamic>.from(e)).toList();

      if (registros.isEmpty) {
        setState(() {
          allData = [];
          anios = [];
          mesesFiltrados = [];
          selectedAnio = null;
          selectedMes = null;
          detalleIngreso = [];
          detalleGasto = [];
          errorMessage = 'No hay información para mostrar en reportes.';
          isLoading = false;
        });
        return;
      }

      final aniosUnicos = registros
          .map((e) => DateTime.parse(e['fecha']).year.toString())
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      final anioInicial = aniosUnicos.first;

      setState(() {
        allData = registros;
        anios = aniosUnicos;
        selectedAnio = anioInicial;
        isLoading = false;
      });

      _filtrarMesesYActualizarUI(anioInicial);
    } catch (_) {
      setState(() {
        errorMessage = 'Ocurrió un error al cargar el reporte.';
        isLoading = false;
      });
    }
  }

  void _filtrarMesesYActualizarUI(String anio) {
    final datosFiltrados = allData
        .where((e) => DateTime.parse(e['fecha']).year.toString() == anio)
        .toList();

    final mesesUnicos = datosFiltrados
        .map((e) => DateTime.parse(e['fecha']).month.toString().padLeft(2, '0'))
        .toSet()
        .toList()
      ..sort();

    final mesInicial = mesesUnicos.isNotEmpty ? mesesUnicos.last : null;

    setState(() {
      mesesFiltrados = mesesUnicos;
      selectedMes = mesInicial;
      detalleIngreso = [];
      detalleGasto = [];
      errorMessage = null;
    });

    if (mesInicial != null) {
      _filtrarIngresosYGastos(anio, mesInicial);
    }
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
    });
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _itemName(Map<String, dynamic> item) {
    final name = item['item'] ?? item['categoria'] ?? item['descripcion'] ?? 'Sin nombre';
    return name.toString();
  }

  String _formatFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return '';
    try {
      final dt = DateTime.parse(fecha);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return fecha;
    }
  }
}

// Compatibilidad temporal: mantiene referencias antiguas mientras se migra.
class ReporteMensualModal extends ReporteMensualPage {
  const ReporteMensualModal({super.key, required super.idCard});
}
