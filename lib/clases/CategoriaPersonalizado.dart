class CategoriaPersonalizado {
  final int id;
  final String nombre;

  CategoriaPersonalizado({
    required this.id,
    required this.nombre,
    });

  factory CategoriaPersonalizado.fromJson(Map<String, dynamic> json) {
    return CategoriaPersonalizado(
      id: json['id'],
      nombre: json['nombre'],
     );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoriaPersonalizado && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
