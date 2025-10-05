class Categoria {
  final int id;
  final String nombre;
  final String tipo;
  final String color;
  final String icono;

  Categoria({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.color,
    required this.icono,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'],
      nombre: json['nombre'],
      tipo: json['tipo'],
      color: json['color'],
      icono: json['icono'],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Categoria && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
