/*
 * Codigo para automatizar si leer la nube o de local
 * funciona como cerebro, prioriza la Nube
 * pero usa local si falla(sin internet) y restaura los datos si se borraron
 */
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/storage_service.dart';
import '../models/harvest_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HarvestRepository {
  final _supabase = SupabaseService();
  final _supabaseClient = Supabase.instance.client; //operaciones nuevas de la pantalla Subir
  final _storage = StorageService();

  // Obtener Cosechas (Lógica Inteligente)
  Future<List<HarvestModel>> getHarvests() async {
    // 1. Verificar si hay Internet
    final connectivityResult = await Connectivity().checkConnectivity();
    final hasInternet = !connectivityResult.contains(ConnectivityResult.none);

    if (hasInternet) {
      try {
        // ignore: avoid_print
        print("🌐 Conexión detectada: Descargando de Supabase...");
        return await _fetchFromCloudAndSync();
      } catch (e, stacktrace) {
        // ignore: avoid_print
        print("🔥 ERROR CRÍTICO EN NUBE: $e");
        // ignore: avoid_print
        print("📍 Stacktrace: $stacktrace");
        //print("⚠️ Error en Nube: $e. Usando datos locales.");
        return _fetchFromLocal();
      }
    } else {
      // ignore: avoid_print
      print("📴 Modo Offline: Cargando desde Hive...");
      return _fetchFromLocal();
    }
  }

  // A. Estrategia: Nube -> Local -> UI
  Future<List<HarvestModel>> _fetchFromCloudAndSync() async {
    // 1. Pedir datos a Supabase (Hacemos JOIN con Productores y Zonas)
    final response = await _supabase.harvests.select('''
      *,
      producers (
        id,
        full_name,
        zones ( name )
      )
    ''').order('cut_date', ascending: true); // Ordenamos por fecha

    // DEBUG: Imprimir la respuesta cruda para ver si llega vacía
    final dataList = response as List<dynamic>;
    // ignore: avoid_print
    print("📦 DATOS RECIBIDOS DE SUPABASE: ${dataList.length} registros");
    
    if (dataList.isNotEmpty) {
      // ignore: avoid_print
      print("🔍 Ejemplo del primer registro: ${dataList.first}");
    } else {
      // ignore: avoid_print
      print("⚠️ ALERTA: Supabase devolvió una lista vacía []. Revisa RLS (Permisos).");
    }

    // 2. Convertir JSON a Lista de Objetos
    final List<HarvestModel> harvestsFromCloud = (response as List)
        .map((json) => HarvestModel.fromJson(json))
        .toList();

    // 3. ACTUALIZAR HIVE (Sincronización con ventana rotativa de 5 meses)
    final retentionThreshold = DateTime.now().subtract(const Duration(days: 150));
    final filteredHarvests = harvestsFromCloud.where((h) {
      return h.cutDate.isAfter(retentionThreshold) || h.cutDate.isAtSameMomentAs(retentionThreshold);
    }).toList();

    await _storage.harvestBox.clear(); 
    await _storage.harvestBox.addAll(filteredHarvests);
    
    // ignore: avoid_print
    print("✅ Sincronización completada: ${filteredHarvests.length} registros guardados en local (ventana de 5 meses).");
    return harvestsFromCloud;
  }

  // B. Estrategia: Solo Local
  List<HarvestModel> _fetchFromLocal() {
    // Devuelve lo que haya en la cajita de Hive
    if (_storage.harvestBox.isEmpty) {
      // ignore: avoid_print
      print("📭 La caja local está vacía.");
      return [];
    }
    // ignore: avoid_print
    print("📂 Cargando ${_storage.harvestBox.length} registros locales.");
    return _storage.harvestBox.values.toList();
  }

  // MÉTODOS EXCLUSIVOS ADICIONADOS PARA LA PANTALLA DE PROYECCIONES (WEB UPLOAD)

  Future<List<Map<String, dynamic>>> checkExistingRecords(String startDate, String endDate) async {
    return await _supabaseClient
        .from('harvest_records')
        .select('id')
        .gte('processed_date', startDate)
        .lt('processed_date', endDate) // Menor estricto que el día 1 del siguiente mes
        .limit(1);
  }

  Future<void> deleteOldRecords(String startDate, String endDate) async {
    await _supabaseClient
        .from('harvest_records')
        .delete()
        .gte('processed_date', startDate)
        .lt('processed_date', endDate);
  }

  Future<void> upsertZones(List<Map<String, dynamic>> zonesToInsert) async {
    await _supabaseClient.from('zones').upsert(zonesToInsert, onConflict: 'name', ignoreDuplicates: true);
  }

  Future<List<Map<String, dynamic>>> selectZones() async {
    return await _supabaseClient.from('zones').select('id, name');
  }

  Future<void> upsertProducers(List<Map<String, dynamic>> producersToInsert) async {
    await _supabaseClient.from('producers').upsert(producersToInsert, onConflict: 'full_name, zone_id', ignoreDuplicates: true);
  }

  Future<List<Map<String, dynamic>>> selectProducers() async {
    return await _supabaseClient.from('producers').select('id, full_name, zone_id');
  }

  Future<void> insertHarvestRecords(List<Map<String, dynamic>> harvestPayload) async {
    await _supabaseClient.from('harvest_records').insert(harvestPayload);
  }
}