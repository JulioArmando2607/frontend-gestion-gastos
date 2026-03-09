import 'package:app_gestion_gastos/api/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProyeccionService {
  ProyeccionService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<http.Response> getObtenerCategoriasProyeccion(
    BuildContext context,
    int usuario,
    int anio,
    int mes,
  ) {
    return _apiService.getObtenerCategoriasProyeccion(context, usuario, anio, mes);
  }

  Future<http.Response> insertUpdateProyeccion(
    BuildContext context,
    int idUsuario,
    int anio,
    int mes,
    double ingreso,
    double totalGastoFinal,
    double ahorroEstimadoFinal,
  ) {
    return _apiService.insertUpdateProyeccion(
      context,
      idUsuario,
      anio,
      mes,
      ingreso,
      totalGastoFinal,
      ahorroEstimadoFinal,
    );
  }

  Future<dynamic> getObtenerDetalleProyeccion(
    BuildContext context,
    int idUsuario,
    int anio,
    int mes,
  ) {
    return _apiService.getObtenerDetalleProyeccion(context, idUsuario, anio, mes);
  }

  Future<http.Response> guardarProyeccionCategoria(
    BuildContext context,
    int idUsuario,
    dynamic body,
  ) {
    return _apiService.guardarProyeccionCategoria(context, idUsuario, body);
  }

  Future<http.Response> listarMisProyecciones(BuildContext context) {
    return _apiService.listarMisProyecciones(context);
  }

  Future<http.Response> cerrarProyeccion(
    BuildContext context,
    int idUsuario,
    int yearActual,
    int mesActual,
  ) {
    return _apiService.cerrarProyeccion(context, idUsuario, yearActual, mesActual);
  }

  Future<http.Response> editarMontoCategoriaProyeccion(
    BuildContext context,
    int idUsuario,
    Map<String, dynamic> body,
  ) {
    return _apiService.editarMontoCategoriaProyeccion(context, idUsuario, body);
  }
}
