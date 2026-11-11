import 'package:flutter/foundation.dart';
import '../../data/models/stats_model.dart';
import '../../data/repositories/stats_repository.dart';

/// Provider reactivo para la gestión de estado analítico de CosechApp.
/// Desacopla la vista de la base de datos y gestiona los estados de carga y error en tiempo real.
class StatsProvider extends ChangeNotifier {
  final StatsRepository _repository = StatsRepository();

  bool _isLoading = true;
  bool _hasError = false;
  List<MonthlyStat> _monthlyData = [];
  List<ZoneStat> _zoneData = [];
  Map<String, dynamic> _kpis = {'total_producers': 0, 'harvests_month': 0};
  MonthlyStat? _selectedMonth;
  List<MonthlyStat> _availableMonths = [];

  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  List<MonthlyStat> get monthlyData => _monthlyData;
  List<ZoneStat> get zoneData => _zoneData;
  Map<String, dynamic> get kpis => _kpis;
  MonthlyStat? get selectedMonth => _selectedMonth;
  List<MonthlyStat> get availableMonths => _availableMonths;

  /// Carga inicial: consulta el histórico mensual y desencadena los filtros iniciales
  Future<void> loadInitialData() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final mData = await _repository.getMonthlyStats();
      _monthlyData = mData;
      _availableMonths = List.from(_monthlyData.reversed);
      await loadFilteredData(null);
    } catch (e) {
      debugPrint("Error en loadInitialData de StatsProvider: $e");
      _hasError = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga filtrada: consulta KPIs y distribución por zona para el mes seleccionado (o null para Global)
  Future<void> loadFilteredData(MonthlyStat? month) async {
    _isLoading = true;
    _hasError = false;
    _selectedMonth = month;
    notifyListeners();

    try {
      final int? year = _selectedMonth?.year;
      final int? monthNum = _selectedMonth?.month;

      final results = await Future.wait([
        _repository.getZoneDistribution(year: year, month: monthNum),
        _repository.getKpis(year: year, month: monthNum),
      ]);

      _zoneData = results[0] as List<ZoneStat>;
      _kpis = results[1] as Map<String, dynamic>;
      _isLoading = false;
      _hasError = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error en loadFilteredData de StatsProvider: $e");
      _hasError = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reintenta la carga en tiempo real tras pérdida de conexión
  Future<void> retry() async {
    await loadInitialData();
  }
}

