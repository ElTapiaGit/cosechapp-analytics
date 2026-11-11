class ZoneDistributionModel {
  final String zoneName;
  final int year;
  final int month;
  final double totalQuantity;
  final double totalReceived;

  ZoneDistributionModel({
    required this.zoneName,
    required this.year,
    required this.month,
    required this.totalQuantity,
    required this.totalReceived,
  });

  factory ZoneDistributionModel.fromJson(Map<String, dynamic> json) {
    return ZoneDistributionModel(
      zoneName: json['zone_name']?.toString() ?? 'Desconocido',
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['total_quantity'] as num?)?.toDouble() ?? 0.0,
      totalReceived: (json['total_received'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
