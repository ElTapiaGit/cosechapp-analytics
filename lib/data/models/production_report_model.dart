// reporte resumen mes produccion
class ProductionReportItem {
  final String extensionista;
  final double cantidadCogollos; // C.RECEP
  final double descarte;         // C.RECH
  final double cantidadProcesada; // C.PROC
  final int diasCosecha;          
  final double promedioDiaCogollos;
  final double rendimientoPromedio;
  final double granTotalMes;     
  final double porcentajeParticipacion;

  ProductionReportItem({
    required this.extensionista,
    required this.cantidadCogollos,
    required this.descarte,
    required this.cantidadProcesada,
    required this.diasCosecha,
    required this.promedioDiaCogollos,
    required this.rendimientoPromedio,
    required this.granTotalMes,
    required this.porcentajeParticipacion,
  });

  factory ProductionReportItem.fromJson(Map<String, dynamic> json) {
    return ProductionReportItem(
      extensionista: json['extensionista'] ?? 'Sin Asignar',
      cantidadCogollos: (json['cantidad_cogollos'] ?? 0).toDouble(),
      descarte: (json['descarte'] ?? 0).toDouble(),
      cantidadProcesada: (json['cantidad_procesada'] ?? 0).toDouble(),
      diasCosecha: (json['dias_cosecha'] ?? 0).toInt(),
      promedioDiaCogollos: (json['promedio_dia_cogollos'] ?? 0).toDouble(),
      rendimientoPromedio: (json['rendimiento_promedio'] ?? 0).toDouble(),
      granTotalMes: (json['gran_total_mes'] ?? 0).toDouble(),
      porcentajeParticipacion: (json['porcentaje_participacion'] ?? 0).toDouble(),
    );
  }
}