import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cosecha_app/core/theme/app_colors.dart';
import 'package:cosecha_app/core/utils/number_utils.dart';
import '../../../logic/providers/quarterly_dashboard_provider.dart';

class QuarterlyDashboardView extends StatelessWidget {
  const QuarterlyDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumir directamente la instancia global provista en main.dart sin re-instanciación
    return const _QuarterlyDashboardContent();
  }
}

class _QuarterlyDashboardContent extends StatefulWidget {
  const _QuarterlyDashboardContent();

  @override
  State<_QuarterlyDashboardContent> createState() => _QuarterlyDashboardContentState();
}

class _QuarterlyDashboardContentState extends State<_QuarterlyDashboardContent> {
  int _selectedSegment = 0; // 0: Tendencia, 1: Zonas, 2: Extensionistas

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<QuarterlyDashboardProvider>();
      if (provider.trendData.isEmpty && !provider.isLoading) {
        provider.fetchData();
      }
    });
  }

  Widget _buildDropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGrey),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuarterlyDashboardProvider>();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          "Reporte Trimestral",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ) ??
              const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      body: Column(
        children: [
          // 1. Capa de Filtros Globales
          _buildFilters(context, provider),
          Divider(height: 1, color: AppColors.borderGrey),
          
          Expanded(
            child: provider.isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : provider.errorMessage != null
                    ? Center(child: Text(provider.errorMessage!, style: const TextStyle(color: AppColors.statusCancelled)))
                    : Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1024),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 2. Capa de Métricas de Rendimiento
                                _buildKPIs(context, provider),
                                const SizedBox(height: 24),
                                
                                // 3. Capa de Segmentación Visual
                                _buildSegmentControl(),
                                const SizedBox(height: 24),
                                
                                // Gráficos
                                _buildChart(provider),
                                
                                const SizedBox(height: 80), // Espacio bottom
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

  Widget _buildFilters(BuildContext context, QuarterlyDashboardProvider provider) {
    final textTheme = Theme.of(context).textTheme;
    final currentYear = DateTime.now().year;
    final availableYears = List.generate(
      currentYear >= 2024 ? (currentYear - 2023) : 1,
      (i) => currentYear - i,
    );
    if (!availableYears.contains(provider.selectedYear)) {
      availableYears.add(provider.selectedYear);
      availableYears.sort((a, b) => b.compareTo(a));
    }

    return Container(
      color: AppColors.surfaceWhite,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Periodo:",
                  style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ) ??
                      const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const Spacer(),
                // Selector de Año estilizado M3
                _buildDropdownContainer(
                  child: DropdownButton<int>(
                    value: provider.selectedYear,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                    style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                    items: availableYears.map((year) => 
                      DropdownMenuItem(value: year, child: Text(year.toString()))
                    ).toList(),
                    onChanged: (val) {
                      if (val != null) provider.setFilter(val, provider.selectedQuarter);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Selector de Trimestre estilizado M3
                _buildDropdownContainer(
                  child: DropdownButton<int>(
                    value: provider.selectedQuarter,
                    icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
                    style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("T1 (Ene-Mar)")),
                      DropdownMenuItem(value: 2, child: Text("T2 (Abr-Jun)")),
                      DropdownMenuItem(value: 3, child: Text("T3 (Jul-Sep)")),
                      DropdownMenuItem(value: 4, child: Text("T4 (Oct-Dic)")),
                    ],
                    onChanged: (val) {
                      if (val != null) provider.setFilter(provider.selectedYear, val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKPIs(BuildContext context, QuarterlyDashboardProvider provider) {
    final variance = provider.variancePercentage;
    final isPositive = variance >= 0;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: "Producción Total",
                value: NumberUtils.formatCogollos(provider.totalProcessed.round()),
                icon: Icons.inventory_2,
                color: AppColors.primaryGreen,
                subtitle: "${isPositive ? '▲ +' : '▼ '}${variance.toStringAsFixed(1)}% vs ant.",
                subtitleColor: isPositive ? AppColors.primaryGreen : AppColors.statusCancelled,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: "Eficiencia",
                value: "${provider.efficiency.toStringAsFixed(1)}%",
                icon: Icons.speed,
                color: AppColors.statusHarvested,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: "Descarte",
                value: NumberUtils.formatCogollos(provider.totalRejected.round()),
                icon: Icons.delete_outline,
                color: AppColors.statusCancelled,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentControl() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text("Tendencia"), icon: Icon(Icons.bar_chart)),
        ButtonSegment(value: 1, label: Text("Zonas"), icon: Icon(Icons.pie_chart)),
        ButtonSegment(value: 2, label: Text("Equipo"), icon: Icon(Icons.people)),
      ],
      selected: {_selectedSegment},
      onSelectionChanged: (Set<int> newSelection) {
        setState(() {
          _selectedSegment = newSelection.first;
        });
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryGreenLight;
            return AppColors.surfaceWhite;
          },
        ),
        foregroundColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryGreen;
            return AppColors.textDark;
          },
        ),
        iconColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryGreen;
            return AppColors.iconGrey;
          },
        ),
      ),
    );
  }

  Widget _buildChart(QuarterlyDashboardProvider provider) {
    return Container(
      height: 350,
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
          )
        ],
      ),
      child: () {
        switch (_selectedSegment) {
          case 0: return _buildTrendChart(provider);
          case 1: return _buildZoneChart(provider);
          case 2: return _buildProgrammerChart(provider);
          default: return const SizedBox();
        }
      }(),
    );
  }

  Widget _buildTrendChart(QuarterlyDashboardProvider provider) {
    final trendData = provider.monthlyProductionTrend;
    if (trendData.isEmpty || trendData.every((val) => val == 0)) {
      return const Center(child: Text("Sin datos para tendencia"));
    }

    final maxY = trendData.reduce((a, b) => a > b ? a : b) * 1.2;
    final quarterMonths = _getQuarterMonthNames(provider.selectedQuarter);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY == 0 ? 100 : maxY,
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(4),
            tooltipMargin: 4,
            getTooltipColor: (_) => Colors.transparent,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                NumberUtils.formatNumber(rod.toY.round()),
                const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index >= 0 && index < quarterMonths.length) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6,
                    child: Text(
                      quarterMonths[index],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ) ??
                          const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            fontSize: 12,
                          ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < trendData.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: [0],
              barRods: [
                BarChartRodData(
                  toY: trendData[i],
                  color: AppColors.primaryGreen,
                  width: 38,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                )
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildZoneChart(QuarterlyDashboardProvider provider) {
    final zoneData = provider.zoneDistributionMap;
    if (zoneData.isEmpty) {
      return const Center(child: Text("Sin datos para zonas"));
    }

    final sortedEntries = zoneData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final textTheme = Theme.of(context).textTheme;

    return ListView.builder(
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final percent = provider.totalProcessed > 0 ? (entry.value / provider.totalProcessed) : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textDark) ??
                          const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    NumberUtils.formatCogollos(entry.value.round()),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.iconGrey) ??
                        const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: percent,
                backgroundColor: AppColors.searchBarFill,
                color: AppColors.primaryGreen,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgrammerChart(QuarterlyDashboardProvider provider) {
    final progData = provider.programmerPerformanceMap;
    if (progData.isEmpty) {
      return const Center(child: Text("Sin datos de equipo"));
    }

    final sortedEntries = progData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final textTheme = Theme.of(context).textTheme;

    return ListView.builder(
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        final percent = provider.totalProcessed > 0 ? (entry.value / provider.totalProcessed) : 0.0;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textDark) ??
                          const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    NumberUtils.formatCogollos(entry.value.round()),
                    style: textTheme.bodySmall?.copyWith(color: AppColors.iconGrey) ??
                        const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: percent,
                backgroundColor: AppColors.searchBarFill,
                color: AppColors.statusHarvested,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _getQuarterMonthNames(int quarter) {
    switch (quarter) {
      case 1: return ['Ene', 'Feb', 'Mar'];
      case 2: return ['Abr', 'May', 'Jun'];
      case 3: return ['Jul', 'Ago', 'Sep'];
      case 4: return ['Oct', 'Nov', 'Dic'];
      default: return [];
    }
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final Color? subtitleColor;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
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
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                        color: AppColors.iconGrey,
                        fontWeight: FontWeight.bold,
                      ) ??
                      const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
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
                  color: AppColors.textDark,
                ) ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDark),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ) ??
                  TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: subtitleColor),
            ),
          ]
        ],
      ),
    );
  }
}
