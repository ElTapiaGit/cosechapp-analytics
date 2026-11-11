import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../../core/utils/snackbar_utils.dart';
import '../../data/repositories/harvest_repository.dart';

// Cambiamos el nombre a ImportHarvestProvider para evitar conflictos con tu provider original
class ImportHarvestProvider extends ChangeNotifier {
  final HarvestRepository _repository = HarvestRepository();

  // Variables de "estado"
  bool _hasFile = false;
  String _fileName = "";
  double _uploadProgress = 0.0;
  String _uploadStatus = "Esperando archivo";
  bool _isUploading = false;

  // Almacena los datos crudos extraídos del Excel
  final List<Map<String, dynamic>> _parsedData = [];
  final List<Map<String, String>> _previewData = [];

  // Getters públicos
  bool get hasFile => _hasFile;
  String get fileName => _fileName;
  double get uploadProgress => _uploadProgress;
  String get uploadStatus => _uploadStatus;
  bool get isUploading => _isUploading;
  List<Map<String, dynamic>> get parsedData => _parsedData;
  List<Map<String, String>> get previewData => _previewData;

  // SELECCIONAR Y LEER EL EXCEL
  Future<void> pickFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true, 
      );

      if (result != null && result.files.first.bytes != null) {
        Uint8List fileBytes = result.files.first.bytes!;
        String fileName = result.files.first.name;

        _isUploading = true;
        _uploadStatus = "Leyendo Excel...";
        _uploadProgress = 0.1;
        notifyListeners();

        var excel = Excel.decodeBytes(fileBytes);
        String sheetName = excel.tables.keys.first;
        Sheet sheet = excel.tables[sheetName]!;

        _extractDataFromSheet(sheet);

        _fileName = fileName;
        _hasFile = true;
        _isUploading = false;
        _uploadStatus = "Archivo leído. ${_parsedData.length} registros encontrados.";
        _uploadProgress = 0.0;
        notifyListeners();
      }
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      _uploadStatus = "Error al leer archivo";
      notifyListeners();
      SnackbarUtils.showError(context, "Error al leer el archivo");
    }
  }

  // EXTRAER DATOS (Filas y Columnas)
  void _extractDataFromSheet(Sheet sheet) {
    _parsedData.clear();
    _previewData.clear();

    if (sheet.rows.isEmpty) return;

    int headerRowIndex = -1;
    Map<String, int> columnIndices = {};

    for (int i = 0; i < sheet.rows.length; i++) {
      var row = sheet.rows[i];
      for (int j = 0; j < row.length; j++) {
        String cellValue = _getCellValueAsString(row[j]).toUpperCase().trim();
        if (cellValue == 'DCTO' || cellValue == 'PRODUCTOR') {
          headerRowIndex = i;
          break;
        }
      }
      if (headerRowIndex != -1) {
        for (int j = 0; j < row.length; j++) {
          String colName = _getCellValueAsString(row[j]).toUpperCase().trim();
          if (colName.isNotEmpty) columnIndices[colName] = j;
        }
        break; 
      }
    }

    if (headerRowIndex == -1 || !columnIndices.containsKey('PRODUCTOR')) {
      throw Exception("No se encontraron las columnas esperadas (Falta PRODUCTOR).");
    }

    for (int i = headerRowIndex + 1; i < sheet.rows.length; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty) continue;

      String safeGet(String colName) {
        final index = columnIndices[colName];
        if (index == null || index >= row.length) return "";
        return _getCellValueAsString(row[index]).trim().toUpperCase();
      }
      
      if (safeGet('PRODUCTOR').isEmpty && safeGet('DCTO').isEmpty) continue;

      String productor = safeGet('PRODUCTOR');
      if (productor.isEmpty) {
        String dcto = safeGet('DCTO');
        throw Exception("El nombre del Productor está vacío para el DCTO '$dcto' (Fila ${i + 1}).");
      }

      Map<String, dynamic> rowData = {
        'dcto': safeGet('DCTO'),
        'productor': productor,
        'zona': safeGet('ZONA'),
        'c_rech': _parseNumber(safeGet('C.RECH')),
        'c_recep': _parseNumber(safeGet('C.RECEP')),
        'c_proc': _parseNumber(safeGet('C.PROC')),
        'f_corte': _parseDate(safeGet('F.CORTE')),
        'f_proc': _parseDate(safeGet('F.PROC')),
        'programador': safeGet('PROGRAMADOR'),
        'transportista': safeGet('TRANSPORTISTA'),
      };

      _parsedData.add(rowData);

      if (_previewData.length < 5) {
        String displayDate = _formatDateForDB(rowData['f_corte']) ?? "Sin fecha";
        DateTime? previewNextDate = rowData['f_corte'] != null 
            ? (rowData['f_corte'] as DateTime).add(const Duration(days: 120)) 
            : null;
        String displayNextDate = _formatDateForDB(previewNextDate) ?? "Sin fecha";

        _previewData.add({
          "Productor": rowData['productor'].toString(),
          "Zona": rowData['zona'].toString(),
          "DCTO": rowData['dcto'].toString(),
          "Fecha": displayDate, 
          "ProxCorte": displayNextDate,
        });
      }
    }
  }

  // PROCESAR Y SUBIR
  Future<void> processAndUploadFile(BuildContext context, Future<bool?> Function(int month, int year) showOverwriteDialog) async {
    if (_parsedData.isEmpty) return;

    _isUploading = true;
    _uploadProgress = 0.1;
    _uploadStatus = "Analizando fechas...";
    notifyListeners();

    try {
      Map<String, int> monthCounts = {};
      for (var row in _parsedData) {
        DateTime? date = row['f_proc'] ?? row['f_corte'];
        if (date != null) {
          String key = "${date.year}-${date.month}";
          monthCounts[key] = (monthCounts[key] ?? 0) + 1;
        }
      }

      String mostFrequent = monthCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      int targetYear = int.parse(mostFrequent.split('-')[0]);
      int targetMonth = int.parse(mostFrequent.split('-')[1]);

      String startDate = '$targetYear-${targetMonth.toString().padLeft(2, '0')}-01';
      int nextMonth = targetMonth == 12 ? 1 : targetMonth + 1;
      int nextYear = targetMonth == 12 ? targetYear + 1 : targetYear;
      String endDate = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

      final existingData = await _repository.checkExistingRecords(startDate, endDate);

      if (existingData.isNotEmpty) {
        bool? overwrite = await showOverwriteDialog(targetMonth, targetYear);
        if (overwrite != true) {
          _isUploading = false;
          _uploadStatus = "Cancelado.";
          _uploadProgress = 0.0;
          notifyListeners();
          return;
        }
        await _repository.deleteOldRecords(startDate, endDate);
      }

      _uploadStatus = "Sincronizando...";
      notifyListeners();

      Set<String> uniqueZones = _parsedData.map((e) => e['zona'] as String).where((z) => z.isNotEmpty).toSet();
      if (uniqueZones.isNotEmpty) {
        await _repository.upsertZones(uniqueZones.map((z) => {'name': z}).toList());
      }
      
      final zonesDb = await _repository.selectZones();
      Map<String, int> zoneDict = {for (var z in zonesDb) z['name'].toString().toUpperCase(): z['id'] as int};
      
      Map<String, Map<String, dynamic>> uniqueProducers = {};
      for (var row in _parsedData) {
        String prodName = row['productor'];
        String zoneName = row['zona'].toString().toUpperCase();
        int? zoneId = zoneDict[zoneName];
        if (zoneId != null) {
          uniqueProducers["${prodName}_$zoneId"] = {'full_name': prodName, 'zone_id': zoneId};
        }
      }

      if (uniqueProducers.isNotEmpty) {
        await _repository.upsertProducers(uniqueProducers.values.toList());
      }

      final producersDb = await _repository.selectProducers();
      Map<String, int> prodDict = {
        for (var p in producersDb) "${p['full_name']}_${p['zone_id']}": p['id'] as int
      };

      List<Map<String, dynamic>> harvestPayload = [];
      for (var row in _parsedData) {
        int? zoneId = zoneDict[row['zona'].toString().toUpperCase()];
        int? prodId = prodDict["${row['productor']}_$zoneId"];
        if (zoneId == null || prodId == null) continue;

        DateTime cutDate = row['f_corte'];
        DateTime nextDate = cutDate.add(const Duration(days: 120));

        harvestPayload.add({
          'producer_id': prodId,
          'dcto_code': row['dcto'],
          'quantity_rejected': row['c_rech'],
          'quantity_received': row['c_recep'],
          'quantity_processed': row['c_proc'],
          'cut_date': _formatDateForDB(cutDate),
          'processed_date': _formatDateForDB(row['f_proc']),
          'programmer': row['programador'],
          'transport_driver': row['transportista'],
          'status': 'HARVESTED',
          'next_estimated_date': nextDate.toIso8601String(),
        });
      }

      if (harvestPayload.isNotEmpty) {
        await _repository.insertHarvestRecords(harvestPayload);
      }

      _isUploading = false;
      _uploadProgress = 1.0;
      _uploadStatus = "¡Completado!";
      notifyListeners();
      SnackbarUtils.showSuccess(context, "Datos importados.");
    } catch (e) {
      SnackbarUtils.showError(context, "Error");
      _isUploading = false;
      notifyListeners();
    }
  }

  String? _formatDateForDB(DateTime? date) {
    if (date == null) return null;
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _getCellValueAsString(Data? cell) {
    if (cell == null || cell.value == null) return "";
    var value = cell.value;
    if (value is TextCellValue) return value.value.toString();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is DateCellValue) return "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}";
    if (value is DateTimeCellValue) return "${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}";
    return value.toString();
  }

  double _parseNumber(String val) => double.tryParse(val.replaceAll(',', '.')) ?? 0.0;

  DateTime? _parseDate(String val) {
    if (val.isEmpty || val.toUpperCase() == 'NULL') return null;
    try {
      val = val.replaceAll('/', '-');
      List<String> parts = val.split('-');
      if (parts.length == 3 && parts[0].length <= 2) {
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      return DateTime.tryParse(val);
    } catch (e) { return null; }
  }
}