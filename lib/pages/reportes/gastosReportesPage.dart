import 'package:app_gestion_gastos/clases/Movimiento.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GastosReportesPage extends StatefulWidget {
  const GastosReportesPage({
    super.key,
    required this.movimientos,
  });

  final List<Movimiento> movimientos;

  static const Color primary = Color(0xFF6C55F9);
  static const Color bg = Color(0xFFF8F3FF);

  @override
  State<GastosReportesPage> createState() => _GastosReportesPageState();
}

class _GastosReportesPageState extends State<GastosReportesPage> {
  late final List<DateTime> _months;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _months = _buildMonthOptions(widget.movimientos);
    _selectedMonth = _months.first;
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 430;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: GastosReportesPage.bg,
        appBar: AppBar(
          backgroundColor: GastosReportesPage.bg,
          elevation: 0,
          title: Text(
            _reportesTitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: _selectedMonth,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedMonth = value);
                      },
                      items: _months
                          .map(
                            (m) => DropdownMenuItem<DateTime>(
                              value: m,
                              child: Text(
                                isCompact ? _monthLabelShort(m) : _monthLabel(m),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Diario'),
              Tab(text: 'Semanal'),
              Tab(text: 'Mensual'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DailyReportTab(
              movimientos: widget.movimientos,
              selectedMonth: _selectedMonth,
            ),
            _WeeklyReportTab(
              movimientos: widget.movimientos,
              selectedMonth: _selectedMonth,
            ),
            _MonthlyReportTab(
              movimientos: widget.movimientos,
              selectedMonth: _selectedMonth,
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyReportTab extends StatelessWidget {
  const _DailyReportTab({
    required this.movimientos,
    required this.selectedMonth,
  });

  final List<Movimiento> movimientos;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final startMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    final daily = <DateTime, double>{};
    for (final m in movimientos) {
      if (m.tipo != 'GASTO') continue;
      final d = _parseFecha(m.fecha);
      if (d == null) continue;
      if (d.isBefore(startMonth) || !d.isBefore(endMonth)) continue;
      final key = DateTime(d.year, d.month, d.day);
      daily[key] = (daily[key] ?? 0) + m.monto;
    }

    final sorted = daily.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    if (sorted.isEmpty) {
      return _EmptyReport(
        title: 'Sin gastos diarios',
        subtitle: 'No hay gastos en ${_monthLabel(selectedMonth)}.',
      );
    }

    final totalMes = sorted.fold<double>(0, (sum, e) => sum + e.value);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'Total del mes',
          value: 'S/ ${totalMes.toStringAsFixed(2)}',
          subtitle: '${sorted.length} día(s) con consumo',
          color: GastosReportesPage.primary,
        ),
        const SizedBox(height: 12),
        ...sorted.map(
          (e) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: GastosReportesPage.primary.withOpacity(.14),
                child: const Icon(Icons.calendar_today_rounded, size: 18),
              ),
              title: Text(
                DateFormat('dd MMM yyyy', 'es_ES').format(e.key),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: Text(
                'S/ ${e.value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyReportTab extends StatefulWidget {
  const _WeeklyReportTab({
    required this.movimientos,
    required this.selectedMonth,
  });

  final List<Movimiento> movimientos;
  final DateTime selectedMonth;

  @override
  State<_WeeklyReportTab> createState() => _WeeklyReportTabState();
}

class _WeeklyReportTabState extends State<_WeeklyReportTab> {
  late List<_WeekOption> _weeks;
  late _WeekOption _selectedWeek;

  @override
  void initState() {
    super.initState();
    _weeks = _buildWeekOptions(widget.selectedMonth);
    _selectedWeek = _weeks.first;
  }

  @override
  void didUpdateWidget(covariant _WeeklyReportTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameMonth(oldWidget.selectedMonth, widget.selectedMonth)) {
      _weeks = _buildWeekOptions(widget.selectedMonth);
      _selectedWeek = _weeks.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final startMonth =
        DateTime(widget.selectedMonth.year, widget.selectedMonth.month, 1);
    final endMonth =
        DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 1);

    final now = DateTime.now();
    final weekStart = _selectedWeek.start;
    final weekEnd = _selectedWeek.end;
    final isCurrentMonth = _isSameMonth(widget.selectedMonth, now);
    final today = DateTime(now.year, now.month, now.day);
    final cutoffDate =
        isCurrentMonth && !today.isBefore(weekStart) && !today.isAfter(weekEnd)
            ? today
            : weekEnd;

    double ingresoMensual = 0;
    double gastoSemana = 0;

    for (final m in widget.movimientos) {
      final d = _parseFecha(m.fecha);
      if (d == null) continue;

      if (!d.isBefore(startMonth) && d.isBefore(endMonth) && m.tipo == 'INGRESO') {
        ingresoMensual += m.monto;
      }

      final inSelectedMonth = !d.isBefore(startMonth) && d.isBefore(endMonth);
      final inSelectedWeek = !d.isBefore(weekStart) && !d.isAfter(weekEnd);
      if (inSelectedMonth && inSelectedWeek && m.tipo == 'GASTO') {
        gastoSemana += m.monto;
      }
    }

    final diasDelMes =
        DateTime(widget.selectedMonth.year, widget.selectedMonth.month + 1, 0).day;
    final presupuestoDiario =
        ingresoMensual > 0 ? ingresoMensual / diasDelMes : 0.0;
    final diasSemanaSeleccionada = weekEnd.difference(weekStart).inDays + 1;
    final presupuestoSemanal = presupuestoDiario * diasSemanaSeleccionada;
    final diasHastaCorte = cutoffDate.difference(weekStart).inDays + 1;
    final gastoPermitidoHastaHoySemana = presupuestoDiario * diasHastaCorte;

    final ratio = gastoPermitidoHastaHoySemana > 0
        ? gastoSemana / gastoPermitidoHastaHoySemana
        : 0.0;

    final status = _weeklyStatus(ratio);
    final progress = ratio.isFinite ? ratio.clamp(0.0, 1.4) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.view_week_rounded),
                const SizedBox(width: 8),
                const Text('Semana'),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_WeekOption>(
                      isExpanded: true,
                      value: _selectedWeek,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedWeek = value);
                      },
                      items: _weeks
                          .map(
                            (w) => DropdownMenuItem<_WeekOption>(
                              value: w,
                              child: Text(
                                w.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatusCard(
          title: 'Estado semanal',
          subtitle: ingresoMensual > 0
              ? status.message
              : 'No hay ingresos en ${_monthLabel(widget.selectedMonth)} para calcular el objetivo semanal.',
          color: ingresoMensual > 0 ? status.color : Colors.grey,
          icon: ingresoMensual > 0 ? status.icon : Icons.info_outline_rounded,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gasto de la semana: S/ ${gastoSemana.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Objetivo semanal (según ingreso): S/ ${presupuestoSemanal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Permitido hasta ${DateFormat('dd/MM').format(cutoffDate)}: S/ ${gastoPermitidoHastaHoySemana.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    color: ingresoMensual > 0 ? status.color : Colors.grey,
                    backgroundColor: (ingresoMensual > 0 ? status.color : Colors.grey)
                        .withOpacity(.2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ratio > 0
                      ? '${(ratio * 100).toStringAsFixed(0)}% del gasto permitido a la fecha de corte'
                      : 'Sin datos suficientes para calcular porcentaje',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyReportTab extends StatelessWidget {
  const _MonthlyReportTab({
    required this.movimientos,
    required this.selectedMonth,
  });

  final List<Movimiento> movimientos;
  final DateTime selectedMonth;

  @override
  Widget build(BuildContext context) {
    final startMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);

    final dailyGastos = <DateTime, double>{};
    double ingresoMensual = 0;
    double gastoMensual = 0;

    for (final m in movimientos) {
      final d = _parseFecha(m.fecha);
      if (d == null) continue;
      if (d.isBefore(startMonth) || !d.isBefore(endMonth)) continue;

      if (m.tipo == 'INGRESO') {
        ingresoMensual += m.monto;
        continue;
      }

      if (m.tipo != 'GASTO') continue;

      gastoMensual += m.monto;
      final key = DateTime(d.year, d.month, d.day);
      dailyGastos[key] = (dailyGastos[key] ?? 0) + m.monto;
    }

    if (ingresoMensual == 0 && gastoMensual == 0) {
      return _EmptyReport(
        title: 'Sin balance mensual',
        subtitle: 'No hay ingresos ni gastos en ${_monthLabel(selectedMonth)}.',
      );
    }

    final now = DateTime.now();
    final diasDelMes = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final presupuestoDiario =
        ingresoMensual > 0 ? ingresoMensual / diasDelMes : 0.0;
    final diaDeCorte = _isSameMonth(selectedMonth, now) ? now.day : diasDelMes;
    final gastoPermitidoHastaCorte = presupuestoDiario * diaDeCorte;

    final excesoAcumulado = gastoMensual - gastoPermitidoHastaCorte;
    final ratioIngreso = ingresoMensual > 0 ? gastoMensual / ingresoMensual : 0.0;
    final status = _weeklyStatus(ratioIngreso);
    final maxDay = dailyGastos.isNotEmpty
        ? dailyGastos.entries.reduce((a, b) => a.value >= b.value ? a : b)
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoCard(
          title: 'Ingreso mensual',
          value: 'S/ ${ingresoMensual.toStringAsFixed(2)}',
          subtitle: 'Base para calcular tu presupuesto diario',
          color: GastosReportesPage.primary,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_view_day_rounded),
            title: const Text('Presupuesto diario sugerido'),
            subtitle: Text(
              'S/ ${presupuestoDiario.toStringAsFixed(2)} por día\n'
              'Gasto acumulado del mes: S/ ${gastoMensual.toStringAsFixed(2)}',
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatusCard(
          title: 'Estado general',
          subtitle: ingresoMensual > 0
              ? status.message
              : 'No hay ingresos registrados en ${_monthLabel(selectedMonth)}.',
          color: ingresoMensual > 0 ? status.color : Colors.grey,
          icon: ingresoMensual > 0 ? status.icon : Icons.info_outline_rounded,
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(
              excesoAcumulado > 0 ? Icons.warning_rounded : Icons.check_circle_rounded,
              color: excesoAcumulado > 0 ? Colors.red : Colors.green,
            ),
            title: Text(
              excesoAcumulado > 0
                  ? 'Alerta: vas por encima de tu ritmo mensual'
                  : 'Vas dentro del ritmo mensual',
            ),
            subtitle: Text(
              'Permitido hasta día $diaDeCorte: S/ ${gastoPermitidoHastaCorte.toStringAsFixed(2)}\n'
              'Diferencia: S/ ${excesoAcumulado.abs().toStringAsFixed(2)} '
              '${excesoAcumulado > 0 ? 'de exceso' : 'disponible'}',
            ),
          ),
        ),
        if (maxDay != null) ...[
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.local_fire_department_rounded, color: Colors.red),
              title: const Text('Día con más gasto'),
              subtitle: Text(
                '${DateFormat('dd MMM yyyy', 'es_ES').format(maxDay.key)} · '
                'S/ ${maxDay.value.toStringAsFixed(2)}',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

DateTime? _parseFecha(String raw) {
  if (raw.isEmpty) return null;
  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso;
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(raw);
  } catch (_) {
    return null;
  }
}

List<DateTime> _buildMonthOptions(List<Movimiento> movimientos) {
  final set = <String, DateTime>{};
  for (final m in movimientos) {
    final d = _parseFecha(m.fecha);
    if (d == null) continue;
    final month = DateTime(d.year, d.month, 1);
    set['${month.year}-${month.month}'] = month;
  }

  final nowMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  set['${nowMonth.year}-${nowMonth.month}'] = nowMonth;

  final months = set.values.toList()
    ..sort((a, b) => b.compareTo(a));

  return months;
}

bool _isSameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

String _reportesTitle(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width < 520 ? 'Reportes' : 'Reportes financieros';
}

String _monthLabel(DateTime date) {
  final raw = DateFormat('MMMM yyyy', 'es_ES').format(date);
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}

String _monthLabelShort(DateTime date) {
  final raw = DateFormat('MMM yy', 'es_ES').format(date);
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}

List<_WeekOption> _buildWeekOptions(DateTime month) {
  final startMonth = DateTime(month.year, month.month, 1);
  final endMonth = DateTime(month.year, month.month + 1, 0);
  final weeks = <_WeekOption>[];

  var weekStart = startMonth;
  var index = 1;
  while (!weekStart.isAfter(endMonth)) {
    final candidateEnd = weekStart.add(const Duration(days: 6));
    final weekEnd = candidateEnd.isAfter(endMonth) ? endMonth : candidateEnd;

    weeks.add(
      _WeekOption(
        index: index,
        start: DateTime(weekStart.year, weekStart.month, weekStart.day),
        end: DateTime(weekEnd.year, weekEnd.month, weekEnd.day),
        label:
            'Semana $index (${DateFormat('dd/MM').format(weekStart)} - ${DateFormat('dd/MM').format(weekEnd)})',
      ),
    );

    weekStart = weekEnd.add(const Duration(days: 1));
    index++;
  }

  return weeks;
}

class _WeekOption {
  const _WeekOption({
    required this.index,
    required this.start,
    required this.end,
    required this.label,
  });

  final int index;
  final DateTime start;
  final DateTime end;
  final String label;
}

_WeeklyStatus _weeklyStatus(double ratio) {
  if (ratio <= 0.85) {
    return const _WeeklyStatus(
      color: Colors.green,
      icon: Icons.check_circle_rounded,
      message: 'Vas en verde: dentro de lo planificado',
    );
  }
  if (ratio <= 1.0) {
    return const _WeeklyStatus(
      color: Colors.orange,
      icon: Icons.warning_rounded,
      message: 'Vas al límite: cerca del tope',
    );
  }
  return const _WeeklyStatus(
    color: Colors.red,
    icon: Icons.error_rounded,
    message: 'Vas en rojo: estás excediendo tu planificación',
  );
}

class _WeeklyStatus {
  const _WeeklyStatus({
    required this.color,
    required this.icon,
    required this.message,
  });

  final Color color;
  final IconData icon;
  final String message;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(.95), color.withOpacity(.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(.3)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assessment_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
