// se encargara de consultar las Vistas SQL
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../models/stats_model.dart';

class StatsRepository {
  final _supabase = SupabaseService();

  // Obtener rendimiento mensual (Vista SQL)
  // No recibe filtros porque el grafico de barras SIEMPRE debe mostrar la tendencia historica
  Future<List<MonthlyStat>> getMonthlyStats() async {
    final response = await _supabase.client
        .from('monthly_stats')
        .select()
        .not('year', 'is', null)
        // Ordenamos cronológicamente para el gráfico (Ene -> Dic)
        .order('year', ascending: true) 
        .order('month', ascending: true);

    return (response as List)
        .map((e) => MonthlyStat.fromJson(e))
        .where((stat) => stat.year > 0) // Doble protección en Dart
        .toList();
  }

  // Obtener distribucion por zonas (Vista SQL)
  Future<List<ZoneStat>> getZoneDistribution({int? year, int? month}) async {
    var query = _supabase.client.from('stats_zone_distribution').select();
    
    // Si el usuario seleccionó un mes específico, filtramos en Supabase
    if (year != null && month != null) {
      query = query.eq('year', year).eq('month', month);
    }

    final response = await query;

    // Si el usuario selecciono "Todos", la vista nos traera la zona repetida por cada mes.
    // Necesitamos agruparla y sumarla aqui para el grafico de Dona.
    Map<String, ZoneStat> grouped = {};
    for (var row in response as List) {
      final zoneName = row['zone_name'];
      final qty = (row['total_quantity'] ?? 0).toDouble();
      final rec = (row['total_received'] ?? 0).toDouble();
      
      if (grouped.containsKey(zoneName)) {
        // Sumamos al acumulado
        grouped[zoneName] = ZoneStat(
          zoneName: zoneName, 
          totalQuantity: grouped[zoneName]!.totalQuantity + qty, 
          totalReceived: grouped[zoneName]!.totalReceived + rec
        );
      } else {
        // Creamos el registro inicial
        grouped[zoneName] = ZoneStat(zoneName: zoneName, totalQuantity: qty, totalReceived: rec);
      }
    }

    final list = grouped.values.toList();
    list.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity)); // Ordenar mayor a menor
    return list;
  }

  // Obtener KPI rapidos 
  Future<Map<String, dynamic>> getKpis({int? year, int? month}) async {
    // Total Productores Activos
    final prodResponse = await _supabase.client
        .from('producers')
        .select('id')
        .eq('is_active', true)
        .count(CountOption.exact);
    final int countProd = prodResponse.count;
    
    // 1. Iniciamos la consulta base SIN el count todavía
    var query = _supabase.client.from('harvest_records').select('id');

    // 2. Aplicamos los filtros de fecha si el usuario seleccionó un mes
    if (year != null && month != null) {
      final startStr = DateTime(year, month, 1).toIso8601String();
      final nextMonth = month == 12 ? 1 : month + 1;
      final nextYear = month == 12 ? year + 1 : year;
      final endStr = DateTime(nextYear, nextMonth, 1).toIso8601String();
      
      query = query.gte('processed_date', startStr).lt('processed_date', endStr);
    }

    // 3. Agregamos el COUNT justo al momento de ejecutar la consulta
    final harvestResponse = await query.count(CountOption.exact);
    final int countHarvest = harvestResponse.count;

    return {
      'total_producers': countProd,
      'harvests_month': countHarvest,
    };
  }
}