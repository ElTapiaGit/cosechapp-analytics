import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/Supabase_flutter.dart';
import '../../data/models/harvest_model.dart';
import '../../data/repositories/harvest_repository.dart';

class HarvestProvider extends ChangeNotifier {
  final HarvestRepository _repository = HarvestRepository();

  List<HarvestModel> _allHarvests = []; // Lista completa
  List<HarvestModel> _filteredHarvests = []; // Lista que se ve en pantalla
  bool _isLoading = true;

  // Variables de Filtro
  String? selectedZone;
  String? selectedProgrammer;
  String? selectedMonth; // Formato "MM-yyyy"

  List<HarvestModel> get harvests => _filteredHarvests;
  bool get isLoading => _isLoading;

  // Constructor: Carga datos al iniciar
  HarvestProvider() {
    loadHarvests();
  }

  // Listas para llenar los Dropdowns dinamicamente
  List<String> get availableZones => _allHarvests.map((e) => e.zoneName).toSet().toList();
  List<String> get availableProgrammers => _allHarvests.map((e) => e.programmer).toSet().toList();

  // Obtener meses unicos de corte (Ej: "12-2025")
  List<String> get availableMonths {
    final dates = _allHarvests.map((e) => e.cutDate).toSet().toList();
    dates.sort((a, b) => b.compareTo(a)); // Más recientes primero
    return dates.map((d) => DateFormat('MM-yyyy').format(d)).toSet().toList();
  }

  Future<void> loadHarvests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allHarvests = await _repository.getHarvests();
      applyFilters(); // Aplicar filtros iniciales
    } catch (e) {
      // ignore: avoid_print
      print("Error cargando cosechas: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Logica de Filtros (Buscador)
  void searchProducers(String query) {
    // Si hay búsqueda, reseteamos los dropdowns para no confundir
    selectedZone = null;
    selectedProgrammer = null;
    selectedMonth = null;

    if (query.isEmpty) {
      applyFilters();
    } else {
      _filteredHarvests = _allHarvests.where((h) {
        return h.producerName.toLowerCase().contains(query.toLowerCase()) ||
               h.dctoCode.contains(query);
      }).toList();
      notifyListeners();
    }
  }

  // Logica principal de filtrado
  void setFilter({String? zone, String? programmer, String? month}) {
    if (zone != null) selectedZone = (zone == 'Todos') ? null : zone;
    if (programmer != null) selectedProgrammer = (programmer == 'Todos') ? null : programmer;
    if (month != null) selectedMonth = (month == 'Todos') ? null : month;
    
    applyFilters();
  }

  void applyFilters() {
    DateTime? overdueLimit;
    if (selectedMonth == null || selectedMonth == 'Todos') {
      final now = DateTime.now();
      overdueLimit = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 5));
    }

    _filteredHarvests = _allHarvests.where((h) {
      final matchZone = selectedZone == null || h.zoneName == selectedZone;
      final matchProg = selectedProgrammer == null || h.programmer == selectedProgrammer;
      
      bool matchDate = true;
      if (selectedMonth != null && selectedMonth != 'Todos') {
        final hDate = DateFormat('MM-yyyy').format(h.cutDate);
        matchDate = hDate == selectedMonth;
      }

      bool matchOverdue = true;
      if (overdueLimit != null) {
        final targetDate = h.nextEstimatedDate;
        final normalizedTarget = DateTime(targetDate.year, targetDate.month, targetDate.day);
        matchOverdue = normalizedTarget.isAfter(overdueLimit) || normalizedTarget.isAtSameMomentAs(overdueLimit);
      }

      return matchZone && matchProg && matchDate && matchOverdue;
    }).toList();
    notifyListeners();
  }

  // Método para actualizar estado (Visita, Cosecha, Cancelación)
  Future<bool> updateStatus(int id, String newStatus, {String? observation}) async {
    try {
      // 1. Actualizar en Supabase
      final data = {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
        if (newStatus == 'VISITED') 'visit_date': DateTime.now().toIso8601String(),
        if (observation != null) 'observation': observation,
      };

      // Llamada directa a la tabla (puedes mover esto al repository si prefieres ser estricto)
      await Supabase.instance.client.from('harvest_records').update(data).eq('id', id);

      // 2. Recargar la lista para ver el cambio en pantalla
      await loadHarvests();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print("Error actualizando estado: $e");
      return false;
    }
  }
}