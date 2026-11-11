import 'package:flutter/material.dart';
import '../../data/models/reconciliation_model.dart';
import '../../data/repositories/projection_repository.dart';

class ProjectionProvider extends ChangeNotifier {
  final ProjectionRepository _repository = ProjectionRepository();

  List<ReconciliationModel> _reportItems = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Filtros de fecha inicializados en el periodo actual
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  // Getters públicos para consumo de las Screens
  List<ReconciliationModel> get reportItems => _reportItems;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get selectedYear => _selectedYear;
  int get selectedMonth => _selectedMonth;

  // CÁLCULO DE KPIs EN TIEMPO REAL

  /// KPI 1: Total Cosechado Real (Logrado) 
  double get totalLogrado => _reportItems.fold(0.0, (sum, item) => sum + item.cantidadRecepcion);
  /// KPI 2: Total Proyectado (Meta del Mes) 
  double get totalProyectado => _reportItems.fold(0.0, (sum, item) => sum + item.cantidadProyeccionHistorica);
  
  /// KPI 3: Volumen Faltante / Brecha de perdida en campo
  double get totalFaltante {
    final diferencia = totalProyectado - totalLogrado;
    return diferencia > 0 ? diferencia : 0.0;
  }

  /// KPI 4: Cantidad No Cosechada (Suma de metas de productores FALTANTES)
  double get totalNoCosechado => _reportItems.isEmpty 
      ? 0.0 
      : _reportItems.first.totalNoCosechado;

  /// KPI 5: Porcentaje de Cobertura Real 
  double get porcentajeCobertura {
    if (totalProyectado == 0) return 0.0;
    return (totalLogrado / totalProyectado) * 100;
  }

  /// KPI 5: Volumen procesado real de INESPERADO
  double get totalInesperado => _reportItems.isEmpty 
      ? 0.0 
      : _reportItems.first.totalInesperado;

  // ACCIONES DE LA CAPA LÓGICA

  /// Carga la matriz de conciliación mensual 
  Future<void> fetchReport(int year, int month) async {
    _selectedYear = year;
    _selectedMonth = month;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reportItems = await _repository.getReconciliationReport(year, month);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza de forma reactiva y optimista la causa de pérdida elegida por el ingeniero
  Future<bool> updateNoHarvestReason(int projectionId, String reason) async {
    final index = _reportItems.indexWhere((item) => item.projectionId == projectionId);
    if (index == -1) return false;

    // Resguardo para Fallback en caso de error de red
    final oldObservation = _reportItems[index].observaciones;

    // Modificación Optimista inmediata
    _reportItems[index] = _reportItems[index].copyWith(observaciones: reason);
    notifyListeners();

    try {
      await _repository.updateNoHarvestReason(projectionId, reason);
      return true;
    } catch (e) {
      // Rollback si la base de datos rechaza la transacción
      _reportItems[index] = _reportItems[index].copyWith(observaciones: oldObservation);
      notifyListeners();
      return false;
    }
  }
}