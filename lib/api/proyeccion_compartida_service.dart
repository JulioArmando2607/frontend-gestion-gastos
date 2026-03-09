import 'package:app_gestion_gastos/api/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProyeccionCompartidaService {
  ProyeccionCompartidaService({ApiService? apiService})
    : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<http.Response> getVerProyeccionCompartida(
    BuildContext context,
    int idProyeccion,
  ) {
    return _apiService.getVerProyeccionCompartida(context, idProyeccion);
  }

  Future<http.Response> getDetalleProyeccionCompartida(
    BuildContext context,
    int idProyeccion,
  ) {
    return _apiService.getDetalleProyeccionCompartida(context, idProyeccion);
  }

  Future<http.Response> listarProyeccionesRecibidas(
    BuildContext context, {
    required int idUsuario,
  }) {
    return _apiService.listarProyeccionesRecibidas(context, idUsuario: idUsuario);
  }

  Future<http.Response> compartirProyeccionPorCorreo(
    BuildContext context, {
    required int idProyeccionSeleccionada,
    required int ownerUserId,
    required int anio,
    required int mes,
    required String correo,
  }) {
    return _apiService.compartirProyeccionPorCorreo(
      context,
      idProyeccionSeleccionada: idProyeccionSeleccionada,
      ownerUserId: ownerUserId,
      anio: anio,
      mes: mes,
      correo: correo,
    );
  }

  Future<http.Response> listarProyeccionesEnviadas(
    BuildContext context, {
    required int ownerUserId,
  }) {
    return _apiService.listarProyeccionesEnviadas(context, ownerUserId: ownerUserId);
  }

  Future<http.Response> revocarCompartidoPorCorreo(
    BuildContext context, {
    required int ownerUserId,
    required int anio,
    required int mes,
    required String correo,
  }) {
    return _apiService.revocarCompartidoPorCorreo(
      context,
      ownerUserId: ownerUserId,
      anio: anio,
      mes: mes,
      correo: correo,
    );
  }

  Future<http.Response> editarMontoCategoriaCompartida(
    BuildContext context, {
    required int usuarioIdAccion,
    required int idProyeccion,
    required int idCategoria,
    required double montoCategoria,
  }) {
    return _apiService.editarMontoCategoriaCompartida(context, {
      'usuarioIdAccion': usuarioIdAccion,
      'idProyeccion': idProyeccion,
      'idCategoria': idCategoria,
      'montoCategoria': montoCategoria,
    });
  }
}
