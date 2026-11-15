class RowValidationError {
  final int rowNumber;
  final String field;
  final String rawValue;
  final String message;

  const RowValidationError({
    required this.rowNumber,
    required this.field,
    required this.rawValue,
    required this.message,
  });
}

class ValidatedHarvestRecord {
  final int rowNumber;
  final String dctoCode;
  final String producerName;
  final String zoneName;
  final double quantityRejected;
  final double quantityReceived;
  final double quantityProcessed;
  final DateTime cutDate;
  final DateTime? processedDate;
  final DateTime nextEstimatedDate;
  final String programmer;
  final String transportDriver;

  ValidatedHarvestRecord({
    required this.rowNumber,
    required this.dctoCode,
    required this.producerName,
    required this.zoneName,
    required this.quantityRejected,
    required this.quantityReceived,
    required this.quantityProcessed,
    required this.cutDate,
    this.processedDate,
    required this.nextEstimatedDate,
    required this.programmer,
    required this.transportDriver,
  });

  Map<String, dynamic> toDbMap() => {
    'dcto_code': dctoCode,
    'producer_name': producerName,
    'zone_name': zoneName,
    'quantity_rejected': quantityRejected,
    'quantity_received': quantityReceived,
    'quantity_processed': quantityProcessed,
    'cut_date': "${cutDate.year}-${cutDate.month.toString().padLeft(2, '0')}-${cutDate.day.toString().padLeft(2, '0')}",
    'processed_date': processedDate != null 
        ? "${processedDate!.year}-${processedDate!.month.toString().padLeft(2, '0')}-${processedDate!.day.toString().padLeft(2, '0')}"
        : null,
    'next_estimated_date': "${nextEstimatedDate.year}-${nextEstimatedDate.month.toString().padLeft(2, '0')}-${nextEstimatedDate.day.toString().padLeft(2, '0')}",
    'programmer': programmer,
    'transport_driver': transportDriver,
    'status': 'HARVESTED',
  };
}

class ExcelAuditResult {
  final List<ValidatedHarvestRecord> validRecords;
  final List<RowValidationError> errors;
  final int targetMonth;
  final int targetYear;

  ExcelAuditResult({
    required this.validRecords,
    required this.errors,
    required this.targetMonth,
    required this.targetYear,
  });

  bool get isValid => errors.isEmpty && validRecords.isNotEmpty;
}

