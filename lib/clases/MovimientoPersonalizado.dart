
class MovimientoPersonalizado {
  final String tipo;
  final double monto;
  final String descripcion;
  final String fecha;
  final int id;
  final String categoria;

  MovimientoPersonalizado({
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    required this.id,
    required this.categoria,
  });

  factory MovimientoPersonalizado.fromJson(Map<String, dynamic> json) {
    return MovimientoPersonalizado(
      tipo: json['tipo'],
      monto: double.parse(json['monto'].toString()),
      descripcion: json['nota'],
      fecha: json['fecha'],
      id: json['id'],
      categoria:  json['categoria'],//Categoria.fromJson(json['categoria']),
    );
  }
}
