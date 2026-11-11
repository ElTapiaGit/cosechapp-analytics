class ProgrammerDetailItem {
  final String dcto;
  final String productor;
  final String zona;
  final double cRech;
  final double cRecep;
  final double cProc;
  final DateTime fCorte;
  final DateTime? fProc;
  final String programador;
  final String transportista;
  final DateTime? proxCorte;
  final String observaciones;

  ProgrammerDetailItem({
    required this.dcto,
    required this.productor,
    required this.zona,
    required this.cRech,
    required this.cRecep,
    required this.cProc,
    required this.fCorte,
    this.fProc,
    required this.programador,
    required this.transportista,
    this.proxCorte,
    required this.observaciones,
  });

  factory ProgrammerDetailItem.fromJson(Map<String, dynamic> json) {
    return ProgrammerDetailItem(
      dcto: json['dcto_code']?.toString() ?? '',
      productor: json['productor'] ?? 'Desc.',
      zona: json['zona'] ?? '',
      cRech: (json['c_rech'] ?? 0).toDouble(),
      cRecep: (json['c_recep'] ?? 0).toDouble(),
      cProc: (json['c_proc'] ?? 0).toDouble(),
      fCorte: DateTime.parse(json['f_corte']),
      fProc: json['f_proc'] != null ? DateTime.parse(json['f_proc']) : null,
      programador: json['programador'] ?? '',
      transportista: json['transportista'] ?? '',
      proxCorte: json['prox_corte'] != null ? DateTime.tryParse(json['prox_corte'].toString()) : null,
      observaciones: json['observaciones'] ?? '',
    );
  }
}
