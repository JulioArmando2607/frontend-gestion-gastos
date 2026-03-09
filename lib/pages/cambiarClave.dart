import 'package:app_gestion_gastos/api/services.dart';
import 'package:app_gestion_gastos/pages/home.dart';
import 'package:app_gestion_gastos/utils/app_storage.dart';
import 'package:app_gestion_gastos/widgets/email_autocomplete_field.dart';
import 'package:flutter/material.dart';

class EditarCuentaPage extends StatefulWidget {
  const EditarCuentaPage({super.key});

  @override
  State<EditarCuentaPage> createState() => _EditarCuentaPageState();
}

class _EditarCuentaPageState extends State<EditarCuentaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final storage = AppStorage();
  final ApiService service = ApiService();

  Future<void> _actualizarCuenta() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final response = await service.register({
        'nombre': _nombreController.text,
        'email': normalizeEmailInput(_emailController.text),
        'password': _passwordController.text,
      });
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta actualizada correctamente')),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la cuenta')),
        );
      }
    }
  }

  Future<void> _cancelar() async {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Cuenta'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu nombre';
                  }
                  return null;
                },
              ),
              EmailAutocompleteField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo electrónico'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa tu correo electrónico';
                  }
                  if (!RegExp(
                    r'^[^@]+@[^@]+\.[^@]+',
                  ).hasMatch(normalizeEmailInput(value))) {
                    return 'Ingresa un correo electrónico válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      child: ElevatedButton(
                        onPressed: _actualizarCuenta,
                        child: const Text('Guardar cambios'),
                      ),
                    ),
              ElevatedButton(onPressed: _cancelar, child: const Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
  }
}
