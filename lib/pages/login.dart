import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/pages/crearCuenta.dart';
import 'package:app_gestion_gastos/pages/Dashboard/DashboardPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final ApiService service = ApiService();
  final storage = FlutterSecureStorage();

  bool _isLoading = false;
  bool _obscure = true;
  bool _rememberMe = false;

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      try {
        final response = await service.login({
          'email': _email.text,
          'password': _pass.text,
        });

        if (response.statusCode == 200) {
          final token = jsonDecode(response.body)['token'];
          await storage.write(key: 'token', value: token);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => DashboardPage()),
          );

      /*    ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Login exitoso')));*/
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al iniciar sesión: ${response.statusCode}'),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _crearCuenta() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => CrearCuentaPage()),
    );
  }

  @override
  void initState() {
    super.initState();
    _storage.read(key: 'email').then((v) {
      if (v != null) {
        setState(() {
          _email.text = v;
          _rememberMe = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF5B2EEA); // morado principal
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
                  // Logo + marca
                  Column(
                    children: [
                      // Usa tu asset si lo tienes: Image.asset('assets/cashly_logo.png', height: 72)
                      Image.asset(
                        'assets/cashlylogoblnco.png',
                        height: 250,
                        color: Colors.white, // Aplica el color blanco
                        colorBlendMode:
                            BlendMode.srcIn, // Mantiene la transparencia
                      ),
                      /*Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 90,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cashly+',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),*/
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Card blanca
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

                          // Email
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(
                              hint: 'Correo electrónico',
                              icon: Icons.person_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa tu correo';
                              }
                              final ok = RegExp(
                                r'^[^@]+@[^@]+\.[^@]+',
                              ).hasMatch(v);
                              if (!ok) return 'Correo inválido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _pass,
                            obscureText: _obscure,
                            decoration: _inputDecoration(
                              hint: 'Contraseña',
                              icon: Icons.lock_rounded,
                              suffix: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
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

                          // Recordarme
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const Text('Recordarme'),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Botón principal
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

                          // Enlaces
                          Column(
                            children: [
                            /*  TextButton(
                                onPressed: () {}, // TODO: recuperar
                                child: const Text('¿Olvidaste tu contraseña?'),
                              ),*/
                              TextButton(
                                onPressed: () {
                                  _crearCuenta();
                                  // TODO: Navigator.pushReplacement(... CrearCuentaPage());
                                },
                                child: const Text(
                                  '¿No tienes cuenta? Regístrate',
                                ),
                              ),
                            ],
                          ),

                          const Divider(height: 28),

                          // Botón Google (solo UI)
                          /*  SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {}, // TODO: Google sign-in opcional
                              icon: const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 28,
                              ),
                              label: const Text('Continuar con Google'),
                            ),
                          ), */
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
