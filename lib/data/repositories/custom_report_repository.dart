import 'package:supabase_flutter/supabase_flutter.dart';

/// Repositorio encargado de la comunicación con Supabase para el reporte personalizado.
class CustomReportRepository {
  late final SupabaseClient _supabase;

  CustomReportRepository({SupabaseClient? client}) {
    if (client != null) {
      _supabase = client;
    } else {
      try {
        _supabase = Supabase.instance.client;
      } catch (_) {
        // En entorno de tests unitarios donde Supabase.instance no ha sido inicializado
      }
    }
  }

  /// Ejecuta la función RPC 'get_custom_report_data' en Supabase y retorna el resultado.
  Future<Map<String, dynamic>> getReportData(
    String startDate,
    String endDate,
    String metricColumn,
  ) async {
    final response = await _supabase.rpc(
      'get_custom_report_data',
      params: {
        'start_date': startDate,
        'end_date': endDate,
        'metric_column': metricColumn,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    } else if (response != null) {
      return {'data': response};
    }
    return <String, dynamic>{};
  }
}
