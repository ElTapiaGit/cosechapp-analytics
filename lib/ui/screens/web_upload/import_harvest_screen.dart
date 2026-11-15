import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/excel_audit_models.dart';
import '../../../logic/providers/import_harvest_provider.dart';

class ImportHarvestScreen extends StatefulWidget {
  const ImportHarvestScreen({super.key});

  @override
  State<ImportHarvestScreen> createState() => _ImportHarvestScreenState();
}

class _ImportHarvestScreenState extends State<ImportHarvestScreen> {
  final Color _primaryColor = const Color(0xFF2E7D32);
  final Color _amberAccent = const Color(0xFFFF9800);
  final Color _bgLight = const Color(0xFFF6F8F6);

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ImportHarvestProvider>();
    final auditResult = provider.auditResult;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _primaryColor),
        title: const Text(
          "Importar Cosechas",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: _primaryColor.withValues(alpha: 0.1),
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildUploadArea(provider),
                      const SizedBox(height: 24),
                      _buildProgressSection(provider),
                      if (auditResult != null) ...[
                        const SizedBox(height: 24),
                        if (!auditResult.isValid)
                          _buildErrorsPanel(auditResult)
                        else
                          _buildPreviewTable(auditResult),
                      ],
                    ],
                  ),
                ),
              ),
              _buildBottomAction(context, provider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadArea(ImportHarvestProvider provider) {
    final audit = provider.auditResult;
    final hasAudit = audit != null;

    String titleText = "Seleccionar o arrastrar archivo .xlsx";
    if (hasAudit) {
      if (audit.isValid) {
        final monthStr = audit.targetMonth.toString().padLeft(2, '0');
        titleText =
            "Archivo auditado: ${audit.validRecords.length} registros (Período $monthStr/${audit.targetYear})";
      } else {
        titleText =
            "Archivo con observaciones (${audit.errors.length} errores detectados)";
      }
    }

    return GestureDetector(
      onTap: provider.isProcessing ? null : () => provider.pickAndAuditFile(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _primaryColor.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.description_outlined,
                size: 36,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titleText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Soporta formatos Excel (.xlsx) con auditoría automática en memoria",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed:
                  provider.isProcessing ? null : () => provider.pickAndAuditFile(),
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              label: const Text(
                "Explorar Archivos",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(ImportHarvestProvider provider) {
    final bool hasErrors =
        provider.auditResult != null && !provider.auditResult!.isValid;
    final bool isErrorStatus =
        hasErrors || provider.statusMessage.startsWith("Error");

    final Color statusColor = isErrorStatus
        ? Colors.red.shade700
        : (provider.uploadProgress == 1.0 ? _primaryColor : _amberAccent);

    final double progressValue = provider.isProcessing
        ? (provider.uploadProgress > 0 ? provider.uploadProgress : 0.35)
        : (provider.hasValidData
            ? (provider.uploadProgress == 1.0 ? 1.0 : 0.5)
            : 0.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Estado de auditoría y carga",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                "${(progressValue * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: provider.isProcessing && provider.uploadProgress == 0.0
                  ? null
                  : progressValue,
              minHeight: 10,
              backgroundColor: _primaryColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isErrorStatus
                    ? Icons.error_outline_rounded
                    : (provider.hasValidData
                        ? Icons.verified_rounded
                        : Icons.info_outline_rounded),
                size: 18,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsPanel(ExcelAuditResult auditResult) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade800,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Inconsistencias Detectadas (${auditResult.errors.length})",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "La subida ha sido bloqueada preventivamente. Corrija las siguientes filas en su archivo Excel y vuelva a seleccionarlo:",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: auditResult.errors.length,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.red.shade100,
                    height: 16,
                  ),
                  itemBuilder: (context, index) {
                    final err = auditResult.errors[index];
                    final rowBadge =
                        err.rowNumber > 0 ? "Fila ${err.rowNumber}" : "Archivo";
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rowBadge,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Campo: ${err.field}",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                err.message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (err.rawValue.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    "Valor leído: \"${err.rawValue}\"",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable(ExcelAuditResult auditResult) {
    final previewRows = auditResult.validRecords.take(5).toList();
    final monthStr = auditResult.targetMonth.toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Vista Previa de Validación",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Período: $monthStr/${auditResult.targetYear}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryColor.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  _primaryColor.withValues(alpha: 0.05),
                ),
                dataRowMinHeight: 42,
                dataRowMaxHeight: 52,
                columnSpacing: 24,
                columns: [
                  DataColumn(
                    label: Text(
                      "Fila",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Productor",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Zona",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "DCTO",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "F. Corte",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      "Próx. Corte (+120d)",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                ],
                rows: previewRows
                    .map(
                      (record) => DataRow(
                        cells: [
                          DataCell(Text(record.rowNumber.toString())),
                          DataCell(
                            Text(
                              record.producerName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          DataCell(Text(record.zoneName)),
                          DataCell(
                            Text(
                              record.dctoCode.isNotEmpty ? record.dctoCode : "-",
                            ),
                          ),
                          DataCell(Text(_dateFormat.format(record.cutDate))),
                          DataCell(
                            Text(
                              _dateFormat.format(record.nextEstimatedDate),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            "Mostrando las primeras ${previewRows.length} de ${auditResult.validRecords.length} filas válidas del archivo seleccionado.",
            style: const TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    ImportHarvestProvider provider,
  ) {
    final bool canSubmit =
        provider.hasValidData && !provider.isProcessing && provider.uploadProgress < 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgLight,
        border: Border(
          top: BorderSide(color: _primaryColor.withValues(alpha: 0.1)),
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: canSubmit
            ? () async {
                final success = await provider.commitUpload(overwrite: true);
                if (success && context.mounted) {
                  SnackbarUtils.showSuccess(
                    context,
                    "Datos importados correctamente.",
                  );
                }
              }
            : null,
        icon: const Icon(Icons.cloud_upload_rounded),
        label: const Text(
          "Confirmar y Subir a Base de Datos",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _amberAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: canSubmit ? 4 : 0,
          shadowColor: _amberAccent.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
