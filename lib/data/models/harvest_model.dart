import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../core/theme/app_colors.dart';

part 'harvest_model.g.dart'; 

@HiveType(typeId: 0)
class HarvestModel extends HiveObject {
  
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int producerId;

  @HiveField(2)
  final String producerName;

  @HiveField(3)
  final String zoneName;

  @HiveField(4)
  final String dctoCode;

  @HiveField(5)
  final DateTime cutDate;

  @HiveField(6)
  final DateTime nextEstimatedDate;

  @HiveField(7)
  String status;

  @HiveField(8)
  String? observation;

  @HiveField(9)
  final int cycleMonths;

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

  // --- LÓGICA DE ESTADO DINÁMICO BASADO EN FECHAS ---

  DateTime get _normalizedToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _normalizedTarget => DateTime(
    nextEstimatedDate.year,
    nextEstimatedDate.month,
    nextEstimatedDate.day,
  );

  /// Indica si la fecha actual ya alcanzó o superó la fecha programada
  bool get isReadyForHarvest => !_normalizedToday.isBefore(_normalizedTarget);

  /// Retorna la cantidad de días restantes (positivo: faltan días; negativo: atrasado)
  int get daysRemaining => _normalizedTarget.difference(_normalizedToday).inDays;

  /// Estado dinámico de negocio: "POR COSECHAR" o "PRÓXIMA COSECHA"
  String get computedStatus {
    return isReadyForHarvest ? "POR COSECHAR" : "PRÓXIMA COSECHA";
  }

  /// Color semántico según la regla temporal
  Color get statusColor {
    return isReadyForHarvest ? AppColors.statusCancelled : AppColors.primaryGreen;
  }

  /// Color de fondo con transparencia para badges y chips
  Color get statusBgColor {
    return statusColor.withValues(alpha: 0.1);
  }

  // --- Conversión desde Supabase (JSON) ---
  factory HarvestModel.fromJson(Map<String, dynamic> json) {
    String zonaSegura = 'Sin Zona';
    try {
      if (json['producers'] != null && json['producers']['zones'] != null) {
        zonaSegura = json['producers']['zones']['name'] ?? 'Sin Zona';
      }
    } catch (_) {}

    return HarvestModel(
      id: json['id'] ?? 0,
      producerId: json['producer_id'] ?? 0,
      producerName: json['producers'] != null ? (json['producers']['full_name'] ?? 'Desconocido') : 'Desconocido',
      zoneName: zonaSegura,
      dctoCode: json['dcto_code']?.toString() ?? '',
      cutDate: DateTime.tryParse(json['cut_date']?.toString() ?? '') ?? DateTime.now(),
      nextEstimatedDate: DateTime.tryParse(json['next_estimated_date']?.toString() ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'PENDING',
      observation: json['observation'],
      cycleMonths: json['cycle_months'] ?? 4,
      programmer: json['programmer']?.toString() ?? 'General',
    );
  }
}
