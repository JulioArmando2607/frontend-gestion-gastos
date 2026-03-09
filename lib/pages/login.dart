import 'dart:convert';

import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:app_gestion_gastos/pages/crearCuenta.dart';
import 'package:app_gestion_gastos/pages/olvideContrasena.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'package:app_gestion_gastos/widgets/email_autocomplete_field.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _storage = const AppStorage();
  final ApiService service = ApiService();
  final storage = AppStorage();

  bool _isLoading = false;
  bool _obscure = true;
  bool _rememberMe = false;
  bool mostrarBtnReset = false;

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final email = normalizeEmailInput(_email.text);
        final response = await service.login({
          'email': email,
          'password': _pass.text,
        });

        if (response.statusCode == 200) {
          final token = jsonDecode(response.body)['token'];
          await storage.write(key: 'token', value: token);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al iniciar sesión: ${response.statusCode}'),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<bool> mostrarBotones(codigoBoton) async {
    setState(() => _isLoading = true);

    try {
      final response = await service.mostrarBotones(codigoBoton, context);
      return response.body.toLowerCase() == 'true';
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _crearCuenta() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CrearCuentaPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    _storage.read(key: 'email').then((v) {
      if (!mounted) return;
      if (v != null) {
        setState(() {
          _email.text = v;
          _rememberMe = true;
        });
      }
    });

    _validarBotones();
  }

  Future<void> _validarBotones() async {
    mostrarBtnReset = await mostrarBotones('BT001_RESET_PWD');
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF5B2EEA);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: purple,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Column(
                    children: [
                      Image.asset(
                        'assets/cashlylogoblnco.png',
                        height: 250,
                        color: Colors.white,
                        colorBlendMode: BlendMode.srcIn,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 24,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Inicio de sesión',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2A2A2A),
                            ),
                          ),
                          const SizedBox(height: 18),
                          EmailAutocompleteField(
                            controller: _email,
                            decoration: _inputDecoration(
                              hint: 'Correo electrónico',
                              icon: Icons.person_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu correo';
                              }
                              final ok = RegExp(
                                r'^[^@]+@[^@]+\.[^@]+',
                              ).hasMatch(normalizeEmailInput(v));
                              if (!ok) return 'Correo inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            decoration: _inputDecoration(
                              hint: 'Contraseña',
                              icon: Icons.lock_rounded,
                              suffix: IconButton(
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              if (v.length < 6) return 'Mínimo 6 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const Text('Recordarme'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 54,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.6,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Iniciar sesión'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              if (mostrarBtnReset)
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const OlvideContrasenaPage(),
                                      ),
                                    );
                                  },
                                  child: const Text('¿Olvidaste tu contraseña?'),
                                ),
                              TextButton(
                                onPressed: _crearCuenta,
                                child: const Text('¿No tienes cuenta? Regístrate'),
                              ),
                            ],
                          ),
                          const Divider(height: 28),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF6F6F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}
