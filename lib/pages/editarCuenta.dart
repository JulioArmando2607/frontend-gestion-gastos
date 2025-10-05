import 'dart:io';

import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/pages/home.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';

class EditarCuentaPage extends StatefulWidget {
  const EditarCuentaPage({super.key});

  @override
  _EditarCuentaPageState createState() => _EditarCuentaPageState();
}

class _EditarCuentaPageState extends State<EditarCuentaPage> {
  @override
  void initState() {
    super.initState();
    obtenerDatosDesdeToken();
  }

  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final storage = FlutterSecureStorage();
  final ApiService service = ApiService();
  String nombre = '';
  int idUsuario = 0;
  String email = '';
  Future<void> _registrarUsuario() async {
    String? token = await storage.read(key: 'token');

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final response = await service.editarCuenta(context, idUsuario, {
        'nombre': _nombreController.text,
        'email': _emailController.text,
      });

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario actulizado exitosamente')),
        );
        _cancelar();
      } else {
        setState(() => _isLoading = false);
        print(response.statusCode);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al actulizado usuario')));
      }
    }
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
    }
  }

  // En tu State
  Future<void> getUsuario(String id) async {
    try {
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
          _nombreController.text = nombre;
          _emailController.text = email;
        });

        // Mensaje correcto y opcional (no siempre es necesario mostrarlo)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario cargado correctamente')),
        );
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión expirada. Inicia sesión nuevamente.'),
          ),
        );
        // Aquí podrías redirigir al login
      } else {
        debugPrint(
          'Error al obtener usuario: ${response.statusCode} - ${response.body}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${response.statusCode} al obtener usuario'),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Excepción al obtener usuario: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error inesperado')),
      );
    }
  }

  Future<void> _cancelar() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configurar Cuenta'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su nombre';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Correo Electrónico'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su correo electrónico';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Ingrese un correo electrónico válido';
                  }
                  return null;
                },
              ),
              /*  TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su contraseña';
                  }
                  return null;
                },
              ),*/
              SizedBox(height: 20),

              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      child: ElevatedButton(
                        onPressed: _registrarUsuario,
                        child: Text('Modificar'),
                      ),
                    ),
              ElevatedButton(onPressed: _cancelar, child: Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
  }
}
