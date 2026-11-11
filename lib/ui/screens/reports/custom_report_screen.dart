import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cosecha_app/core/theme/app_colors.dart';
import 'package:cosecha_app/core/utils/number_utils.dart';
import '../../../logic/providers/custom_report_provider.dart';

/// Modelo de datos interno para mapear y representar los ítems de cualquier dimensión
class _ReportItem {
  final String label;
  final double value;
  final Map<String, dynamic> rawMap;

  const _ReportItem({
    required this.label,
    required this.value,
    required this.rawMap,
  });

  factory _ReportItem.fromMap(Map<String, dynamic> map) {
    // Buscar etiqueta (nombre de zona, programador, mes, etc.)
    final label = map['name'] ??
        map['label'] ??
        map['zone_name'] ??
        map['programmer'] ??
        map['month'] ??
        map['month_name'] ??
        map['mes'] ??
        map['zona'] ??
        map['programador'] ??
        map['key'] ??
        'Sin nombre';

    // Buscar valor numérico de la métrica
    final rawVal = map['total'] ??
        map['quantity'] ??
        map['value'] ??
        map['total_quantity'] ??
        map['cantidad'] ??
        map['amount'] ??
        0;

    final double val = (rawVal is num)
        ? rawVal.toDouble()
        : (double.tryParse(rawVal.toString()) ?? 0.0);

    return _ReportItem(
      label: label.toString(),
      value: val,
      rawMap: map,
    );
  }
}

/// Pantalla del panel de filtros y visualización del Generador de Reportes Personalizado.
/// Conectada a la función RPC de Supabase `get_custom_report_data` a través de CustomReportRepository.
class CustomReportScreen extends StatefulWidget {
  const CustomReportScreen({super.key});

  @override
  State<CustomReportScreen> createState() => _CustomReportScreenState();
}

class _CustomReportScreenState extends State<CustomReportScreen> {
  /// Abre el showDatePicker nativo individual de Material 3 con salto rápido de año y mes
  Future<DateTime?> _selectSingleDate(
    BuildContext context, {
    required DateTime? currentDate,
    required String helpText,
  }) async {
    final now = DateTime.now();
    final initial = currentDate ?? now;
    final clampedInitial = initial.isBefore(DateTime(2020))
        ? DateTime(2020)
        : (initial.isAfter(DateTime(2035)) ? DateTime(2035) : initial);

    return await showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDate: clampedInitial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: helpText,
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
              secondary: AppColors.statusUrgent,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  /// Traductor y formateador de meses para la dimensión "Evolución Mensual"
  String _formatMonthLabel(
    String rawLabel,
    Map<String, dynamic> rawMap,
    CustomReportProvider provider,
  ) {
    const Map<int, String> mesesAbrev = {
      1: "Ene.", 2: "Feb.", 3: "Mar.", 4: "Abr.", 5: "May.", 6: "Jun.",
      7: "Jul.", 8: "Ago.", 9: "Sep.", 10: "Oct.", 11: "Nov.", 12: "Dic."
    };

    const Map<String, String> mesesNombreAbrev = {
      "enero": "Ene.", "febrero": "Feb.", "marzo": "Mar.", "abril": "Abr.",
      "mayo": "May.", "junio": "Jun.", "julio": "Jul.", "agosto": "Ago.",
      "septiembre": "Sep.", "octubre": "Oct.", "noviembre": "Nov.", "diciembre": "Dic."
    };

    // Extraer año si viene en el mapa o del rango seleccionado
    int? year;
    final rawYear = rawMap['year'] ?? rawMap['anio'] ?? rawMap['año'];
    if (rawYear != null) {
      year = (rawYear is num) ? rawYear.toInt() : int.tryParse(rawYear.toString());
    }
    year ??= provider.startDate?.year ?? DateTime.now().year;

    // Caso 1: Número de mes crudo (ej. 8, "8", "08")
    final int? monthNum = int.tryParse(rawLabel.trim());
    if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
      final abrev = mesesAbrev[monthNum]!;
      return "$abrev $year";
    }

    // Caso 2: Formato ISO (ej. "2026-08" o "2026-08-01")
    if (rawLabel.contains('-')) {
      final parts = rawLabel.split('-');
      if (parts.length >= 2) {
        final parsedYear = int.tryParse(parts[0]);
        final parsedMonth = int.tryParse(parts[1]);
        if (parsedMonth != null && parsedMonth >= 1 && parsedMonth <= 12) {
          final abrev = mesesAbrev[parsedMonth]!;
          final finalYear = parsedYear ?? year;
          return "$abrev $finalYear";
        }
      }
    }

    // Caso 3: Nombre en texto (ej. "Agosto", "agosto")
    final lower = rawLabel.trim().toLowerCase();
    if (mesesNombreAbrev.containsKey(lower)) {
      final abrev = mesesNombreAbrev[lower]!;
      return "$abrev $year";
    }

    return rawLabel;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomReportProvider>();
    final hasDates = provider.startDate != null && provider.endDate != null;
    final hasReport = provider.reportData != null;

    // Convertir lista de la dimensión activa a modelos _ReportItem
    final dimensionItems = provider.currentDimensionList
        .map((map) => _ReportItem.fromMap(map))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "Generador Personalizado",
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
            tooltip: 'Restablecer filtros',
            onPressed: () {
              context.read<CustomReportProvider>().resetFilters();
            },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SECCIÓN ANIMADA: PANEL DE FILTROS COLAPSABLE
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: provider.isFilterExpanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              "FILTROS GENERALES",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          if (hasReport)
                            TextButton.icon(
                              onPressed: () =>
                                  context.read<CustomReportProvider>().toggleFilters(),
                              icon: const Icon(Icons.keyboard_arrow_up_rounded,
                                  size: 18, color: AppColors.primaryGreen),
                              label: const Text(
                                "Ocultar filtros",
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Tarjeta Selector de Fechas (Row con "Fecha Desde" y "Fecha Hasta")
                      _buildDateRangeCard(context, provider, hasDates),

                      const SizedBox(height: 20),

                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(
                          "PARÁMETROS DE REPORTE",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),

                      // Tarjeta Selectores (Dropdowns)
                      _buildSelectorsCard(context, provider),

                      const SizedBox(height: 20),

                      // BOTÓN GENERAR REPORTE REUBICADO DENTRO DEL PANEL COLAPSABLE
                      _buildGenerateButton(context, provider, hasDates),

                      const SizedBox(height: 16),
                    ],
                  ),
                  secondChild: _buildCollapsedFiltersBar(context, provider),
                ),

