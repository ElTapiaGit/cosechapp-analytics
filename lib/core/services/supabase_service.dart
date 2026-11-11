import 'package:supabase_flutter/Supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  // Patrón Singleton: Para tener una única instancia en toda la app
  static final SupabaseService _instance = SupabaseService._internal();
  
  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Cliente oficial de Supabase
  final SupabaseClient client = Supabase.instance.client;

  // Inicialización (se llama desde el main.dart)
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  // --- Metodos Helper para acceder a las tablas rapidamente ---
  
  // Tabla de Cosechas
  SupabaseQueryBuilder get harvests => client.from('harvest_records');
  
  // Tabla de Productores
  SupabaseQueryBuilder get producers => client.from('producers');
  
  // Tabla de Zonas
  SupabaseQueryBuilder get zones => client.from('zones');
  
  // Vista de Estadisticas (¡La magia de los graficos!)
  SupabaseQueryBuilder get quarterlyStats => client.from('quarterly_stats');
}