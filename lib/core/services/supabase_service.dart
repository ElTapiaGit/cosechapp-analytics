import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Patrón Singleton: Para tener una única instancia en toda la app
  static final SupabaseService _instance = SupabaseService._internal();
  
  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Cliente oficial de Supabase
  final SupabaseClient client = Supabase.instance.client;

  // --- Metodos Helper para acceder a las tablas rapidamente ---
  
  // Tabla de Cosechas
  SupabaseQueryBuilder get harvests => client.from('harvest_records');
}