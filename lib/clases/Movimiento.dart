import 'package:app_gestion_gastos/clases/Categoria.dart';

class Movimiento {
  final String tipo;
  final double monto;
  final String descripcion;
  final String fecha;
  final int id;
  final Categoria categoria;

  Movimiento({
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    required this.id,
    required this.categoria,
  });

  factory Movimiento.fromJson(Map<String, dynamic> json) {
    return Movimiento(
      tipo: json['tipo'],
      monto: double.parse(json['monto'].toString()),
      descripcion: json['descripcion'],
      fecha: json['fecha'],
      id: json['id'],
      categoria: Categoria.fromJson(json['categoria']),
    );
  }
}
