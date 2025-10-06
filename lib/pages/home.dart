import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/clases/Movimiento.dart';
import 'package:app_gestion_gastos/pages/editarCuenta.dart';
import 'package:app_gestion_gastos/pages/gastosDiarios.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String nombre = '';
  int idUsuario = 0;
  String email = '';
  double montoSaldoTotal = 0.0;
  double montoIngresos = 0.0;
  double montoGastos = 0.0;
  List<Movimiento> movimientos = [];
  final ApiService service = ApiService();
  final storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    obtenerDatosDesdeToken();
    obtenerCarResumen();
    obtenerMovimientos(); // 👈 Nuevo
  }

  void obtenerDatosDesdeToken() async {
    String? token = await storage.read(key: 'token');

    if (token != null) {
      Map<String, dynamic> decodedToken = JwtDecoder.decode(token);

      setState(() {
        nombre = decodedToken['nombre'];
        idUsuario = decodedToken['id'];
        email = decodedToken['sub'];
      });
      getUsuario(idUsuario.toString());
      //print('Nombre: $nombre, ID: $idUsuario, Email: $email');
    }
  }

  Future<void> getUsuario(String id) async {
    final response = await service.usuario(context, id);

    if (response.statusCode == 200) {
      // Decodifica el JSON de forma segura (UTF-8)
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (!mounted) return;
      setState(() {
        nombre = data['nombre'] as String? ?? '';
        email = data['email'] as String? ?? '';
      });
    }
  }

  void obtenerCarResumen() async {
    final response = await service.cardResumen(context);
    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body);

        // Validar si vienen los datos
        final saldoTotalRaw = json['saldoTotal'];
        final ingresoRaw = json['totalIngresos'];
        final gastosRaw = json['totalGastos'];

        final double saldoTotal = saldoTotalRaw != null
            ? double.tryParse(saldoTotalRaw.toString()) ?? 0.0
            : 0.0;
        final double ingresoTotal = ingresoRaw != null
            ? double.tryParse(ingresoRaw.toString()) ?? 0.0
            : 0.0;
        final double gastosTotal = gastosRaw != null
            ? double.tryParse(gastosRaw.toString()) ?? 0.0
            : 0.0;

        setState(() {
          montoSaldoTotal = saldoTotal;
          montoIngresos = ingresoTotal;
          montoGastos = gastosTotal;
        });
      } catch (e) {
        debugPrint('Error al procesar el resumen: $e');
        // puedes mostrar un snackbar u otra alerta
      }
    } else {
      debugPrint('Error de conexión: ${response.statusCode}');
    }
  }

  void obtenerMovimientos() async {
    final response = await service.obtenerMovimientos(context);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);

      setState(() {
        movimientos = data.map((e) => Movimiento.fromJson(e)).toList();
      });
    } else {
      print('Error al obtener movimientos: ${response.statusCode}');
    }
  }

  eliminarMovimiento(id) async {
    final response = await service.eliminarMovimiento(context, id.toString());
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Movimiento eliminado con éxito')));
    } else {
      print('Error al obtener movimientos: ${response.statusCode}');
    }
  }

  String getFechaFormateada() {
    DateTime ahora = DateTime.now();
    final locale = 'es_ES'; // Español
    final formatter = DateFormat('EEEE, d \'de\' MMMM', locale);
    return toBeginningOfSentenceCase(formatter.format(ahora)) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola, $nombre', style: TextStyle(fontSize: 23)),

            SizedBox(height: 16),
            Card(
              color: Colors.green.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Ocupa el ancho disponible para que el área táctil sea grande
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => Gastosdiarios(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Gastos Diarios',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.money, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Saldo Total',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      montoSaldoTotal.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ingresos\n $montoIngresos',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Gastos\nS/- $montoGastos ',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            /*  Card(
              color: Colors.green.shade900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Proyeccion',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(), // Empuja el símbolo a la derecha
                        Text(
                          '>',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.money, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Ahorro Total',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      montoSaldoTotal.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ingresos\n $montoIngresos',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          'Gastos\nS/- $montoGastos ',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),*/
            /*   Expanded(
              child: ListView.builder(
                itemCount: movimientos.length,
                itemBuilder: (context, index) {
                  final movimiento = movimientos[index];

                  final color = movimiento.tipo == 'INGRESO'
                      ? Colors.green
                      : Colors.red;
                  final signo = movimiento.tipo == 'INGRESO' ? '+' : '-';

                  return Dismissible(
                    key: Key(movimiento.id.toString()),
                    background: Container(
                      color: Colors.blue, // Fondo para editar
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.edit, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red, // Fondo para eliminar
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        // 👉 Confirmación para eliminar
                        final confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Confirmar eliminación'),
                            content: Text(
                              '¿Estás seguro de eliminar este movimiento?',
                            ),
                            actions: [
                              TextButton(
                                child: Text('Cancelar'),
                                onPressed: () => Navigator.pop(context, false),
                              ),
                              TextButton(
                                child: Text('Eliminar'),
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ],
                          ),
                        );
                        return confirm == true;
                      } else {
                        // 👉 Acción para editar
                        // Navega a la página de edición
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditarMovimientoPage(movimiento: movimiento),
                          ),
                        );
                        /* Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditarMovimientoPage(movimiento: movimiento),
                          ),
                        );*/
                        return false;
                      }
                    },
                    onDismissed: (direction) async {
                      if (direction == DismissDirection.endToStart) {
                        // Aquí llamas a tu servicio para eliminar
                        await eliminarMovimiento(movimiento.id);
                        setState(() {
                          movimientos.removeAt(index);
                          obtenerCarResumen();
                          obtenerMovimientos();
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Movimiento eliminado')),
                        );
                      }
                    },
                    child: _buildTransactionItem(
                      context,
                      amount:
                          '$signo S/ ${movimiento.monto.toStringAsFixed(2)}',
                      description: movimiento.descripcion,
                      date: movimiento.fecha,
                      color: color,
                      categoria: movimiento.categoria.nombre,
                    ),
                  );
                },
              ),
            ),
           */
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => EditarCuentaPage()),
          );
          // Acción para agregar nueva transacción
        },
        backgroundColor: Colors.amber,
        child: Icon(Icons.settings),
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context, {
    required String amount,
    required String description,
    required String categoria,
    required String date,
    required Color color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(Icons.circle, color: color),
        title: Text(amount),
        subtitle: Text('$description \n $categoria'),
        trailing: Text(date),
      ),
    );
  }
}
