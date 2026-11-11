import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:cosecha_app/core/theme/app_colors.dart';
import 'package:cosecha_app/core/utils/number_utils.dart';
import '../../../data/models/programmer_detail_model.dart';

class ProgrammerReportScreen extends StatefulWidget {
  const ProgrammerReportScreen({super.key});

  @override
  State<ProgrammerReportScreen> createState() => _ProgrammerReportScreenState();
}

class _ProgrammerReportScreenState extends State<ProgrammerReportScreen> {
  // Filtros dinámicos
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String _selectedProgrammer = 'Todos';

  List<DateTime> _availablePeriods = [];
  bool _isLoadingPeriods = true;
  List<String> _programmersList = ['Todos'];

  bool _isLoading = false;
  List<ProgrammerDetailItem> _data = [];

  @override
  void initState() {
    super.initState();
    _loadAvailablePeriods();
  }

  // 1. Cargar períodos reales desde la vista monthly_stats
  Future<void> _loadAvailablePeriods() async {
    try {
      final response = await Supabase.instance.client
          .from('monthly_stats')
          .select('year, month')
          .order('year', ascending: false)
          .order('month', ascending: false);

      final List<DateTime> loaded = (response as List).map((row) {
        return DateTime((row['year'] as num).toInt(), (row['month'] as num).toInt(), 1);
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
      if (mounted) setState(() => _isLoadingPeriods = false);
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

  // 2. Cargar datos de la tabla optimizando la lista de programadores por mes
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      var query = Supabase.instance.client
          .from('programmer_detail_report')
          .select()
          .eq('year', _selectedYear)
          .eq('month', _selectedMonth);

      // Si seleccionó un programador específico, filtramos
      if (_selectedProgrammer != 'Todos') {
        query = query.eq('programador', _selectedProgrammer);
      }

      final response = await query.order('f_corte', ascending: false);

      final list = (response as List)
          .map((e) => ProgrammerDetailItem.fromJson(e))
          .toList();

      // Si cargamos todos, actualizamos la lista disponible de programadores para este mes
      if (_selectedProgrammer == 'Todos') {
        final names = list
            .map((e) => e.programador.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        _programmersList = ['Todos', ...names];
      }

      setState(() {
        _data = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error data: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- LOGICA EXCEL CON TOTALES Y PROX_CORTE NULO SEGURO ---
  Future<void> _exportToExcel() async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Detalle Programador'];
    excel.delete('Sheet1');

    // 1. Encabezados
    List<String> headers = [
      "DCTO", "PRODUCTOR", "ZONA", "C.RECH", "C.RECEP", "C.PROC",
      "F.CORTE", "F.PROC", "PROGRAMADOR", "TRANSPORTISTA", "PROX.CORTE", "OBSERVACIONES"
    ];
    
    sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // 2. Datos y Acumuladores
    final dateFormat = DateFormat('dd/MM/yyyy');
    double totalRech = 0;
    double totalRecep = 0;
    double totalProc = 0;

    for (var item in _data) {
      totalRech += item.cRech;
      totalRecep += item.cRecep;
      totalProc += item.cProc;

      sheetObject.appendRow([
        TextCellValue(item.dcto),
        TextCellValue(item.productor),
        TextCellValue(item.zona),
        DoubleCellValue(item.cRech),
        DoubleCellValue(item.cRecep),
        DoubleCellValue(item.cProc),
        TextCellValue(dateFormat.format(item.fCorte)),
        TextCellValue(item.fProc != null ? dateFormat.format(item.fProc!) : '-'),
        TextCellValue(item.programador),
        TextCellValue(item.transportista),
        TextCellValue(item.proxCorte != null ? dateFormat.format(item.proxCorte!) : '-'),
        TextCellValue(item.observaciones),
      ]);
    }

    // 3. Fila de TOTALES
    sheetObject.appendRow([
      TextCellValue("TOTAL"),
      TextCellValue("-"),
      TextCellValue("-"),
      DoubleCellValue(totalRech),
      DoubleCellValue(totalRecep),
      DoubleCellValue(totalProc),
      TextCellValue("-"),
      TextCellValue("-"),
      TextCellValue("-"),
      TextCellValue("-"),
      TextCellValue("-"),
      TextCellValue("-"),
    ]);

    // 4. Guardar y Compartir
    var fileBytes = excel.save(fileName: "Reporte_Programadores_${_selectedMonth}_$_selectedYear.xlsx");
    if (fileBytes != null) {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/Reporte_Programadores_${_selectedMonth}_$_selectedYear.xlsx";
      File(path)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      
      final xFile = XFile(path);
      final params = ShareParams(
        text: 'Reporte de Programadores $_selectedMonth/$_selectedYear',
        files: [xFile],
      );

      await SharePlus.instance.share(params);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat('dd/MM/yy');

    // Cálculo de totales agregados
    final totalRech = _data.fold<double>(0, (sum, i) => sum + i.cRech);
    final totalRecep = _data.fold<double>(0, (sum, i) => sum + i.cRecep);
    final totalProc = _data.fold<double>(0, (sum, i) => sum + i.cProc);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          "Desempeño Programadores",
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
          // CABECERA COMPACTA EN UNA FILA HORIZONTAL (Material 3)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceWhite,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // 1. Selector de Período (DropdownMenu M3)
                  if (_isLoadingPeriods)
                    Container(
                      width: 240,
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
                            "Cargando...",
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
                      key: ValueKey("period-$_selectedYear-$_selectedMonth-${_availablePeriods.length}"),
                      width: 240,
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
                            _selectedProgrammer = 'Todos';
                          });
                          _fetchData();
                        }
                      },
                    ),

                  // 2. Selector de Programador (DropdownMenu M3)
                  DropdownMenu<String>(
                    key: ValueKey("prog-$_selectedProgrammer-${_programmersList.length}"),
                    width: 240,
                    initialSelection: _selectedProgrammer,
                    enableFilter: false,
                    enableSearch: false,
                    requestFocusOnTap: false,
                    leadingIcon: const Icon(Icons.person, color: AppColors.primaryGreen, size: 20),
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
                    dropdownMenuEntries: _programmersList.map((prog) {
                      return DropdownMenuEntry<String>(
                        value: prog,
                        label: prog,
                        style: MenuItemButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                        ),
                      );
                    }).toList(),
                    onSelected: (val) {
                      if (val != null && val != _selectedProgrammer) {
                        setState(() {
                          _selectedProgrammer = val;
                        });
                        _fetchData();
                      }
                    },
                  ),

                  if (_isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          Divider(height: 1, color: AppColors.borderGrey),

          // TABLA DE DATOS DE ANCHO LIBRE CON TOTALES
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
                      "No se encontraron registros para este período.",
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
                            columnSpacing: 20,
                            columns: [
                              DataColumn(
                                label: Text(
                                  "DCTO",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "PRODUCTOR",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "ZONA",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "C.RECH",
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
                                  "C.RECEP",
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
                                  "C.PROC",
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
                                  "F.CORTE",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "F.PROC",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "PROGRAMADOR",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "TRANSPORTISTA",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "PROX.CORTE",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  "OBSERVACIONES",
                                  style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                            rows: [
                              // 1. Filas de datos
                              ..._data.map((item) {
                                return DataRow(cells: [
                                  DataCell(
                                    Text(
                                      item.dcto,
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.productor,
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.zona,
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.iconGrey),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(item.cRech.round()),
                                      style: textTheme.bodyMedium?.copyWith(
                                            color: AppColors.statusCancelled,
                                            fontWeight: FontWeight.w500,
                                          ) ??
                                          const TextStyle(color: AppColors.statusCancelled),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(item.cRecep.round()),
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(item.cProc.round()),
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      dateFormat.format(item.fCorte),
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.fProc != null ? dateFormat.format(item.fProc!) : '-',
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.programador,
                                      style: textTheme.bodyMedium?.copyWith(
                                            color: AppColors.primaryGreen,
                                            fontWeight: FontWeight.bold,
                                          ) ??
                                          const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.transportista,
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.proxCorte != null ? dateFormat.format(item.proxCorte!) : '-',
                                      style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        item.observaciones.isNotEmpty ? item.observaciones : '-',
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium?.copyWith(color: AppColors.textDark),
                                      ),
                                    ),
                                  ),
                                ]);
                              }),

                              // 2. Fila de TOTALES
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
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(totalRech.round()),
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.statusCancelled,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusCancelled),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(totalRecep.round()),
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      NumberUtils.formatNumber(totalProc.round()),
                                      style: textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ) ??
                                          const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                  const DataCell(Center(child: Text("-", style: TextStyle(fontWeight: FontWeight.bold)))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Margen de seguridad inferior
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
