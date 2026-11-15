import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/excel_parser_service.dart';
import '../../data/models/excel_audit_models.dart';

class ImportHarvestProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isProcessing = false;
  ExcelAuditResult? _auditResult;
  String _statusMessage = "Esperando archivo Excel (.xlsx)";
  double _uploadProgress = 0.0;

  bool get isProcessing => _isProcessing;
  ExcelAuditResult? get auditResult => _auditResult;
  String get statusMessage => _statusMessage;
  double get uploadProgress => _uploadProgress;
  bool get hasValidData => _auditResult != null && _auditResult!.isValid;

  Future<void> pickAndAuditFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.first.bytes == null) return;

      _isProcessing = true;
      _statusMessage = "Auditando registros en memoria...";
      notifyListeners();

      final bytes = result.files.first.bytes!;
      _auditResult = ExcelParserService.parseAndAudit(bytes);

      _isProcessing = false;
      if (_auditResult!.errors.isNotEmpty) {
        _statusMessage = "Se encontraron ${_auditResult!.errors.length} errores en el archivo.";
      } else {
        _statusMessage = "${_auditResult!.validRecords.length} registros válidos listos para importar.";
      }
      notifyListeners();
    } catch (e) {
      _isProcessing = false;
      _statusMessage = "Error al procesar archivo: $e";
      notifyListeners();
    }
  }

  Future<bool> commitUpload({required bool overwrite}) async {
    if (!hasValidData) return false;

    _isProcessing = true;
    _statusMessage = "Ejecutando importación atómica en servidor...";
    _uploadProgress = 0.5;
    notifyListeners();

    try {
      final tYear = _auditResult!.targetYear;
      final tMonth = _auditResult!.targetMonth;
      final startDate = '$tYear-${tMonth.toString().padLeft(2, '0')}-01';
      final nextMonth = tMonth == 12 ? 1 : tMonth + 1;
      final nextYear = tMonth == 12 ? tYear + 1 : tYear;
      final endDate = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01';

      final payload = _auditResult!.validRecords.map((r) => r.toDbMap()).toList();

      final response = await _supabase.rpc(
        'import_monthly_harvest_atomic',
        params: {
          'p_start_date': startDate,
          'p_end_date': endDate,
          'p_delete_existing': overwrite,
          'p_records': payload,
        },
      );

      _isProcessing = false;
      _uploadProgress = 1.0;
      _statusMessage = "¡Importación exitosa!";
      notifyListeners();
      return response['success'] == true;
    } catch (e) {
      _isProcessing = false;
      _uploadProgress = 0.0;
      _statusMessage = "Error al persistir: $e";
      notifyListeners();
      return false;
    }
  }
}
