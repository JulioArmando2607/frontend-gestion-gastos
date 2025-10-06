import 'dart:convert';
import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:app_gestion_gastos/pages/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CrearCuentaPage extends StatefulWidget {
  const CrearCuentaPage({super.key});

  @override
  State<CrearCuentaPage> createState() => _CrearCuentaPageState();
}

class _CrearCuentaPageState extends State<CrearCuentaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _service = ApiService();

  bool _isLoading = false;
  bool _obscure = true;

  InputDecoration _input(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _registrarUsuario() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    print(_nombreController.text.trim());
    print(_emailController.text.trim());
    print(_passwordController.text.trim());

    final res = await _service.register({
      'nombre': _nombreController.text.trim(),
      'email': _emailController.text.trim(),
      'password': _passwordController.text,
    });
    print(res);
    setState(() => _isLoading = false);

    if (res.statusCode == 200 || res.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario registrado exitosamente')),
      );
      await _loginAfterRegister();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar: ${res.statusCode}')),
      );
    }
  }

  Future<void> _loginAfterRegister() async {
    setState(() => _isLoading = true);
    try {
      final response = await _service.login({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });
      if (response.statusCode == 200) {
        final token = jsonDecode(response.body)['token'];
        await _storage.write(key: 'token', value: token);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Login exitoso')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: ${response.statusCode}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelar() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF5B3CF5); // morado login
    return Scaffold(
      backgroundColor:
          primary, // degradado simple; puedes usar LinearGradient si quieres
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 12,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 28,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Crear Cuenta',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 24),

                      // Nombre
                      TextFormField(
                        controller: _nombreController,
                        decoration: _input('Nombre', Icons.person),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Ingrese su nombre'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _input('Correo electrónico', Icons.email),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingrese su correo electrónico';
                          }
                          final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
                          return ok ? null : 'Correo inválido';
                        },
                      ),
                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        decoration: _input('Contraseña', Icons.lock).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Ingrese su contraseña'
                            : null,
                      ),

                      const SizedBox(height: 24),

                      // Botón primario
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton(
                                onPressed: _registrarUsuario,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text('Registrar'),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // Botón secundario (contorneado)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _cancelar,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            side: BorderSide(color: primary, width: 1.2),
                            foregroundColor: primary,
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
