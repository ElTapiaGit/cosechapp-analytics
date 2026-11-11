import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cosecha_app/core/theme/app_colors.dart';
import 'package:cosecha_app/core/utils/number_utils.dart';
import 'package:cosecha_app/core/utils/snackbar_utils.dart';

/// Modelo interno que representa un registro de resumen de producción por extensionista y mes
class _QuarterlyProductionItem {
  final String extensionista;
  final int year;
  final int month;
  final double cantidadRecepcion; // C.RECEP (Cosecha en campo)
  final double cantidadProcesada; // C.PROC (Procesado en planta)
  final double descarte;          // C.RECH (Rechazo/descarte)
  final double rendimiento;       // (C.PROC / C.RECEP) * 100

  _QuarterlyProductionItem({
    required this.extensionista,
    required this.year,
    required this.month,
    required this.cantidadRecepcion,
    required this.cantidadProcesada,
    required this.descarte,
    required this.rendimiento,
  });

  factory _QuarterlyProductionItem.fromJson(Map<String, dynamic> json) {
    final recep = (json['cantidad_cogollos'] as num?)?.toDouble() ?? 0.0;
    final proc = (json['cantidad_procesada'] as num?)?.toDouble() ?? 0.0;
    final rech = (json['descarte'] as num?)?.toDouble() ?? 0.0;
    final rend = recep > 0 ? (proc / recep) * 100.0 : 0.0;

    return _QuarterlyProductionItem(
      extensionista: json['extensionista']?.toString() ?? 'Sin Asignar',
      year: (json['year'] as num?)?.toInt() ?? 0,
      month: (json['month'] as num?)?.toInt() ?? 0,
      cantidadRecepcion: recep,
      cantidadProcesada: proc,
      descarte: rech,
      rendimiento: rend,
    );
  }
}

/// Modelo de agregación mensual para la gráfica comparativa de barras
class _MonthBarSummary {
  final int month;
  final String monthName;
  final String shortMonthName;
  final double cantidadRecepcion;
  final double cantidadProcesada;
  final double rendimiento;

  _MonthBarSummary({
    required this.month,
    required this.monthName,
    required this.shortMonthName,
    required this.cantidadRecepcion,
    required this.cantidadProcesada,
    required this.rendimiento,
  });
}

/// Pantalla analítica: Recepción y Producción Trimestral
/// Permite comparar la cosecha recepcionada en campo contra la procesada en planta.
class QuarterlyProductionReportScreen extends StatefulWidget {
  const QuarterlyProductionReportScreen({super.key});

  @override
  State<QuarterlyProductionReportScreen> createState() => _QuarterlyProductionReportScreenState();
}

class _QuarterlyProductionReportScreenState extends State<QuarterlyProductionReportScreen> {
  // Selectores de período reactivos en Material 3
  late int _selectedYear;
  late int _selectedQuarter;

