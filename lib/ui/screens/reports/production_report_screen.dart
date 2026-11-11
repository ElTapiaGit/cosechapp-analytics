import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cosecha_app/core/theme/app_colors.dart';
import 'package:cosecha_app/core/utils/number_utils.dart';
import '../../../data/models/production_report_model.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/utils/error_translator.dart';

class ProductionReportScreen extends StatefulWidget {
  const ProductionReportScreen({super.key});

  @override
  State<ProductionReportScreen> createState() => _ProductionReportScreenState();
}

class _ProductionReportScreenState extends State<ProductionReportScreen> {
  // Filtros dinámicos
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  
  List<DateTime> _availablePeriods = [];
  bool _isLoadingPeriods = true;

  bool _isLoading = false;
  List<ProductionReportItem> _data = [];

  @override
  void initState() {
    super.initState();
    _loadAvailablePeriods();
  }

  // Consulta los períodos reales con registros desde Supabase (vista monthly_stats)
  Future<void> _loadAvailablePeriods() async {
    try {
      final response = await Supabase.instance.client
          .from('monthly_stats')
          .select('year, month')
          .order('year', ascending: false)
          .order('month', ascending: false);

      final List<DateTime> loaded = (response as List).map((row) {
        final y = (row['year'] as num).toInt();
        final m = (row['month'] as num).toInt();
        return DateTime(y, m, 1);
      }).toSet().toList();

      if (mounted) {
        setState(() {
          _availablePeriods = loaded;
          _isLoadingPeriods = false;
          if (loaded.isNotEmpty) {
            _selectedYear = loaded.first.year;
            _selectedMonth = loaded.first.month;
          }
        });
        if (loaded.isNotEmpty) {
          _fetchData();
        }
      }
    } catch (e) {
      debugPrint("Error cargando periodos: $e");
      if (mounted) {
        setState(() => _isLoadingPeriods = false);
      }
    }
  }

