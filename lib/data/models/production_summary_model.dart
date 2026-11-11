class ProductionSummaryModel {
  final String extensionista;
  final int year;
  final int month;
  final double cantidadCogollos;
  final double descarte;
  final double cantidadProcesada;
  final int diasCosecha;

  ProductionSummaryModel({
    required this.extensionista,
    required this.year,
    required this.month,
    required this.cantidadCogollos,
    required this.descarte,
    required this.cantidadProcesada,
    required this.diasCosecha,
  });

  factory ProductionSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProductionSummaryModel(
      extensionista: json['extensionista']?.toString() ?? 'Desconocido',
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      cantidadCogollos: (json['cantidad_cogollos'] as num?)?.toDouble() ?? 0.0,
      descarte: (json['descarte'] as num?)?.toDouble() ?? 0.0,
      cantidadProcesada: (json['cantidad_procesada'] as num?)?.toDouble() ?? 0.0,
      diasCosecha: (json['dias_cosecha'] as num?)?.toInt() ?? 0,
    );
  }
}
