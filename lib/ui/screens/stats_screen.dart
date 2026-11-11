import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/number_utils.dart';
import '../../data/models/stats_model.dart';
import '../../logic/providers/stats_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // Paleta de colores para la dona de distribución por zonas
  final List<Color> _colorPalette = [
    AppColors.primaryGreen,
    AppColors.statusUrgent,
    AppColors.statusHarvested,
    AppColors.statusVisited,
    AppColors.statusCancelled,
    AppColors.statusOverdue,
    Colors.teal,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.pink,
    Colors.brown,
    Colors.lime,
    Colors.deepOrange,
    Colors.lightBlue,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StatsProvider>().loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = context.watch<StatsProvider>();

    // 1. Estado de carga
    if (statsProvider.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // 2. Estado de error / Sin conexión
    if (statsProvider.hasError) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.iconGrey,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Sin conexión a internet",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "El panel de estadísticas requiere conexión activa para calcular datos en tiempo real",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.iconGrey,
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.read<StatsProvider>().retry(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: AppColors.surfaceWhite,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, color: AppColors.surfaceWhite),
                    label: const Text(
                      "Reintentar",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 3. Preparación de datos para la vista
    final monthlyData = statsProvider.monthlyData;
    List<MonthlyStat> visibleBars = monthlyData;
    if (visibleBars.length > 6) {
      visibleBars = visibleBars.sublist(visibleBars.length - 6);
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        title: Text(
          "Panel de Estadísticas",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: () => context.read<StatsProvider>().loadInitialData(),
          ),
        ],
        // BARRA INFERIOR CON EL DROPDOWN (Adaptado a maxWidth: 1024)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1024),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                child: DropdownMenu<MonthlyStat?>(
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: statsProvider.selectedMonth,
                  enableFilter: false,
                  enableSearch: false,
                  requestFocusOnTap: false,
                  leadingIcon: const Icon(Icons.calendar_month, color: AppColors.primaryGreen),
                  textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                        fontSize: 14,
                      ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderGrey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.borderGrey),
                    ),
                  ),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<MonthlyStat?>(
                      value: null,
                      label: 'Histórico Global (Todos los meses)',
                    ),
                    ...statsProvider.availableMonths.map((MonthlyStat monthStat) {
                      return DropdownMenuEntry<MonthlyStat?>(
                        value: monthStat,
                        label: '${monthStat.monthName} ${monthStat.year}',
                      );
                    }),
                  ],
                  onSelected: (MonthlyStat? newValue) {
                    context.read<StatsProvider>().loadFilteredData(newValue);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      // CUERPO ADAPTADO A DESKTOP / WEB (maxWidth: 1024)
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. KPIS (Tarjetas Superiores)
                _buildKpiSection(context, statsProvider),
                const SizedBox(height: 24),

                // 2. GRAFICO DE BARRAS (Histórico)
                _buildBarChartCard(context, visibleBars),
                const SizedBox(height: 24),

                // 3. GRAFICO DE DONA (Zonas)
                _buildPieChartCard(context, statsProvider),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SECCIONES UI ---
  Widget _buildKpiSection(BuildContext context, StatsProvider provider) {
    final double totalVisible = provider.zoneData.fold(0, (sum, item) => sum + item.totalQuantity);

    return Column(
      children: [
        // Tarjeta Grande: Productores Activos
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowLight,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Productores Activos",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.iconGrey,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberUtils.formatNumber(provider.kpis['total_producers'] ?? 0),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                        ),
                  ),
                ],
              ),
              const Icon(Icons.group, size: 40, color: AppColors.primaryGreen),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Tarjetas Pequeñas
        Row(
          children: [
            Expanded(
              child: _SmallKpiCard(
                title: "Cosechas Mes",
                value: NumberUtils.formatNumber(provider.kpis['harvests_month'] ?? 0),
                subtitle: provider.selectedMonth == null
                    ? "Mes Global"
                    : "En ${provider.selectedMonth!.monthName} ${provider.selectedMonth!.year}",
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SmallKpiCard(
                title: "Total Proc.",
                value: NumberUtils.formatCogollos(totalVisible),
                subtitle: provider.selectedMonth == null
                    ? "Histórico Global"
                    : "En ${provider.selectedMonth!.monthName}",
                color: AppColors.statusUrgent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChartCard(BuildContext context, List<MonthlyStat> visibleBars) {
    if (visibleBars.isEmpty) return const SizedBox.shrink();
    double maxY = visibleBars.map((e) => e.totalProcessed).reduce((a, b) => a > b ? a : b) * 1.2;
    if (maxY == 0) maxY = 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                "Rendimiento Mensual (C.PROC)",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
              ),
              const Icon(Icons.bar_chart, color: AppColors.primaryGreen),
            ],
          ),
          const SizedBox(height: 24),
          // GRAFICO DE BARRAS
          SizedBox(
            height: 280,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.textDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        NumberUtils.formatNumber(rod.toY.round()),
                        const TextStyle(
                          color: AppColors.surfaceWhite,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  // EJE X (Meses) - Lógica y extracción preservadas intactas
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < visibleBars.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              visibleBars[value.toInt()].monthName,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: visibleBars.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    showingTooltipIndicators: const [0],
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.totalProcessed,
                        color: AppColors.primaryGreen,
                        width: 24,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.scaffoldBackground,
                        ),
                      )
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard(BuildContext context, StatsProvider provider) {
    final zoneData = provider.zoneData;
    if (zoneData.isEmpty) {
      return Center(
        child: Text(
          "No hay datos para este mes.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.iconGrey),
        ),
      );
    }

    final double totalProc = zoneData.fold(0, (sum, item) => sum + item.totalQuantity);
    final double totalRecep = zoneData.fold(0, (sum, item) => sum + item.totalReceived);

    // Título dinámico según período seleccionado
    final String zoneTitle = provider.selectedMonth == null
        ? "Distribución por Zonas (Histórico Global)"
        : "Distribución por Zonas - ${provider.selectedMonth!.monthName} ${provider.selectedMonth!.year}";

    // Subtítulo dinámico para el banner de total recepcionado
    final String recepSubtitle = provider.selectedMonth == null
        ? "(C.RECEP HISTÓRICO GLOBAL)"
        : "(C.RECEP - ${provider.selectedMonth!.monthName} ${provider.selectedMonth!.year})";

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeTablet = screenWidth > 800;

    final double containerHeight = isLargeTablet ? 320 : (isTablet ? 260 : 200);
    final double centerRadius = isLargeTablet ? 80 : (isTablet ? 60 : 40);
    final double sectionRadius = isLargeTablet ? 50 : (isTablet ? 35 : 28);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zoneTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: containerHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LADO GRAFICO (50%)
                Expanded(
                  flex: 1,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: centerRadius,
                      sections: zoneData.asMap().entries.map((entry) {
                        final index = entry.key % _colorPalette.length;
                        return PieChartSectionData(
                          color: _colorPalette[index],
                          value: entry.value.totalQuantity,
                          title:
                              '${((entry.value.totalQuantity / (totalProc == 0 ? 1 : totalProc)) * 100).toStringAsFixed(0)}%',
                          radius: sectionRadius,
                          titleStyle: TextStyle(
                            fontSize: isLargeTablet ? 12 : 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.surfaceWhite,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // LADO LEYENDA ZONAS
                Expanded(
                  flex: 1,
                  child: Scrollbar(
                    thumbVisibility: isTablet,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Column(
                          children: zoneData.asMap().entries.map((entry) {
                            final index = entry.key % _colorPalette.length;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _colorPalette[index],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entry.value.zoneName,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontSize: isTablet ? 14 : 12,
                                            color: AppColors.iconGrey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    NumberUtils.formatCogollos(entry.value.totalQuantity),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontSize: isTablet ? 13 : 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // SECCION TOTAL RECEPCIONADO (Con subtítulo dinámico y NumberUtils)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryGreenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL RECEPCIONADO",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      recepSubtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primaryGreen.withValues(alpha: 0.8),
                            fontSize: 8,
                          ),
                    ),
                  ],
                ),
                Text(
                  NumberUtils.formatCogollos(totalRecep),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primaryGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _SmallKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.iconGrey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
