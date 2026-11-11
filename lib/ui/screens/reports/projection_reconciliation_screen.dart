import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/dropdown_constants.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../logic/providers/projection_provider.dart';
import '../../common/custom_dropdown.dart';

class ProjectionReconciliationScreen extends StatefulWidget {
  const ProjectionReconciliationScreen({super.key});

  @override
  State<ProjectionReconciliationScreen> createState() => _ProjectionReconciliationScreenState();
}

class _ProjectionReconciliationScreenState extends State<ProjectionReconciliationScreen> {
  // Mapa auxiliar para mostrar nombres de meses legibles en el AppBar
  final List<String> _nombreMeses = [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Carga inicial automatica del mes actual
      final DateTime now = DateTime.now();
      context.read<ProjectionProvider>().fetchReport(now.year, now.month);
    });
  }

  // Formateador analítico para añadir comas de mil a valores enteros grandes
  String _formatNumber(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectionProvider = Provider.of<ProjectionProvider>(context);
    final String mesActualTexto = _nombreMeses[projectionProvider.selectedMonth - 1];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      
      // 1. HEADER OPTIMIZADO CON FILTROS INTEGRADOS EN LA ESQUINA DERECHA
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Proyeción de Cosecha', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Período de Análisis: $mesActualTexto de ${projectionProvider.selectedYear}', 
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111811),
        elevation: 0.5,
        actions: [
          // Selector de Mes estilizado en el AppBar
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: projectionProvider.selectedMonth,
              icon: const Icon(Icons.filter_list, color: Color(0xFF2F7F34)),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111811)),
              onChanged: (nuevoMes) {
                if (nuevoMes != null) {
                  projectionProvider.fetchReport(projectionProvider.selectedYear, nuevoMes);
                }
              },
              items: List.generate(12, (index) => index + 1).map((int value) {
                return DropdownMenuItem<int>(
                  value: value, 
                  child: Text(_nombreMeses[value - 1], style: const TextStyle(fontSize: 13))
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          // Selector de Año estilizado en el AppBar
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: projectionProvider.selectedYear,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111811)),
              onChanged: (nuevoAnio) {
                if (nuevoAnio != null) {
                  projectionProvider.fetchReport(nuevoAnio, projectionProvider.selectedMonth);
                }
              },
              items: [2025, 2026].map((int value) {
                return DropdownMenuItem<int>(
                  value: value, 
                  child: Text(value.toString(), style: const TextStyle(fontSize: 13))
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      
      body: projectionProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : projectionProvider.errorMessage != null
              ? Center(child: Text(projectionProvider.errorMessage!, style: const TextStyle(color: Colors.red)))
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. SECCIÓN DE KPIs CLAROS CON SUBTÍTULOS TEMPORALES
                      _buildKpiDashboard(projectionProvider, mesActualTexto),
                      const SizedBox(height: 16),
                      
                      Text(
                        'MATRIZ COMPARATIVA DE CONTROL ($mesActualTexto.)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),

                      // 3. SECCIÓN PRINCIPAL: TABLA COMPLETA CON TODAS LAS COLUMNAS REQUERIDAS
                      Expanded(
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: Colors.white,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // header fijo de la tabla
                                    DataTable(
                                      headingRowColor: WidgetStateProperty.all(const Color(0xFF2F7F34).withValues(alpha: 0.04)),
                                      columnSpacing: 24,
                                      horizontalMargin: 12,
                                      columns: const [
                                        DataColumn(label: SizedBox(width: 70, child: Text('DCTO', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 160, child: Text('PRODUCTOR', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 80, child: Text('ZONA', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 90, child: Text('ESTADO', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 70, child: Text('C.RECH', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 80, child: Text('C.RECEP', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        //DataColumn(label: SizedBox(width: 80, child: Text('C.PROC', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 90, child: Text('PROM. HIST', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 95, child: Text('F.CORTE', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 120, child: Text('PROGRAMADOR', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 95, child: Text('PROX.CORTE', style: TextStyle(fontWeight: FontWeight.bold)))),
                                        DataColumn(label: SizedBox(width: 250, child: Text('OBSERVACIONES', style: TextStyle(fontWeight: FontWeight.bold)))),
                                      ],
                                      rows: const [], // No renderiza filas aquí para mantenerse estático
                                    ),

                                    // Body de la tabla
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.vertical,
                                        child: DataTable(
                                          headingRowHeight: 0, // Oculta los header nativos duplicados
                                          columnSpacing: 24,
                                          horizontalMargin: 12,
                                          columns: const [
                                            DataColumn(label: SizedBox(width: 70)),
                                            DataColumn(label: SizedBox(width: 160)),
                                            DataColumn(label: SizedBox(width: 80)),
                                            DataColumn(label: SizedBox(width: 90)),
                                            DataColumn(label: SizedBox(width: 70)),
                                            //DataColumn(label: SizedBox(width: 80)),
                                            DataColumn(label: SizedBox(width: 80)),
                                            DataColumn(label: SizedBox(width: 90)),
                                            DataColumn(label: SizedBox(width: 95)),
                                            DataColumn(label: SizedBox(width: 120)),
                                            DataColumn(label: SizedBox(width: 95)),
                                            DataColumn(label: SizedBox(width: 250)),
                                          ],
                                          rows: projectionProvider.reportItems.map((item) {
                                            return DataRow(
                                              cells: [
                                                DataCell(SizedBox(width: 70, child: Text(item.dctoCode ?? '-', style: TextStyle(color: Colors.grey[700]), overflow: TextOverflow.ellipsis))),
                                                DataCell(SizedBox(width: 160, child: Text(item.productor, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))),
                                                DataCell(SizedBox(width: 80, child: Text(item.zona, overflow: TextOverflow.ellipsis))),
                                                DataCell(SizedBox(width: 90, child: Align(alignment: Alignment.centerLeft, child: _buildStatusBadge(item.statusReconciliacion)))),
                                                // Datos de volumen y promedios
                                                DataCell(SizedBox(width: 70, child: Text(item.statusReconciliacion == 'FALTANTE' ? '0' : '0', overflow: TextOverflow.ellipsis))), 
                                                DataCell(SizedBox(width: 80, child: Text(item.cantidadRecepcion > 0 ? _formatNumber(item.cantidadRecepcion) : '0', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))),
                                                //DataCell(SizedBox(width: 80, child: Text(_formatNumber(item.cantidadReal), style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))), 
                                                DataCell(SizedBox(width: 90, child: Text(_formatNumber(item.cantidadProyeccionHistorica), style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))), 
                                                // Datos logísticos de fechas
                                                DataCell(SizedBox(width: 95, child: Text(item.statusReconciliacion != 'FALTANTE' ? '${item.year}-${item.month.toString().padLeft(2, '0')}-05' : '-', overflow: TextOverflow.ellipsis))), 
                                                DataCell(SizedBox(width: 120, child: Text(item.programador, overflow: TextOverflow.ellipsis))),
                                                DataCell(SizedBox(width: 95, child: Text(item.statusReconciliacion != 'FALTANTE' ? '${item.year}-${(item.month + 4).toString().padLeft(2, '0')}-05' : '-', overflow: TextOverflow.ellipsis))),

                                                // Celda de Justificaciones con el Dropdown Integrado
                                                DataCell(
                                                  SizedBox(
                                                    width: 250,
                                                    child: item.statusReconciliacion == 'FALTANTE'
                                                        ? CustomDropdown(
                                                            value: item.observaciones,
                                                            items: DropdownConstants.noHarvestReasons,
                                                            hint: 'Seleccionar causa...',
                                                            isEnabled: true,
                                                            onChanged: (newValue) async {
                                                              if (newValue != null && item.projectionId != null) {
                                                                final success = await projectionProvider.updateNoHarvestReason(item.projectionId!, newValue);
                                                                if (success) {
                                                                  SnackbarUtils.showSuccess(context, 'Causa guardada con éxito.');
                                                                } else {
                                                                  SnackbarUtils.showError(context, 'Error al conectar con Supabase.');
                                                                }
                                                              }
                                                            },
                                                          )
                                                        : Padding(
                                                            padding: const EdgeInsets.only(left: 4.0),
                                                            child: Text(
                                                              item.observaciones ?? 'OK',
                                                              style: TextStyle(
                                                                color: item.statusReconciliacion == 'OK' ? Colors.green[700] : Colors.blue[700],
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildKpiDashboard(ProjectionProvider provider, String mesTexto) {
    final bool esSobreproduccion = provider.porcentajeCobertura > 100.0;
    final MaterialColor coberturaColor = esSobreproduccion ? Colors.deepPurple : Colors.blue;
    final String coberturaSubtitulo = esSobreproduccion ? 'Excedente de Planta' : 'Eficiencia del mes';

    return Row(
      children: [
        _buildKpiCard('CANTIDAD RECIBIDA', _formatNumber(provider.totalLogrado), 'Total ingresado en $mesTexto', Colors.green, Icons.inventory_2_outlined),
        const SizedBox(width: 6),
        _buildKpiCard('CANTIDAD PROYECTADA', _formatNumber(provider.totalProyectado), 'Meta estimada de $mesTexto', Colors.orange, Icons.analytics_outlined),
        const SizedBox(width: 6),
        _buildKpiCard('CANTIDAD NO COSECHADA', _formatNumber(provider.totalNoCosechado), 'Pérdida de los FALTANTES', Colors.red, Icons.gpp_bad_outlined),
        const SizedBox(width: 6),
        _buildKpiCard('RECEPCIÓN INESPERADA', _formatNumber(provider.totalInesperado), 'Fuera de programa', Colors.teal, Icons.assignment_turned_in_outlined),
        const SizedBox(width: 6),
        _buildKpiCard('COBERTURA', '${provider.porcentajeCobertura.toStringAsFixed(1)}%', coberturaSubtitulo, coberturaColor, Icons.pie_chart_outline),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, String subtitle, MaterialColor color, IconData icon) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color[50], 
              child: Icon(icon, color: color[700], size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Incremento responsive del valor principal (fontSize: 18)
                  Text(
                    title, 
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color[700]), 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111811)), 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500), 
                    overflow: TextOverflow.ellipsis
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backColor;
    Color textColor;
    
    switch (status) {
      case 'OK':
        backColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        break;
      case 'FALTANTE':
        backColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        break;
      default:
        backColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: backColor, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