  // Formateador de etiqueta de período (ej. "Noviembre 2026")
  String _formatPeriodLabel(DateTime date) {
    const monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return "${monthNames[date.month - 1]} ${date.year}";
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('production_summary_report')
          .select()
          .eq('year', _selectedYear)
          .eq('month', _selectedMonth)
          .order('cantidad_cogollos', ascending: false); // Ordenar por quien hizo mas

      final list = (response as List)
          .map((e) => ProductionReportItem.fromJson(e))
          .toList();

      setState(() {
        _data = list;
        _isLoading = false;
      });
    } catch (e) {
      final translatedMessage = ErrorTranslator.translate(e);
      if(mounted) SnackbarUtils.showError(context, translatedMessage);
      setState(() => _isLoading = false);
    }
  }

  // --- LOGICA EXCEL ---
  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Reporte Producción'];
    excel.delete('Sheet1'); // Borrar hoja default

    // 1. Encabezados
    List<String> headers = [
      "Extensionista",
      "Cant. Cogollos (C.RECEP)",
      "Descarte (C.RECH)",
      "Rendimiento Promedio", // Vacio
      "Días Cosechados",      // Vacio
      "Promedio Día/Cogollos",
      "% Cosecha"
    ];
    
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());
    
    // Aplicar estilo a la fila 1 (programáticamente es mas complejo en esta librería, simplificamos llenando datos)

    // 2. Datos
    double totalCogollos = 0;
    double totalDescarte = 0;
    double totalPromedio = 0;
    double totalPorcentaje = 0;

    for (var item in _data) {
      // Acumulamos totales
      totalCogollos += item.cantidadCogollos;
      totalDescarte += item.descarte;
      totalPromedio += item.promedioDiaCogollos;
      totalPorcentaje += item.porcentajeParticipacion;
      sheetObject.appendRow([
        TextCellValue(item.extensionista),
        DoubleCellValue(item.cantidadCogollos),
        DoubleCellValue(item.descarte),
        TextCellValue("${item.rendimientoPromedio.toStringAsFixed(1)}%"), 
        DoubleCellValue(item.diasCosecha.toDouble()), 
        DoubleCellValue(double.parse(item.promedioDiaCogollos.toStringAsFixed(2))),
        TextCellValue("${item.porcentajeParticipacion.toStringAsFixed(1)}%"),
      ]);
    }

    // 3. Fila de TOTALES (Nueva)
    sheetObject.appendRow([
      TextCellValue("TOTAL"), // Columna Extensionista
      DoubleCellValue(totalCogollos),
      DoubleCellValue(totalDescarte),
      TextCellValue(""), 
      TextCellValue(""), 
      DoubleCellValue(double.parse(totalPromedio.toStringAsFixed(2))),
      TextCellValue("${totalPorcentaje.toStringAsFixed(0)}%"), // Debería dar ~100%
    ]);

    // 4. Guardar y Compartir
    var fileBytes = excel.save(fileName: "Reporte_Produccion_${_selectedMonth}_$_selectedYear.xlsx");
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/Reporte_Produccion_${_selectedMonth}_$_selectedYear.xlsx";
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      
      final xFile = XFile(path);
      //await Share.shareXFiles([xFile], text: 'Reporte de Producción $_selectedMonth/$_selectedYear');
      final params = ShareParams(
        text: 'Reporte de Producción $_selectedMonth/$_selectedYear',
        files: [xFile],
      );

      await SharePlus.instance.share(params);

      /*if (result.status == ShareResultStatus.success) {
        print('Archivo compartido correctamente');
      } else {
        print('El usuario canceló el compartir o hubo un error');
      }*/
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Calculamos totales y estadísticas para la vista en pantalla
    double totalCogollos = 0;
    double totalDescarte = 0;
    double totalPorcentaje = 0;
    int maxDiasCosecha = 0;

    if (_data.isNotEmpty) {
      totalCogollos = _data.fold(0, (sum, item) => sum + item.cantidadCogollos);
      totalDescarte = _data.fold(0, (sum, item) => sum + item.descarte);
      totalPorcentaje = _data.fold(0, (sum, item) => sum + item.porcentajeParticipacion);
      maxDiasCosecha = _data.map((item) => item.diasCosecha).reduce((curr, next) => curr > next ? curr : next);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          "Resumen de Producción",
          style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textDark,
              ) ??
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDark),
        ),
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: AppColors.primaryGreen),
            tooltip: "Exportar a Excel",
            onPressed: _data.isEmpty ? null : _exportToExcel,
          )
        ],
      ),
      body: Column(
        children: [
          // FILTRO UNIFICADO "MES Y AÑO" MATERIAL 3 (DropdownMenu Dinámico)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceWhite,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingPeriods)
                    Container(
                      width: 250,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderGrey),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.calendar_month, color: AppColors.primaryGreen, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Cargando períodos...",
                            style: TextStyle(color: AppColors.iconGrey, fontSize: 13),
                          ),
                          Spacer(),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_availablePeriods.isNotEmpty)
                    DropdownMenu<DateTime>(
                      key: ValueKey("$_selectedYear-$_selectedMonth-${_availablePeriods.length}"),
                      width: 250,
                      initialSelection: DateTime(_selectedYear, _selectedMonth, 1),
                      enableFilter: false,
                      enableSearch: false,
                      requestFocusOnTap: false,
                      leadingIcon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen, size: 20),
                      textStyle: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ) ??
                          const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      inputDecorationTheme: InputDecorationTheme(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        fillColor: AppColors.surfaceWhite,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.borderGrey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.borderGrey),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
                        ),
                      ),
                      menuStyle: MenuStyle(
                        backgroundColor: WidgetStateProperty.all(AppColors.surfaceWhite),
                        elevation: WidgetStateProperty.all(4),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      dropdownMenuEntries: _availablePeriods.map((period) {
                        return DropdownMenuEntry<DateTime>(
                          value: period,
                          label: _formatPeriodLabel(period),
                          style: MenuItemButton.styleFrom(
                            foregroundColor: AppColors.textDark,
                          ),
                        );
                      }).toList(),
                      onSelected: (selectedDate) {
                        if (selectedDate != null && 
                           (selectedDate.year != _selectedYear || selectedDate.month != _selectedMonth)) {
                          setState(() {
                            _selectedYear = selectedDate.year;
                            _selectedMonth = selectedDate.month;
                          });
                          _fetchData();
                        }
                      },
                    )
                  else
                    Container(
                      width: 250,
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderGrey),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.calendar_month, color: AppColors.iconGrey, size: 20),
                          SizedBox(width: 12),
                          Text(
                            "Sin períodos registrados",
                            style: TextStyle(color: AppColors.iconGrey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  if (_isLoading) ...[
                    const SizedBox(width: 16),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          Divider(height: 1, color: AppColors.borderGrey),

          // TABLA DE DATOS
          Expanded(
            child: (_isLoadingPeriods || _isLoading) && _data.isEmpty 
              ? const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.primaryGreen,
                  ),
                )
              : _data.isEmpty 
                ? Center(
                    child: Text(
                      "No hay datos para este periodo",
                      style: textTheme.bodyMedium?.copyWith(color: AppColors.iconGrey),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(AppColors.primaryGreenLight),
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 60,
                            columnSpacing: 24,
                            columns: [
                              DataColumn(
                                label: Text(
                                  "EXTENSIONISTA",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "CANT.\nCOGOLLOS",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(
                                  "DESCARTE",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.statusCancelled,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(
                                  "REND.\nPROMEDIO",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.iconGrey,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "DIAS\nCOSECHA",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.iconGrey,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "PROM.\nDIA/COGOLLOS",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                                numeric: true,
                              ),
                              DataColumn(
                                label: Text(
                                  "% COSECHA",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  textAlign: TextAlign.right,
                                ),
                                numeric: true,
                              ),
                            ],
                            rows: [
                              // 1. FILAS DE DATOS POR EXTENSIONISTA
                              ..._data.map((item) {
                                return DataRow(cells: [
                                  DataCell(
                                    Text(
                                      item.extensionista,
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(item.cantidadCogollos.round()),
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(item.descarte.round()),
                                      style: textTheme.bodyMedium?.copyWith(
                                            color: AppColors.statusCancelled,
                                            fontWeight: FontWeight.w500,
                                          ) ??
                                          const TextStyle(color: AppColors.statusCancelled),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        "${item.rendimientoPromedio.toStringAsFixed(1)}%",
                                        style: textTheme.bodyMedium?.copyWith(
                                              color: AppColors.iconGrey,
                                              fontWeight: FontWeight.bold,
                                            ) ??
                                            const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ), 
                                  DataCell(
                                    Center(
                                      child: Text(
                                        "${item.diasCosecha}",
                                        style: textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textDark,
                                            ) ??
                                            const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ), 
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(item.promedioDiaCogollos.round()),
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreenLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "${item.porcentajeParticipacion.toStringAsFixed(1)}%",
                                        style: textTheme.labelSmall?.copyWith(
                                              color: AppColors.primaryGreen,
                                              fontWeight: FontWeight.bold,
                                            ) ??
                                            const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ]);
                              }),

                              // 2. FILA DE TOTALES CORREGIDA
                              DataRow(
                                color: WidgetStateProperty.all(AppColors.searchBarFill),
                                cells: [
                                  DataCell(
                                    Text(
                                      "TOTAL",
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13,
                                            color: AppColors.textDark,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(totalCogollos.round()),
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(totalDescarte.round()),
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.statusCancelled,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusCancelled),
                                    ),
                                  ),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        "$maxDiasCosecha",
                                        style: textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textDark,
                                            ) ??
                                            const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  DataCell(
                                    Text(
                                      "${totalPorcentaje.toStringAsFixed(0)}%",
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Margen de seguridad para que la fila de totales no colisione con el borde inferior
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
