class ReconciliationModel {
  final int year;
  final int month;
  final int? projectionId;
  final int? actualId;
  final int producerId;
  final String productor;
  final String zona;
  final String programador;
  final String? dctoCode;
  final double cantidadRecepcion; // C.RECEP
  final double cantidadProyeccionHistorica; // Meta basada ahora en C.RECEP
  final String statusReconciliacion; // 'OK', 'FALTANTE', 'INESPERADO'
  final String? observaciones;
  final double totalNoCosechado;
  final double totalInesperado;

  ReconciliationModel({
    required this.year,
    required this.month,
    this.projectionId,
    this.actualId,
    required this.producerId,
    required this.productor,
    required this.zona,
    required this.programador,
    this.dctoCode,
    required this.cantidadRecepcion,
    required this.cantidadProyeccionHistorica,
    required this.statusReconciliacion,
    this.observaciones,
    required this.totalNoCosechado,
    required this.totalInesperado,
  });

  /// Mapea el JSON plano de la vista de Supabase a la entidad fuertemente tipada de Dart
  factory ReconciliationModel.fromJson(Map<String, dynamic> json) {
    return ReconciliationModel(
      year: json['year'] as int? ?? 0,
      month: json['month'] as int? ?? 0,
      projectionId: json['projection_id'] as int?,
      actualId: json['actual_id'] as int?,
      producerId: json['producer_id'] as int? ?? 0,
      productor: json['productor'] as String? ?? 'Sin Nombre',
      zona: json['zona'] as String? ?? 'Sin Zona',
      programador: json['programador'] as String? ?? 'Sin Asignar',
      dctoCode: json['dcto_code'] as String?,
      cantidadRecepcion: (json['cantidad_recepcion'] as num? ?? 0.0).toDouble(),
      cantidadProyeccionHistorica: (json['cantidad_proyeccion_historica'] as num? ?? 0.0).toDouble(),
      statusReconciliacion: json['status_reconciliacion'] as String? ?? 'INESPERADO',
      observaciones: json['observaciones'] as String?,
      totalNoCosechado: (json['total_no_cosechado'] as num? ?? 0.0).toDouble(),
      totalInesperado: (json['total_inesperado'] as num? ?? 0.0).toDouble(),
    );
  }

  /// Permite realizar copias mutables optimistas para la UI de Flutter
  ReconciliationModel copyWith({
    int? year,
    int? month,
    int? projectionId,
    int? actualId,
    int? producerId,
    String? productor,
    String? zona,
    String? programador,
    String? dctoCode,
    double? cantidadRecepcion,
    double? cantidadProyeccionHistorica,
    String? statusReconciliacion,
    String? observaciones,
    double? totalNoCosechado,
    double? totalInesperado,
  }) {
    return ReconciliationModel(
      year: year ?? this.year,
      month: month ?? this.month,
      projectionId: projectionId ?? this.projectionId,
      actualId: actualId ?? this.actualId,
      producerId: producerId ?? this.producerId,
      productor: productor ?? this.productor,
      zona: zona ?? this.zona,
      programador: programador ?? this.programador,
      dctoCode: dctoCode ?? this.dctoCode,
      cantidadRecepcion: cantidadRecepcion ?? this.cantidadRecepcion,
      cantidadProyeccionHistorica: cantidadProyeccionHistorica ?? this.cantidadProyeccionHistorica,
      statusReconciliacion: statusReconciliacion ?? this.statusReconciliacion,
      observaciones: observaciones ?? this.observaciones,
      totalNoCosechado: totalNoCosechado ?? this.totalNoCosechado,
      totalInesperado: totalInesperado ?? this.totalInesperado,
    );
  }
}