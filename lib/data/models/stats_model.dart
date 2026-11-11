// clase simple para recibir los datos de Supabase
class MonthlyStat {
  final int year;
  final int month;
  final double totalProcessed;

  MonthlyStat({required this.year, required this.month, required this.totalProcessed});

  factory MonthlyStat.fromJson(Map<String, dynamic> json) {
    return MonthlyStat(
      // protege contra Nulos y decimales que a veces devuelve SQL
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      totalProcessed: (json['total_processed'] ?? 0).toDouble(),
    );
  }
  
  // Convertimos numero de mes a texto corto (Español)
  String get monthName {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}

class ZoneStat {
  final String zoneName;
  final double totalQuantity; // C.PROC
  final double totalReceived; // C.RECEP 

  ZoneStat({required this.zoneName, required this.totalQuantity, required this.totalReceived});

  factory ZoneStat.fromJson(Map<String, dynamic> json) {
    return ZoneStat(
      zoneName: json['zone_name'],
      totalQuantity: (json['total_quantity'] ?? 0).toDouble(),
      totalReceived: (json['total_received'] ?? 0).toDouble(),
    );
  }
}