import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/production_summary_model.dart';
import '../../data/models/zone_distribution_model.dart';

class QuarterlyDashboardProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _selectedYear = DateTime.now().year;
  int get selectedYear => _selectedYear;

  int _selectedQuarter = (DateTime.now().month / 3).ceil();
  int get selectedQuarter => _selectedQuarter;

  List<ProductionSummaryModel> _currentQuarterProduction = [];
  List<ProductionSummaryModel> get currentQuarterProduction => _currentQuarterProduction;

  List<ProductionSummaryModel> _previousQuarterProduction = [];
  List<ProductionSummaryModel> get previousQuarterProduction => _previousQuarterProduction;

  List<ZoneDistributionModel> _currentQuarterZones = [];
  List<ZoneDistributionModel> get currentQuarterZones => _currentQuarterZones;

  // KPIs Calculados
  double get totalProcessed {
    return _currentQuarterProduction.fold(0.0, (sum, item) => sum + item.cantidadProcesada);
  }

  double get previousTotalProcessed {
    return _previousQuarterProduction.fold(0.0, (sum, item) => sum + item.cantidadProcesada);
  }

  double get totalReceived {
    return _currentQuarterProduction.fold(0.0, (sum, item) => sum + item.cantidadCogollos);
  }

  double get totalRejected {
    return _currentQuarterProduction.fold(0.0, (sum, item) => sum + item.descarte);
  }

  double get efficiency {
    if (totalReceived == 0) return 0.0;
    return (totalProcessed / totalReceived) * 100.0;
  }

  double get variancePercentage {
    if (previousTotalProcessed == 0) return totalProcessed > 0 ? 100.0 : 0.0;
    return ((totalProcessed - previousTotalProcessed) / previousTotalProcessed) * 100.0;
  }

  void setFilter(int year, int quarter) {
    if (_selectedYear == year && _selectedQuarter == quarter) return;
    _selectedYear = year;
    _selectedQuarter = quarter;
    fetchData();
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final targetMonths = _getMonthsForQuarter(_selectedQuarter);
      final previousQuarterInfo = _getPreviousQuarterInfo(_selectedYear, _selectedQuarter);
      final prevMonths = _getMonthsForQuarter(previousQuarterInfo['quarter']!);

      // Fetch current quarter production
      final currentProdResponse = await _supabase
          .from('production_summary_report')
          .select()
          .eq('year', _selectedYear)
          .inFilter('month', targetMonths);

      _currentQuarterProduction = (currentProdResponse as List)
          .map((e) => ProductionSummaryModel.fromJson(e))
          .toList();

      // Fetch previous quarter production
      final prevProdResponse = await _supabase
          .from('production_summary_report')
          .select()
          .eq('year', previousQuarterInfo['year']!)
          .inFilter('month', prevMonths);

      _previousQuarterProduction = (prevProdResponse as List)
          .map((e) => ProductionSummaryModel.fromJson(e))
          .toList();

      // Fetch current quarter zones
      final currentZonesResponse = await _supabase
          .from('stats_zone_distribution')
          .select()
          .eq('year', _selectedYear)
          .inFilter('month', targetMonths);

      _currentQuarterZones = (currentZonesResponse as List)
          .map((e) => ZoneDistributionModel.fromJson(e))
          .toList();

    } catch (e) {
      _errorMessage = 'Error al cargar datos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<int> _getMonthsForQuarter(int quarter) {
    switch (quarter) {
      case 1: return [1, 2, 3];
      case 2: return [4, 5, 6];
      case 3: return [7, 8, 9];
      case 4: return [10, 11, 12];
      default: return [];
    }
  }

  Map<String, int> _getPreviousQuarterInfo(int year, int quarter) {
    if (quarter == 1) {
      return {'year': year - 1, 'quarter': 4};
    }
    return {'year': year, 'quarter': quarter - 1};
  }

  // Agrupadores para gráficas
  List<double> get monthlyProductionTrend {
    final months = _getMonthsForQuarter(_selectedQuarter);
    return months.map((m) {
      final monthlyData = _currentQuarterProduction.where((item) => item.month == m);
      return monthlyData.fold(0.0, (sum, item) => sum + item.cantidadProcesada);
    }).toList();
  }

  List<double> get trendData => monthlyProductionTrend;

  Map<String, double> get zoneDistributionMap {
    final map = <String, double>{};
    for (var item in _currentQuarterZones) {
      map[item.zoneName] = (map[item.zoneName] ?? 0) + item.totalQuantity;
    }
    return map;
  }

  Map<String, double> get programmerPerformanceMap {
    final map = <String, double>{};
    for (var item in _currentQuarterProduction) {
      map[item.extensionista] = (map[item.extensionista] ?? 0) + item.cantidadProcesada;
    }
    return map;
  }
}
