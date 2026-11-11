import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/providers/import_harvest_provider.dart';

class ImportHarvestScreen extends StatefulWidget {
  const ImportHarvestScreen({super.key});

  @override
  State<ImportHarvestScreen> createState() => _ImportHarvestScreenState();
}

class _ImportHarvestScreenState extends State<ImportHarvestScreen> {
  // Colores basados en tu configuracion (primary y amber-accent)
  final Color _primaryColor = const Color(0xFF2E7D32); // Verde oscuro
  final Color _amberAccent = const Color(0xFFFF9800); // Naranja
  final Color _bgLight = const Color(0xFFF6F8F6);

  @override
  Widget build(BuildContext context) {
    // Escucha de manera reactiva los cambios del estado global del flujo de carga
    final provider = context.watch<ImportHarvestProvider>();

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2E7D32)),
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
          child: Container(color: _primaryColor.withValues(alpha: 0.1), height: 1.0),
        ),
      ),
      body: Column(
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
                  const SizedBox(height: 24),
                  if (provider.hasFile) _buildPreviewTable(provider), // Solo mostrar tabla si hay archivo
                ],
              ),
            ),
          ),
          _buildBottomAction(provider),
        ],
      ),
    );
  }

  // Widgets Internos 
  Widget _buildUploadArea(ImportHarvestProvider provider) {
    return GestureDetector(
      onTap: provider.isUploading ? null : () => provider.pickFile(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.description_outlined, size: 36, color: _primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              provider.hasFile ? provider.fileName : "Seleccionar o arrastrar archivo .xlsx",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              "Soporta formatos Excel (.xlsx)",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: provider.isUploading ? null : () => provider.pickFile(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Explorar Archivos", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(ImportHarvestProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Estado de carga", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700])),
            Text(
              provider.uploadStatus, 
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: provider.uploadProgress == 1.0 ? _primaryColor : _amberAccent)
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: provider.hasFile ? (provider.uploadProgress > 0 ? provider.uploadProgress : 0.05) : 0.0,
            backgroundColor: _primaryColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor.withValues(alpha: 0.6)),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTable(ImportHarvestProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.visibility_outlined, color: _primaryColor, size: 20),
            const SizedBox(width: 8),
            const Text("Vista Previa del Archivo", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _primaryColor.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(_primaryColor.withValues(alpha: 0.05)),
                dataRowMinHeight: 40,
                dataRowMaxHeight: 50,
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text("Productor", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor))),
                  DataColumn(label: Text("Zona", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor))),
                  DataColumn(label: Text("DCTO", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor))),
                  DataColumn(label: Text("Fecha", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor))),
                  DataColumn(label: Text("Próx. Corte", style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor))), // 💡 Columna agregada para cerciorar el cálculo
                ],
                rows: provider.previewData.map((row) => DataRow(cells: [
                  DataCell(Text(row["Productor"]!)), DataCell(Text(row["Zona"]!)),
                  DataCell(Text(row["DCTO"]!)), DataCell(Text(row["Fecha"]!)),
                  DataCell(Text(row["ProxCorte"]!)),
                ])).toList(),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8, left: 4),
          child: Text(
            "Mostrando las primeras 5 filas del archivo seleccionado.",
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(ImportHarvestProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgLight,
        border: Border(top: BorderSide(color: _primaryColor.withValues(alpha: 0.1))),
      ),
      child: ElevatedButton.icon(
        onPressed: (provider.hasFile && !provider.isUploading && provider.uploadProgress < 1.0) 
            ? () => provider.processAndUploadFile(context, _showOverwriteDialog) 
            : null,
        icon: const Icon(Icons.upload_file),
        label: const Text("Procesar y Subir", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _amberAccent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          disabledForegroundColor: Colors.grey[500],
          minimumSize: const Size(double.infinity, 56), // Altura de 14 rem aprox
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: provider.hasFile && !provider.isUploading ? 4 : 0,
          shadowColor: _amberAccent.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // Mantiene la alerta visual dentro de la capa del Screen para no ensuciar el Provider con contextos visuales
  Future<bool?> _showOverwriteDialog(int targetMonth, int targetYear) async {
    if (!mounted) return false;
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: _amberAccent, size: 28),
              const SizedBox(width: 8),
              const Text("Datos Existentes"),
            ],
          ),
          content: Text(
            "El sistema detectó que ya existen registros procesados para el mes de ${targetMonth.toString().padLeft(2, '0')}/$targetYear.\n\n"
            "¿Deseas eliminar los datos antiguos de este mes y reemplazarlos con este nuevo archivo corregido?",
            style: const TextStyle(fontSize: 16),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancelar
              child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Aceptar
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Sí, Sobrescribir", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }
}