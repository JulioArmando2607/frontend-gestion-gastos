import 'dart:convert';

import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/pages/home.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'package:app_gestion_gastos/widgets/email_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class EditarCuentaPage extends StatefulWidget {
  const EditarCuentaPage({super.key});

  @override
  State<EditarCuentaPage> createState() => _EditarCuentaPageState();
}

class _EditarCuentaPageState extends State<EditarCuentaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _celularController = TextEditingController();
  final _fechaNacimientoController = TextEditingController();
  final _preguntaRecuperacionController = TextEditingController();
  final _respuestaController = TextEditingController();

  final storage = AppStorage();
  final ApiService service = ApiService();

  bool _isLoading = false;
  bool _isFetchingUser = true;
  String nombre = '';
  int idUsuario = 0;
  int idPersona = 0;
  String email = '';

  @override
  void initState() {
    super.initState();
    obtenerDatosDesdeToken();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _celularController.dispose();
    _fechaNacimientoController.dispose();
    _preguntaRecuperacionController.dispose();
    _respuestaController.dispose();
    super.dispose();
  }

  Future<void> _registrarUsuario() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final body = <String, dynamic>{
      'nombre': _nombreController.text.trim(),
      'email': normalizeEmailInput(_emailController.text),
      'celular': _celularController.text.trim(),
      'fechaNacimiento': _fechaIsoDesdeInput(_fechaNacimientoController.text),
      'preguntaRecuperacion': _preguntaRecuperacionController.text.trim(),
      'respuestaRecuperacion': _respuestaController.text.trim(),
      'activo': 1,
      'id': idPersona,
      'usuarioId': idUsuario,
    };

    try {
      print(body);
      final response = await service.editarCuenta(context, idUsuario, body);
      if (!mounted) return;
        print(response.body);
        print("Respuesta de act");

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Datos personales actualizados.')),
        );
        await _cancelar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar (${response.statusCode}).')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al actualizar tus datos.')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> obtenerDatosDesdeToken() async {
    final token = await storage.read(key: 'token');

    if (token == null) {
      if (mounted) setState(() => _isFetchingUser = false);
      return;
    }

    final decodedToken = JwtDecoder.decode(token);
    setState(() {
      nombre = (decodedToken['nombre'] ?? '').toString();
      idUsuario = decodedToken['id'] as int? ?? 0;
      email = (decodedToken['sub'] ?? '').toString();
    });

    if (idUsuario > 0) {
      await getUsuario(idUsuario.toString());
    } else {
      if (mounted) setState(() => _isFetchingUser = false);
    }
  }

  Future<void> getUsuario(String id) async {
    try {
      final response = await service.usuario(context, id);
      print(response.body);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));

        if (!mounted) return;
        setState(() {
          nombre = (data['nombre'] as String?) ?? '';
          email = (data['email'] as String?) ?? '';
          idPersona = (data['id'] as int?) ?? 0;

          _nombreController.text = nombre;
          _emailController.text = email;

          _celularController.text = ((data['celular'] ?? data['telefono']) ?? '')
              .toString();
          _fechaNacimientoController.text =
              _fechaInputDesdeBackend((data['fechaNacimiento'] ?? data['fecha_nacimiento'])?.toString());
          _preguntaRecuperacionController.text =
              ((data['preguntaRecuperacion'] ?? data['pregunta_recuperacion']) ?? '')
                  .toString();
          _respuestaController.text =
              ((data['respuestaRecuperacion'] ?? data['respuesta_recuperacion']) ?? '')
                  .toString();
        });
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión expirada. Inicia sesión nuevamente.'),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${response.statusCode} al obtener usuario.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error inesperado.')),
      );
    } finally {
      if (mounted) setState(() => _isFetchingUser = false);
    }
  }

  Future<void> _pickFechaNacimiento() async {
    final now = DateTime.now();
    final initial =
        _parseFechaFlexible(_fechaNacimientoController.text) ?? DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (picked == null) return;

    _fechaNacimientoController.text = _formatDdMmYyyy(picked);
    setState(() {});
  }

  Future<void> _cancelar() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF5B2EEA);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: purple,
      appBar: AppBar(
        backgroundColor: purple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Datos personales'),
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                        'Actualizar datos personales',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2A2A2A),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _nombreController,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          hint: 'Nombre completo',
                          icon: Icons.person_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, ingresa tu nombre.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      EmailAutocompleteField(
                        controller: _emailController,
                        decoration: _fieldDecoration(
                          hint: 'Correo electrónico',
                          icon: Icons.mail_outline_rounded,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, ingresa tu correo electrónico.';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                              .hasMatch(normalizeEmailInput(value))) {
                            return 'Ingresa un correo electrónico válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _celularController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDecoration(
                          hint: 'Celular',
                          icon: Icons.phone_rounded,
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return 'Ingresa tu número de celular.';
                          if (v.length < 7) return 'Celular inválido.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _fechaNacimientoController,
                        readOnly: true,
                        onTap: _pickFechaNacimiento,
                        decoration: _fieldDecoration(
                          hint: 'Fecha de nacimiento',
                          icon: Icons.cake_rounded,
                        ).copyWith(
                          hintText: 'dd/mm/aaaa',
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) {
                            return 'Selecciona tu fecha de nacimiento.';
                          }
                          if (_parseFechaFlexible(v) == null) {
                            return 'Formato inválido. Usa dd/mm/aaaa.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _preguntaRecuperacionController,
                        textInputAction: TextInputAction.done,
                        decoration: _fieldDecoration(
                          hint: 'Pregunta de recuperación',
                          icon: Icons.help_rounded,
                        ).copyWith(
                          helperText:
                              'Esta pregunta se usa para ayudarte a recuperar tu contraseña.',
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) {
                            return 'Ingresa una pregunta de recuperación.';
                          }
                          if (v.length < 8) {
                            return 'La pregunta es muy corta.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _respuestaController,
                        textInputAction: TextInputAction.done,
                        decoration: _fieldDecoration(
                          hint: 'Respuesta de recuperación',
                          icon: Icons.help_rounded,
                        ).copyWith(
                          helperText:
                          'Esta respuesta se usa para ayudarte a recuperar tu contraseña.',
                        ),
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) {
                            return 'Ingresa una respuesta de recuperación.';
                          }
                          if (v.length < 3) {
                            return 'La respuesta es muy corta.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _registrarUsuario,
                          style: FilledButton.styleFrom(
                            backgroundColor: purple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.6,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Guardar cambios'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _isLoading ? null : _cancelar,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: Color(0xFFDDD7FF)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isFetchingUser)
            Positioned.fill(
              child: AbsorbPointer(
                child: Container(
                  color: Colors.black.withOpacity(0.18),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 10),
                        Text(
                          'Cargando datos...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF6F6F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}

DateTime? _parseFechaFlexible(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final iso = DateTime.tryParse(text);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  final parts = text.split('/');
  if (parts.length == 3) {
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d != null && m != null && y != null) {
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }
  }

  return null;
}

String _formatDdMmYyyy(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString();
  return '$d/$m/$y';
}

String _fechaInputDesdeBackend(String? raw) {
  final parsed = raw == null ? null : _parseFechaFlexible(raw);
  if (parsed == null) return '';
  return _formatDdMmYyyy(parsed);
}

String? _fechaIsoDesdeInput(String raw) {
  final parsed = _parseFechaFlexible(raw);
  if (parsed == null) return null;
  final y = parsed.year.toString().padLeft(4, '0');
  final m = parsed.month.toString().padLeft(2, '0');
  final d = parsed.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