                // ESTADO DE CARGA O ERROR
                if (provider.isLoading) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.primaryGreen),
                          SizedBox(height: 14),
                          Text(
                            "Consultando datos en Supabase...",
                            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else if (hasReport) ...[
                  // --- SECCIÓN DE RESULTADOS ---
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12, top: 4),
                    child: Text(
                      "RESULTADOS DEL ANÁLISIS",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  // 1. TARJETA DE RESUMEN OSCURA (TOTAL COGOLLOS)
                  _buildSummaryDarkCard(provider),
                  const SizedBox(height: 20),

                  // 2. GRÁFICA DE BARRAS DINÁMICA (FL_CHART) CON SCROLL HORIZONTAL CONSERVADO
                  _buildBarChart(dimensionItems, provider.selectedDimension ?? "Dimensión", provider),
                  const SizedBox(height: 20),

                  // 3. TABLA DE DATOS CRUDA (TOTAL AL INICIO, TÍTULO "Detalles - [Agrupación]")
                  _buildDataTable(dimensionItems, provider.selectedDimension ?? "Dimensión", provider),
                  const SizedBox(height: 30),
                ] else ...[
                  // GUÍA INICIAL ANTES DE GENERAR
                  _buildInitialGuideCard(provider, hasDates),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botón principal "Generar Reporte" integrado dentro del panel de filtros colapsable
  Widget _buildGenerateButton(
    BuildContext context,
    CustomReportProvider provider,
    bool hasDates,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.statusUrgent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.statusUrgent.withValues(alpha: 0.7),
          elevation: 2,
          shadowColor: AppColors.statusUrgent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: provider.isLoading
            ? null
            : () async {
                if (!hasDates) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Debes seleccionar un rango de fechas para generar el reporte.",
                      ),
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                await context.read<CustomReportProvider>().generateReport();

                if (context.mounted) {
                  if (provider.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "Error al generar reporte: ${provider.errorMessage}",
                        ),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Reporte generado exitosamente",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.primaryGreen,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
        child: provider.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Generar Reporte",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Barra colapsada minimalista con botón para expandir
  Widget _buildCollapsedFiltersBar(BuildContext context, CustomReportProvider provider) {
    final datesText = provider.formattedDateRange ?? "Sin rango de fechas";
    final metricText = provider.selectedMetricLabel;
    final dimText = provider.selectedDimension ?? "Zonas";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryGreenLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.tune_rounded, color: AppColors.primaryGreen, size: 20),
        ),
        title: const Text(
          "Filtros aplicados (Tocar para editar)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primaryGreen,
          ),
        ),
        subtitle: Text(
          "$datesText • $metricText • $dimText",
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryGreen),
        onTap: () => context.read<CustomReportProvider>().toggleFilters(),
      ),
    );
  }

  /// Tarjeta "Período de Análisis" con dos campos tipo input independientes ("Fecha Desde" y "Fecha Hasta")
  Widget _buildDateRangeCard(
    BuildContext context,
    CustomReportProvider provider,
    bool hasDates,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasDates ? AppColors.primaryGreen.withValues(alpha: 0.3) : Colors.grey.shade200,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.date_range_rounded,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Período de Análisis",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              if (hasDates)
                TextButton.icon(
                  onPressed: () {
                    context.read<CustomReportProvider>().setDates(null, null);
                  },
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.grey),
                  label: const Text(
                    "Limpiar",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // 1. Campo Fecha Desde
              Expanded(
                child: _buildDateInputField(
                  context: context,
                  label: "Fecha Desde",
                  currentDate: provider.startDate,
                  onTap: () async {
                    final picked = await _selectSingleDate(
                      context,
                      currentDate: provider.startDate,
                      helpText: 'Seleccionar Fecha Desde',
                    );
                    if (picked != null) {
                      final currentEnd = provider.endDate;
                      if (currentEnd != null && picked.isAfter(currentEnd)) {
                        context.read<CustomReportProvider>().setDates(picked, picked);
                      } else {
                        context.read<CustomReportProvider>().setDates(picked, currentEnd);
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // 2. Campo Fecha Hasta
              Expanded(
                child: _buildDateInputField(
                  context: context,
                  label: "Fecha Hasta",
                  currentDate: provider.endDate,
                  onTap: () async {
                    final picked = await _selectSingleDate(
                      context,
                      currentDate: provider.endDate ?? provider.startDate,
                      helpText: 'Seleccionar Fecha Hasta',
                    );
                    if (picked != null) {
                      final currentStart = provider.startDate;
                      if (currentStart != null && picked.isBefore(currentStart)) {
                        context.read<CustomReportProvider>().setDates(picked, picked);
                      } else {
                        context.read<CustomReportProvider>().setDates(currentStart, picked);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Campo visual estilo input para seleccionar fecha individual
  Widget _buildDateInputField({
    required BuildContext context,
    required String label,
    required DateTime? currentDate,
    required VoidCallback onTap,
  }) {
    final isSelected = currentDate != null;
    final text = isSelected ? DateFormat('dd/MM/yyyy').format(currentDate) : "dd/mm/aaaa";

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.04) : const Color(0xFFF9FBF9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primaryGreen : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.textDark : Colors.grey.shade400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: isSelected ? AppColors.primaryGreen : Colors.grey.shade400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Tarjeta con los dos DropdownButtonFormField
  Widget _buildSelectorsCard(BuildContext context, CustomReportProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Dropdown: Métrica a Evaluar (Usa "Volumen Recepcionado")
          DropdownButtonFormField<String>(
            value: provider.selectedMetricLabel,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            icon: const Icon(
              Icons.arrow_drop_down_circle_outlined,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            decoration: InputDecoration(
              labelText: "Métrica a Evaluar",
              labelStyle: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.analytics_outlined,
                color: AppColors.primaryGreen,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FBF9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.8),
              ),
            ),
            items: CustomReportProvider.availableMetrics.map((String metric) {
              return DropdownMenuItem<String>(
                value: metric,
                child: Text(metric),
              );
            }).toList(),
            onChanged: (String? value) {
              context.read<CustomReportProvider>().setMetric(value);
            },
          ),

          const SizedBox(height: 20),

          // 2. Dropdown: Agrupar por
          DropdownButtonFormField<String>(
            value: provider.selectedDimension,
            isExpanded: true,
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
            icon: const Icon(
              Icons.arrow_drop_down_circle_outlined,
              color: AppColors.primaryGreen,
              size: 20,
            ),
            decoration: InputDecoration(
              labelText: "Agrupar por",
              labelStyle: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.pie_chart_outline_rounded,
                color: AppColors.primaryGreen,
              ),
              filled: true,
              fillColor: const Color(0xFFF9FBF9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.8),
              ),
            ),
            items: CustomReportProvider.availableDimensions.map((String dimension) {
              return DropdownMenuItem<String>(
                value: dimension,
                child: Text(dimension),
              );
            }).toList(),
            onChanged: (String? value) {
              context.read<CustomReportProvider>().setDimension(value);
            },
          ),
        ],
      ),
    );
  }

  /// 1. Tarjeta de Resumen (Card verde oscuro) con total en cogollos
  Widget _buildSummaryDarkCard(CustomReportProvider provider) {
    final globalTotal = provider.globalTotal;
    final formattedTotal = NumberUtils.formatNumber(globalTotal.round());
    final datesText = provider.formattedDateRange ?? "Sin rango de fechas";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), AppColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  provider.selectedMetricLabel.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Icon(
                Icons.analytics_rounded,
                color: Colors.white70,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "Consolidado del Período",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Total: $formattedTotal cogollos",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  datesText,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                "Agrupado: ${provider.selectedDimension}",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 2. Widget BarChart de fl_chart con traducción de meses y scroll horizontal preservado
  Widget _buildBarChart(
    List<_ReportItem> items,
    String dimensionTitle,
    CustomReportProvider provider,
  ) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            "No se encontraron registros para la dimensión seleccionada.",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      );
    }

    final isMonthly = dimensionTitle == 'Evolución Mensual';
    final maxVal = items.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.40;
    // Ancho dinámico para scroll horizontal asegurado
    final chartWidth = items.length > 5 ? items.length * 85.0 : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Distribución por $dimensionTitle",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const Text(
                "(cogollos)",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 380,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: chartWidth ?? 500,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    minY: 0,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        tooltipMargin: 8,
                        tooltipPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        getTooltipColor: (_) => AppColors.textDark,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final item = items[group.x.toInt()];
                          final formattedLabel = isMonthly
                              ? _formatMonthLabel(item.label, item.rawMap, provider)
                              : item.label;
                          return BarTooltipItem(
                            '$formattedLabel\n${NumberUtils.formatNumber(rod.toY.round())} cogollos',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox.shrink();
                            String text;
                            if (value >= 1000000) {
                              text = '${(value / 1000000).toStringAsFixed(1)}M';
                            } else if (value >= 1000) {
                              text = '${(value / 1000).toInt()}k';
                            } else {
                              text = value.toInt().toString();
                            }
                            return Text(
                              text,
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 58,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < items.length) {
                              final raw = items[idx].label;
                              final String formatted = isMonthly
                                  ? _formatMonthLabel(raw, items[idx].rawMap, provider)
                                  : raw;
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 8,
                                child: Transform.rotate(
                                  angle: -0.7,
                                  child: Text(
                                    formatted,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (int i = 0; i < items.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: items[i].value,
                              color: AppColors.primaryGreen,
                              width: items.length > 8 ? 20 : 24,
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(6)),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxY,
                                color: AppColors.searchBarFill,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. DataTable con la fila de TOTAL reubicada como primera fila y título "Detalles - [Agrupación]"
  Widget _buildDataTable(
    List<_ReportItem> items,
    String dimensionTitle,
    CustomReportProvider provider,
  ) {
    final isMonthly = dimensionTitle == 'Evolución Mensual';
    final totalValue = items.fold<double>(0, (sum, item) => sum + item.value);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Título dinámico "Detalles - [Nombre de la Agrupación]" sin la palabra Tabular
                Text(
                  "Detalles - $dimensionTitle",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${items.length} filas",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  "Sin registros para mostrar en la tabla.",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 450),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FBF9)),
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 50,
                  columnSpacing: 28,
                  columns: [
                    DataColumn(
                      label: Text(
                        isMonthly
                            ? 'Mes'
                            : (dimensionTitle == 'Programadores' ? 'Programador' : 'Zona'),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ),
                    const DataColumn(
                      numeric: true,
                      label: Text(
                        'Cantidad de cogollos',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      ),
                    ),
                  ],
                  rows: [
                    // Fila de TOTAL como PRIMERA fila de datos justo debajo de las cabeceras
                    DataRow(
                      color: WidgetStateProperty.all(Colors.green.shade50),
                      cells: [
                        const DataCell(
                          Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            NumberUtils.formatNumber(totalValue.round()),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Filas de datos individuales
                    ...items.map((item) {
                      final itemLabel = isMonthly
                          ? _formatMonthLabel(item.label, item.rawMap, provider)
                          : item.label;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              itemLabel,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          DataCell(
                            Text(
                              NumberUtils.formatNumber(item.value.round()),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Tarjeta guía inicial previa a la ejecución
  Widget _buildInitialGuideCard(CustomReportProvider provider, bool hasDates) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.grey.shade700, size: 18),
              const SizedBox(width: 8),
              const Text(
                "Configuración Seleccionada",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildSummaryRow(
            "Período:",
            hasDates ? provider.formattedDateRange! : "Pendiente de selección",
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            "Métrica:",
            "${provider.selectedMetricLabel} (${provider.selectedMetric ?? 'N/A'})",
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            "Agrupación:",
            provider.selectedDimension ?? "Zonas",
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
