import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reconciliation_model.dart';

class ProjectionRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Obtiene el reporte de conciliación mensual directamente desde Supabase
  Future<List<ReconciliationModel>> getReconciliationReport(int year, int month) async {
    try {
      // Consulta directa a nuestra vista maestra en Supabase
      final response = await _supabase
          .from('monthly_reconciliation_report')
          .select()
          .eq('year', year)
          .eq('month', month);

      // Mapeamos la lista de JSON planos recibidos al modelo de Dart
      return (response as List)
          .map((json) => ReconciliationModel.fromJson(json))
          .toList();
    } catch (e) {
      // Elevamos el error para que el Provider lo capture y lo muestre en la UI
      throw Exception('Error al obtener el reporte de conciliación desde el servidor: $e');
    }
  }

  /// Actualiza de forma persistente la causa de pérdida de cosecha en Supabase
  Future<void> updateNoHarvestReason(int projectionId, String reason) async {
    try {
      // Modifica directamente la columna observation del registro planificado original
      await _supabase
          .from('harvest_records')
          .update({'observation': reason})
          .eq('id', projectionId);
    } catch (e) {
      throw Exception('Error al actualizar la causa de no-cosecha en Supabase: $e');
    }
  }
}