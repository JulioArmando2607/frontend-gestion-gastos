class CardPersonalizado {
  final int id;
 // final int userId;
  final String nombre;
  final String descripcion;
  final String moneda;
  final String colorHex;

  final double saldo;
  final double ingresos;
  final double gastos;

  CardPersonalizado({
    required this.id,
  ///  required this.userId,
    required this.nombre,
    required this.descripcion,
    required this.moneda,
    required this.colorHex,


    required this.saldo,
    required this.ingresos,
    required this.gastos,
  });

  factory CardPersonalizado.fromJson(Map<String, dynamic> json) {
    return CardPersonalizado(
      id: json['id'],
    //  userId: json['userId'],
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      moneda: json['moneda'],
      colorHex: json['colorHex'],



      saldo: json['saldo'],
      ingresos: json['ingresos'],
      gastos: json['gastos'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
   //   'userId': userId,
      'nombre': nombre,
      'descripcion': descripcion,
      'moneda': moneda,
      'colorHex': colorHex,

      'saldo': saldo,
      'ingresos': ingresos,
      'gastos': gastos,

    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is CardPersonalizado &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id.hashCode;
}
