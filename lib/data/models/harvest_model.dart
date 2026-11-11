/*
 * Este código hace 3 cosas a la vez:
 * Define los datos.
 * Prepara el guardado offline (Hive).
 * Prepara la lectura de la nube (Supabase).
 */
import 'package:hive/hive.dart';

// Esta línea es OBLIGATORIA para que Hive genere el código binario
part 'harvest_model.g.dart'; 

@HiveType(typeId: 0) // typeId único para esta clase
class HarvestModel extends HiveObject {
  
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int producerId;

  @HiveField(2)
  final String producerName; // Guardamos el nombre aquí para no hacer consultas extra offline

  @HiveField(3)
  final String zoneName; // Igual con la zona

  @HiveField(4)
  final String dctoCode;

  @HiveField(5)
  final DateTime cutDate; // Fecha Corte (Histórica)

  @HiveField(6)
  final DateTime nextEstimatedDate; // Próxima Cosecha (Calculada)

  @HiveField(7)
  String status; // 'PENDING', 'TO_VISIT', 'VISITED', 'HARVESTED', 'CANCELLED'

  @HiveField(8)
  String? observation;

  @HiveField(9)
  final int cycleMonths; // 3 o 4

  @HiveField(10) 
  final String programmer; 

  HarvestModel({
    required this.id,
    required this.producerId,
    required this.producerName,
    required this.zoneName,
    required this.dctoCode,
    required this.cutDate,
    required this.nextEstimatedDate,
    required this.status,
    this.observation,
    required this.cycleMonths,
    required this.programmer,
  });

  // --- Logica Visual (Getters) ---
  
  // Calcula si es urgente (Faltan 7 días o menos y no se ha visitado)
  bool get isUrgent {
    if (status != 'PENDING' && status != 'TO_VISIT') return false;
    final daysLeft = nextEstimatedDate.difference(DateTime.now()).inDays;
    return daysLeft <= 7;
  }

  // --- Conversion desde Supabase (JSON) ---
  factory HarvestModel.fromJson(Map<String, dynamic> json) {
    // Extraccion segura del nombre de zona
    String zonaSegura = 'Sin Zona';
    
    try {
      if (json['producers'] != null && json['producers']['zones'] != null) {
        zonaSegura = json['producers']['zones']['name'];
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error parseando zona: $e");
    }

    return HarvestModel(
      id: json['id'] ?? 0,
      producerId: json['producer_id'] ?? 0,
      // Supabase devuelve objetos anidados cuando hacemos joins
      producerName: json['producers'] != null ? json['producers']['full_name'] : 'Desconocido',
      zoneName: zonaSegura,
      dctoCode: json['dcto_code']?.toString() ?? '',
      cutDate: DateTime.parse(json['cut_date']),
      nextEstimatedDate: DateTime.parse(json['next_estimated_date']),
      status: json['status'] ?? 'PENDING',
      observation: json['observation'],
      cycleMonths: json['cycle_months'] ?? 4,
      // Mapeamos el programador (si viene null, ponemos 'General')
      programmer: json['programmer']?.toString() ?? 'General',
    );
  }
}
