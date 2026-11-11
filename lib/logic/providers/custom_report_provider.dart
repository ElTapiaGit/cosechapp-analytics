import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../data/repositories/custom_report_repository.dart';

/// Provider para la gestión del estado, filtros y consulta del Generador de Reportes Personalizado.
class CustomReportProvider extends ChangeNotifier {
  final CustomReportRepository _repository = CustomReportRepository();

  // --- Variables de Estado ---
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedMetric = 'C.PROC';
  String? _selectedDimension = 'Zonas';
  bool _isLoading = false;

  /// Almacena el resultado devuelto por la función RPC de Supabase
  Map<String, dynamic>? reportData;

  /// Controla si el panel de filtros está expandido o colapsado
  bool _isFilterExpanded = true;

  /// Mensaje de error en caso de fallo en la consulta
  String? errorMessage;

  // --- Getters Públicos ---
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get selectedMetric => _selectedMetric;
  String? get selectedDimension => _selectedDimension;
  bool get isLoading => _isLoading;
  bool get isFilterExpanded => _isFilterExpanded;

  // --- Opciones de Métricas (Mapeo Técnico <-> Etiqueta de Negocio) ---
  static const Map<String, String> metricKeyToLabel = {
    'C.PROC': 'Volumen Procesado',
    'C.RECEP': 'Volumen Recepcionado',
    'C.RECH': 'Cantidad Rechazada',
  };

  static const Map<String, String> metricLabelToKey = {
    'Volumen Procesado': 'C.PROC',
    'Volumen Recepcionado': 'C.RECEP',
    'Volumen Recibido': 'C.RECEP', // Soporte retrocompatible
    'Cantidad Rechazada': 'C.RECH',
  };

  static const List<String> availableMetrics = [
    'Volumen Procesado',
    'Volumen Recepcionado',
    'Cantidad Rechazada',
  ];

  static const List<String> availableDimensions = [
    'Zonas',
    'Programadores',
    'Evolución Mensual',
  ];

  /// Devuelve el texto legible de la métrica actualmente seleccionada
  String get selectedMetricLabel {
    return metricKeyToLabel[_selectedMetric] ?? _selectedMetric ?? 'Volumen Procesado';
  }

  /// Retorna un texto formateado del rango de fechas si ambas están definidas
  String? get formattedDateRange {
    if (_startDate == null || _endDate == null) return null;
    final formatter = DateFormat('dd/MM/yyyy');
    return '${formatter.format(_startDate!)} - ${formatter.format(_endDate!)}';
  }

  /// Alterna la visibilidad del panel de filtros
  void toggleFilters() {
    _isFilterExpanded = !_isFilterExpanded;
    notifyListeners();
  }

  /// Establece explícitamente el estado de expansión de los filtros
  void setFilterExpanded(bool expanded) {
    _isFilterExpanded = expanded;
    notifyListeners();
  }

  // --- Métodos de Actualización de Estado ---

  /// Actualiza las fechas de inicio y fin del reporte
  void setDates(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  /// Actualiza la métrica a evaluar.
  /// Acepta tanto el código técnico ('C.PROC') como la etiqueta visual ('Volumen Procesado').
  void setMetric(String? metric) {
    if (metric == null) {
      _selectedMetric = null;
    } else if (metricLabelToKey.containsKey(metric)) {
      _selectedMetric = metricLabelToKey[metric];
    } else {
      _selectedMetric = metric;
    }
    notifyListeners();
  }

  /// Actualiza la dimensión de agrupación (Zonas, Programadores, Evolución Mensual)
  void setDimension(String? dimension) {
    _selectedDimension = dimension;
    notifyListeners();
  }

  /// Ejecuta la consulta RPC a Supabase con los parámetros seleccionados
  Future<void> generateReport() async {
    if (_startDate == null || _endDate == null) {
      errorMessage = 'Debes seleccionar un rango de fechas para generar el reporte.';
      notifyListeners();
      return;
    }

    if (_isLoading) return;

    _isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Mapeo visual de la métrica a la columna de BD
      String mappedMetric;
      final metric = selectedMetricLabel;
      if (metric == 'Volumen Recepcionado' || metric == 'Volumen Recibido' || _selectedMetric == 'C.RECEP') {
        mappedMetric = 'quantity_received';
      } else if (metric == 'Cantidad Rechazada' || _selectedMetric == 'C.RECH') {
        mappedMetric = 'quantity_rejected';
      } else {
        mappedMetric = 'quantity_processed';
      }

      final startFormatted = _startDate!.toIso8601String().split('T')[0];
      final endFormatted = _endDate!.toIso8601String().split('T')[0];

      final response = await _repository.getReportData(
        startFormatted,
        endFormatted,
        mappedMetric,
      );

      reportData = response;

      // Ocultar los filtros automáticamente al obtener resultados
      _isFilterExpanded = false;
    } catch (e) {
      errorMessage = e.toString();
      debugPrint('Error al ejecutar RPC get_custom_report_data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene la lista correspondiente de la dimensión seleccionada (by_zone, by_programmer, monthly_trend)
  List<Map<String, dynamic>> get currentDimensionList {
    if (reportData == null) return [];
    dynamic rawList;
    switch (_selectedDimension) {
      case 'Zonas':
        rawList = reportData!['by_zone'];
        break;
      case 'Programadores':
        rawList = reportData!['by_programmer'];
        break;
      case 'Evolución Mensual':
        rawList = reportData!['monthly_trend'];
        break;
      default:
        rawList = reportData!['by_zone'];
    }

    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  /// Retorna el total global obtenido del RPC
  num get globalTotal {
    if (reportData == null) return 0;
    final val = reportData!['global_total'];
    if (val is num) return val;
    return num.tryParse(val?.toString() ?? '0') ?? 0;
  }

  /// Restablece los filtros a sus valores predeterminados
  void resetFilters() {
    _startDate = null;
    _endDate = null;
    _selectedMetric = 'C.PROC';
    _selectedDimension = 'Zonas';
    _isLoading = false;
    _isFilterExpanded = true;
    reportData = null;
    errorMessage = null;
    notifyListeners();
  }
}