  bool _isLoading = true;
  String? _errorMessage;
  List<_QuarterlyProductionItem> _items = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedQuarter = (now.month / 3).ceil().clamp(1, 4);
    _fetchData();
  }

  List<int> _getMonthsForQuarter(int quarter) {
    switch (quarter) {
      case 1: return [1, 2, 3];
      case 2: return [4, 5, 6];
      case 3: return [7, 8, 9];
      case 4: return [10, 11, 12];
      default: return [1, 2, 3];
    }
  }

  String _getMonthName(int month) {
    const names = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    if (month >= 1 && month <= 12) return names[month - 1];
    return 'Mes $month';
  }

  String _getShortMonthName(int month) {
    const names = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    if (month >= 1 && month <= 12) return names[month - 1];
    return '$month';
  }

  String _getQuarterLabel(int quarter) {
    switch (quarter) {
      case 1: return "T1 (Ene - Mar)";
      case 2: return "T2 (Abr - Jun)";
      case 3: return "T3 (Jul - Sep)";
      case 4: return "T4 (Oct - Dic)";
      default: return "T$quarter";
    }
  }

  /// Consulta la vista existente `production_summary_report` en Supabase sin cambios backend
  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final months = _getMonthsForQuarter(_selectedQuarter);
      final response = await Supabase.instance.client
          .from('production_summary_report')
          .select()
          .eq('year', _selectedYear)
          .inFilter('month', months)
          .order('month', ascending: true)
          .order('extensionista', ascending: true);

      final List<_QuarterlyProductionItem> loaded = (response as List)
          .map((json) => _QuarterlyProductionItem.fromJson(json))
          .toList();

      if (mounted) {
        setState(() {
          _items = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar los datos de producción: $e';
          _isLoading = false;
        });
      }
    }
  }

  // --- ACUMULADOS Y BALANCES DE KPIS ---
  double get _totalRecep => _items.fold(0.0, (sum, i) => sum + i.cantidadRecepcion);
  double get _totalProc => _items.fold(0.0, (sum, i) => sum + i.cantidadProcesada);
  double get _totalRech => _items.fold(0.0, (sum, i) => sum + i.descarte);
  double get _rendimientoGlobal => _totalRecep > 0 ? (_totalProc / _totalRecep * 100) : 0.0;

  // --- EXPORTACIÓN DE PLANILLA A EXCEL (.XLSX) ---
  Future<void> _exportToExcel() async {
    try {
      final excel = Excel.createExcel();
      const sheetName = 'Recepción y Producción';
      final sheet = excel[sheetName];
      excel.delete('Sheet1');

      // 1. Membrete Institucional
      sheet.appendRow([
        TextCellValue("COSECHAPP - BALANCE DE RECEPCIÓN Y PRODUCCIÓN TRIMESTRAL"),
      ]);
      sheet.appendRow([
        TextCellValue("Período: ${_getQuarterLabel(_selectedQuarter)} de $_selectedYear"),
      ]);
      sheet.appendRow([TextCellValue("")]);

      // 2. Resumen de KPIs de Balance
      sheet.appendRow([
        TextCellValue("Cosecha Recepcionada (Campo):"),
        DoubleCellValue(_totalRecep),
        TextCellValue("cogollos"),
      ]);
      sheet.appendRow([
        TextCellValue("Producción Procesada (Planta):"),
        DoubleCellValue(_totalProc),
        TextCellValue("cogollos"),
      ]);
      sheet.appendRow([
        TextCellValue("Descarte Acumulado:"),
        DoubleCellValue(_totalRech),
        TextCellValue("cogollos"),
      ]);
      sheet.appendRow([
        TextCellValue("Rendimiento Global:"),
        TextCellValue("${_rendimientoGlobal.toStringAsFixed(1)}%"),
      ]);
      sheet.appendRow([TextCellValue("")]);

      // 3. Encabezados de Tabla
      sheet.appendRow([
        TextCellValue("Mes / Período"),
        TextCellValue("Extensionista"),
        TextCellValue("Cosecha Recepcionada (C.RECEP)"),
        TextCellValue("Producción Procesada (C.PROC)"),
        TextCellValue("Descarte (C.RECH)"),
        TextCellValue("Rendimiento %"),
      ]);

      // 4. Filas de Registros
      for (final item in _items) {
        sheet.appendRow([
          TextCellValue(_getMonthName(item.month)),
          TextCellValue(item.extensionista),
          DoubleCellValue(item.cantidadRecepcion),
          DoubleCellValue(item.cantidadProcesada),
          DoubleCellValue(item.descarte),
          TextCellValue("${item.rendimiento.toStringAsFixed(1)}%"),
        ]);
      }

      // 5. Fila de Totales
      sheet.appendRow([
        TextCellValue("TOTAL GENERAL"),
        TextCellValue("-"),
        DoubleCellValue(_totalRecep),
        DoubleCellValue(_totalProc),
        DoubleCellValue(_totalRech),
        TextCellValue("${_rendimientoGlobal.toStringAsFixed(1)}%"),
      ]);

      // 6. Guardado y Compartido Multiplataforma (Web & Android)
      final fileName = "Recepcion_y_Produccion_Trimestral_T${_selectedQuarter}_$_selectedYear.xlsx";
      final fileBytes = excel.save(fileName: fileName);

      if (fileBytes != null) {
        if (kIsWeb) {
          final xFile = XFile.fromData(
            Uint8List.fromList(fileBytes),
            name: fileName,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          );
          await SharePlus.instance.share(
            ShareParams(
              text: 'Reporte Trimestral T$_selectedQuarter/$_selectedYear',
              files: [xFile],
            ),
          );
        } else {
          final directory = await getApplicationDocumentsDirectory();
          final path = "${directory.path}/$fileName";
          File(path)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);

          final xFile = XFile(path);
          await SharePlus.instance.share(
            ShareParams(
              text: 'Reporte Trimestral T$_selectedQuarter/$_selectedYear',
              files: [xFile],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, "Error al exportar el archivo Excel: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        foregroundColor: AppColors.textDark,
        title: Text(
          "Recepción y Producción Trimestral",
          style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textDark,
              ) ??
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: AppColors.primaryGreen),
            tooltip: "Exportar a Excel (.xlsx)",
            onPressed: (_isLoading || _items.isEmpty) ? null : _exportToExcel,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Selector de Período en Material 3 (Contenedor superior)
          _buildPeriodSelector(context),
          Divider(height: 1, color: AppColors.borderGrey),

          // 2. Contenido Analítico con contención a 1024px para Web y Escritorio
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppColors.statusCancelled),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchData,
                                icon: const Icon(Icons.refresh),
                                label: const Text("Reintentar"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: AppColors.surfaceWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1024),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 2.1 Tarjetas KPI de Balance
                                _buildKPIGrid(context),
                                const SizedBox(height: 24),

                                // 2.2 Gráfica de Barras Pareadas Agrupadas (fl_chart)
                                _buildChartSection(context),
                                const SizedBox(height: 24),

                                // 2.3 Tabla de Auditoría Desglosada
                                _buildAuditTable(context),
                                const SizedBox(height: 80),
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

  /// Selector de Año y Trimestre con Material 3
  Widget _buildPeriodSelector(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currentYear = DateTime.now().year;
    final availableYears = List.generate(
      currentYear >= 2024 ? (currentYear - 2023) : 1,
      (i) => currentYear - i,
    );
    if (!availableYears.contains(_selectedYear)) {
      availableYears.add(_selectedYear);
      availableYears.sort((a, b) => b.compareTo(a));
    }

    return Container(
      color: AppColors.surfaceWhite,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.primaryGreen, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Período de Análisis:",
                      style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ) ??
                          const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                  ],
                ),

                // Selector de Año
                _buildM3Dropdown<int>(
                  value: _selectedYear,
                  items: availableYears.map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedYear) {
                      setState(() => _selectedYear = val);
                      _fetchData();
                    }
                  },
                ),

                // Selector de Trimestre
                _buildM3Dropdown<int>(
                  value: _selectedQuarter,
                  items: const [
                    DropdownMenuItem<int>(value: 1, child: Text("T1 (Ene - Mar)")),
                    DropdownMenuItem<int>(value: 2, child: Text("T2 (Abr - Jun)")),
                    DropdownMenuItem<int>(value: 3, child: Text("T3 (Jul - Sep)")),
                    DropdownMenuItem<int>(value: 4, child: Text("T4 (Oct - Dic)")),
                  ],
                  onChanged: (val) {
                    if (val != null && val != _selectedQuarter) {
                      setState(() => _selectedQuarter = val);
                      _fetchData();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildM3Dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// 4 Tarjetas KPI superiores de balance con diseño responsive
  Widget _buildKPIGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final card1 = _KPICard(
          title: "Total Recepcionado (Campo)",
          value: NumberUtils.formatCogollos(_totalRecep.round()),
          icon: Icons.agriculture_rounded,
          accentColor: AppColors.primaryGreen,
          subtitle: "Cosecha entregada a planta",
        );

        final card2 = _KPICard(
          title: "Total Procesado (Planta)",
          value: NumberUtils.formatCogollos(_totalProc.round()),
          icon: Icons.precision_manufacturing_outlined,
          accentColor: AppColors.statusHarvested,
          subtitle: "Cogollos aprovechados",
        );

        final card3 = _KPICard(
          title: "Descarte Acumulado",
          value: NumberUtils.formatCogollos(_totalRech.round()),
          icon: Icons.delete_outline,
          accentColor: AppColors.statusCancelled,
          subtitle: "Rechazo por merma o daño",
        );

        final card4 = _KPICard(
          title: "Rendimiento Global",
          value: "${_rendimientoGlobal.toStringAsFixed(1)}%",
          icon: Icons.speed_rounded,
          accentColor: _rendimientoGlobal >= 85 ? AppColors.primaryGreen : AppColors.statusUrgent,
          subtitle: "Aprovechamiento vs recepción",
          isHighlighted: true,
        );

        if (constraints.maxWidth < 650) {
          // Disposición móvil: cuadrícula de 2x2
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: card1),
                  const SizedBox(width: 12),
                  Expanded(child: card2),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: card3),
                  const SizedBox(width: 12),
                  Expanded(child: card4),
                ],
              ),
            ],
          );
        }

        // Disposición amplia: 4 columnas continuas
        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 12),
            Expanded(child: card2),
            const SizedBox(width: 12),
            Expanded(child: card3),
            const SizedBox(width: 12),
            Expanded(child: card4),
          ],
        );
      },
    );
  }

  /// Gráfica comparativa de barras agrupadas pareadas (Grouped Bar Chart)
  Widget _buildChartSection(BuildContext context) {
    final months = _getMonthsForQuarter(_selectedQuarter);

    // Preparar agregados de los 3 meses del trimestre
    final monthlyStats = months.map((m) {
      final monthItems = _items.where((item) => item.month == m);
      final recep = monthItems.fold(0.0, (sum, i) => sum + i.cantidadRecepcion);
      final proc = monthItems.fold(0.0, (sum, i) => sum + i.cantidadProcesada);
      final rend = recep > 0 ? (proc / recep * 100) : 0.0;
      return _MonthBarSummary(
        month: m,
        monthName: _getMonthName(m),
        shortMonthName: _getShortMonthName(m),
        cantidadRecepcion: recep,
        cantidadProcesada: proc,
        rendimiento: rend,
      );
    }).toList();

    double maxVal = 0.0;
    for (final s in monthlyStats) {
      if (s.cantidadRecepcion > maxVal) maxVal = s.cantidadRecepcion;
      if (s.cantidadProcesada > maxVal) maxVal = s.cantidadProcesada;
    }
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.35;

    return Container(
      height: 360,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Leyenda Superior
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendPill(AppColors.primaryGreen, "Cosecha Recepcionada (Campo)"),
              const SizedBox(width: 24),
              _buildLegendPill(AppColors.statusHarvested, "Producción Procesada (Planta)"),
            ],
          ),
          const SizedBox(height: 16),

          // Gráfico de Barras Agrupadas
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Text(
                      "Sin registros de producción en el trimestre seleccionado",
                      style: TextStyle(color: AppColors.iconGrey, fontSize: 13),
                    ),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          tooltipMargin: 8,
                          tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          getTooltipColor: (_) => AppColors.textDark,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final stat = monthlyStats[group.x.toInt()];
                            final isRecep = rodIndex == 0;
                            final label = isRecep ? "Recepción" : "Procesado";
                            final cogollosText = NumberUtils.formatCogollos(rod.toY.round());

                            if (!isRecep) {
                              return BarTooltipItem(
                                '${stat.monthName}\n$label: $cogollosText\n${stat.rendimiento.toStringAsFixed(1)}% aprovechado',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            }
                            return BarTooltipItem(
                              '${stat.monthName}\n$label: $cogollosText',
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
                        // Badge de Rendimiento Mensual en el eje superior
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < monthlyStats.length) {
                                final stat = monthlyStats[index];
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreenLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${stat.rendimiento.toStringAsFixed(1)}% aprovechado",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        // Nombres cortos de los meses en el eje inferior
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < monthlyStats.length) {
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  space: 6,
                                  child: Text(
                                    monthlyStats[index].shortMonthName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
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
                                style: const TextStyle(fontSize: 10, color: AppColors.iconGrey),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.borderGrey.withValues(alpha: 0.5),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(monthlyStats.length, (i) {
                        final stat = monthlyStats[i];
                        return BarChartGroupData(
                          x: i,
                          barsSpace: 8,
                          barRods: [
                            // Barra 0: Recepción (Campo)
                            BarChartRodData(
                              toY: stat.cantidadRecepcion,
                              color: AppColors.primaryGreen,
                              width: 26,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                            // Barra 1: Procesamiento (Planta)
                            BarChartRodData(
                              toY: stat.cantidadProcesada,
                              color: AppColors.statusHarvested,
                              width: 26,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  /// Tabla de auditoría desglosada por mes y extensionista
  Widget _buildAuditTable(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Detalle de Recepción vs Producción",
                  style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ) ??
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${_items.length} registros",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderGrey),

          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                  "No hay registros disponibles para este trimestre.",
                  style: TextStyle(color: AppColors.iconGrey),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.primaryGreenLight),
                dataRowMinHeight: 44,
                dataRowMaxHeight: 56,
                columnSpacing: 22,
                columns: const [
                  DataColumn(
                    label: Text("Mes / Período", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text("Extensionista", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: Text("Cosecha (Recep)", style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text("Procesado (Planta)", style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text("Descarte", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusCancelled)),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text("Rendimiento %", style: TextStyle(fontWeight: FontWeight.bold)),
                    numeric: true,
                  ),
                ],
                rows: [
                  // Filas de datos individuales
                  ..._items.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            _getMonthName(item.month),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                        ),
                        DataCell(
                          Text(item.extensionista, style: const TextStyle(color: AppColors.textDark)),
                        ),
                        DataCell(
                          Text(
                            NumberUtils.formatNumber(item.cantidadRecepcion.round()),
                            style: const TextStyle(color: AppColors.textDark),
                          ),
                        ),
                        DataCell(
                          Text(
                            NumberUtils.formatNumber(item.cantidadProcesada.round()),
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                          ),
                        ),
                        DataCell(
                          Text(
                            NumberUtils.formatNumber(item.descarte.round()),
                            style: const TextStyle(color: AppColors.statusCancelled, fontWeight: FontWeight.w500),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.rendimiento >= 85
                                  ? AppColors.primaryGreenLight
                                  : AppColors.statusCancelledBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${item.rendimiento.toStringAsFixed(1)}%",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: item.rendimiento >= 85
                                    ? AppColors.primaryGreen
                                    : AppColors.statusCancelled,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),

                  // Fila de TOTALES
                  DataRow(
                    color: WidgetStateProperty.all(AppColors.searchBarFill),
                    cells: [
                      const DataCell(
                        Text("TOTAL GENERAL", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
                      ),
                      const DataCell(Text("-", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(
                        Text(
                          NumberUtils.formatNumber(_totalRecep.round()),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                      ),
                      DataCell(
                        Text(
                          NumberUtils.formatNumber(_totalProc.round()),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                      ),
                      DataCell(
                        Text(
                          NumberUtils.formatNumber(_totalRech.round()),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusCancelled),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "${_rendimientoGlobal.toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.surfaceWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Widget individual para tarjeta de KPI de balance
class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String subtitle;
  final bool isHighlighted;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.subtitle,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? accentColor.withValues(alpha: 0.5) : AppColors.borderGrey,
          width: isHighlighted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.iconGrey,
                        fontSize: 11,
                      ) ??
                      const TextStyle(fontSize: 11, color: AppColors.iconGrey, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.textDark,
                ) ??
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.iconGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

