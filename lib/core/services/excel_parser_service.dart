import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import '../../data/models/excel_audit_models.dart';

class ExcelParserService {
  static const int nextCutOffsetDays = 120;

  static String sanitizeText(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toUpperCase();
  }

  static DateTime? parseFlexibleDate(dynamic cellValue) {
    if (cellValue == null) return null;
    if (cellValue is DateCellValue) {
      return DateTime(cellValue.year, cellValue.month, cellValue.day);
    }
    if (cellValue is DateTimeCellValue) {
      return DateTime(cellValue.year, cellValue.month, cellValue.day);
    }
    
    String raw = cellValue.toString().trim();
    if (raw.isEmpty || raw.toUpperCase() == 'NULL') return null;

    final numValue = num.tryParse(raw);
    if (numValue != null && numValue > 30000 && numValue < 70000) {
      final excelEpoch = DateTime(1899, 12, 30);
      return excelEpoch.add(Duration(days: numValue.toInt()));
    }

    raw = raw.replaceAll('/', '-');
    final parts = raw.split('-');
    if (parts.length == 3) {
      if (parts[0].length <= 2) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      } else if (parts[0].length == 4) {
        return DateTime.tryParse(raw);
      }
    }
    return DateTime.tryParse(raw);
  }

  static ExcelAuditResult parseAndAudit(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ExcelAuditResult(validRecords: [], errors: [
        const RowValidationError(rowNumber: 0, field: 'Archivo', rawValue: '', message: 'El archivo Excel no contiene hojas de datos.')
      ], targetMonth: 0, targetYear: 0);
    }

    final sheet = excel.tables[excel.tables.keys.first]!;
    if (sheet.rows.isEmpty) {
      return ExcelAuditResult(validRecords: [], errors: [
        const RowValidationError(rowNumber: 0, field: 'Hoja', rawValue: '', message: 'La hoja seleccionada está vacía.')
      ], targetMonth: 0, targetYear: 0);
    }

    int headerIndex = -1;
    Map<String, int> colMap = {};

    for (int i = 0; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      for (int j = 0; j < row.length; j++) {
        final val = sanitizeText(row[j]?.value?.toString() ?? '');
        if (val == 'PRODUCTOR' || val == 'DCTO') {
          headerIndex = i;
          break;
        }
      }
      if (headerIndex != -1) {
        for (int j = 0; j < row.length; j++) {
          final colName = sanitizeText(row[j]?.value?.toString() ?? '');
          if (colName.isNotEmpty) colMap[colName] = j;
        }
        break;
      }
    }

    if (headerIndex == -1 || !colMap.containsKey('PRODUCTOR')) {
      return ExcelAuditResult(validRecords: [], errors: [
        const RowValidationError(rowNumber: 0, field: 'Encabezado', rawValue: '', message: 'No se encontró la columna obligatoria PRODUCTOR.')
      ], targetMonth: 0, targetYear: 0);
    }

    final List<ValidatedHarvestRecord> validList = [];
    final List<RowValidationError> errorList = [];
    final Map<String, int> monthCounter = {};

    for (int i = headerIndex + 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final rowNum = i + 1;
      if (row.isEmpty) continue;

      dynamic getRaw(String col) {
        final idx = colMap[col];
        if (idx == null || idx >= row.length) return null;
        return row[idx]?.value;
      }

      String getString(String col) => sanitizeText(getRaw(col)?.toString() ?? '');

      final productor = getString('PRODUCTOR');
      final dcto = getString('DCTO');
      final zona = getString('ZONA');

      if (productor.isEmpty && dcto.isEmpty && zona.isEmpty) continue;

      if (productor.isEmpty) {
        errorList.add(RowValidationError(
          rowNumber: rowNum,
          field: 'PRODUCTOR',
          rawValue: '',
          message: 'Fila $rowNum: El nombre del Productor es obligatorio para el documento "$dcto".',
        ));
      }

      final cutDate = parseFlexibleDate(getRaw('F.CORTE'));
      if (cutDate == null) {
        errorList.add(RowValidationError(
          rowNumber: rowNum,
          field: 'F.CORTE',
          rawValue: getRaw('F.CORTE')?.toString() ?? 'Vacío',
          message: 'Fila $rowNum: Fecha de corte inválida o ausente.',
        ));
      }

      final procDate = parseFlexibleDate(getRaw('F.PROC'));

      double parseNum(String col) {
        final raw = getString(col).replaceAll(',', '.');
        return double.tryParse(raw) ?? 0.0;
      }

      if (cutDate != null && productor.isNotEmpty) {
        final monthKey = "${cutDate.year}-${cutDate.month}";
        monthCounter[monthKey] = (monthCounter[monthKey] ?? 0) + 1;

        final nextEstimated = DateTime(cutDate.year, cutDate.month, cutDate.day).add(const Duration(days: nextCutOffsetDays));

        validList.add(ValidatedHarvestRecord(
          rowNumber: rowNum,
          dctoCode: dcto,
          producerName: productor,
          zoneName: zona.isEmpty ? 'GENERAL' : zona,
          quantityRejected: parseNum('C.RECH'),
          quantityReceived: parseNum('C.RECEP'),
          quantityProcessed: parseNum('C.PROC'),
          cutDate: cutDate,
          processedDate: procDate,
          nextEstimatedDate: nextEstimated,
          programmer: getString('PROGRAMADOR'),
          transportDriver: getString('TRANSPORTISTA'),
        ));
      }
    }

    int tYear = DateTime.now().year;
    int tMonth = DateTime.now().month;
    if (monthCounter.isNotEmpty) {
      final mostFrequentKey = monthCounter.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final parts = mostFrequentKey.split('-');
      tYear = int.parse(parts[0]);
      tMonth = int.parse(parts[1]);
    }

    return ExcelAuditResult(
      validRecords: validList,
      errors: errorList,
      targetMonth: tMonth,
      targetYear: tYear,
    );
  }
}

