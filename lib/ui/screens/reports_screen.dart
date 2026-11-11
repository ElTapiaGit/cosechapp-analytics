import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../logic/providers/auth_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Verificación de estado de autenticación y rol de usuario (RBAC)
    final authProvider = context.watch<AuthProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        
        // HEADER ADAPTADO A DESKTOP / WEB
        appBar: AppBar(
          backgroundColor: AppColors.surfaceWhite,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            "Centro de Reportes",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1024),
                child: TabBar(
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.iconGrey,
                  indicatorColor: AppColors.primaryGreen,
                  labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
                  tabs: const [
                    Tab(text: "Mensual"),
                    Tab(text: "Trimestral"),
                  ],
                ),
              ),
            ),
          ),
        ),

        // LISTA DE REPORTES ADAPTADA A DESKTOP / WEB (maxWidth: 1024)
        body: TabBarView(
          children: [
            // --- PESTAÑA 1: MENSUAL ---
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1024),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          "REPORTES ESTÁNDAR",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.iconGrey,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                        ),
                      ),
            
                      // 1. RESUMEN DE PRODUCCIÓN (Con unidad oficial de cogollos)
                      _ReportCard(
                        title: "Resumen de Producción",
                        description: "Totales por mes, comparativas anuales y tendencias de cogollos procesados.",
                        icon: Icons.trending_up,
                        color: AppColors.primaryGreen,
                        onTap: () => context.push('/reports/production'),
                      ),
                      const SizedBox(height: 16),

                      // 2. CONTROL POR PROGRAMADOR
                      _ReportCard(
                        title: "Desempeño de Programadores",
                        description: "Cantidad de productores atendidos y eficiencia por cada programador.",
                        icon: Icons.people_alt,
                        color: AppColors.statusHarvested,
                        onTap: () => context.push('/reports/programmer'),
                      ),
                      const SizedBox(height: 16),

                      // 3. MATRIZ DE CONCILIACIÓN Y PROYECCIONES ESTADÍSTICAS
                      _ReportCard(
                        title: "Conciliación y Proyecciones",
                        description: "Cruza la expectativa estimada contra las cargas reales y audita pérdidas de suministro.",
                        icon: Icons.fact_check_outlined,
                        color: AppColors.statusUrgent,
                        onTap: () => context.push('/reports/reconciliation'),
                      ),
                      const SizedBox(height: 16),
            
                      // 4. SUBIR ARCHIVO EXCEL DEL MES (Protegido por rol Administrador - RBAC)
                      if (authProvider.isAdmin) ...[
                        _ReportCard(
                          title: "Subir archivo Excel del Mes",
                          description: "Carga de archivo Excel correspondiente a un mes de cosecha para procesamiento y registro en el sistema.",
                          icon: Icons.unarchive,
                          color: AppColors.primaryGreen,
                          onTap: () => context.push('/reports/import'),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 16),

                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          "HERRAMIENTAS AVANZADAS",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.iconGrey,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                        ),
                      ),

                      // 5. REPORTE PERSONALIZADO
                      _ReportCard(
                        title: "Generador Personalizado",
                        description: "Filtra por zonas, estados o fechas específicas y exporta el resultado.",
                        icon: Icons.filter_alt,
                        color: AppColors.statusVisited,
                        isAdvanced: true,
                        onTap: () => context.push('/reports/custom'),
                      ),
            
                      const SizedBox(height: 80), // Espacio para el BottomNav
                    ],
                  ),
                ),
              ),
            ),
            
            // --- PESTAÑA 2: TRIMESTRAL ---
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1024),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          "REPORTES TRIMESTRALES",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.iconGrey,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                        ),
                      ),
                      _ReportCard(
                        title: "Dashboard Trimestral",
                        description: "Métricas consolidadas, tendencias mensuales y distribución geográfica.",
                        icon: Icons.dashboard,
                        color: AppColors.statusVisited,
                        onTap: () => context.push('/reports/quarterly'),
                      ),
                      const SizedBox(height: 16),
                      _ReportCard(
                        title: "Recepción y Producción Trimestral",
                        description: "Auditoría comparativa de cosecha recepcionada en campo vs producción procesada en planta.",
                        icon: Icons.table_chart,
                        color: AppColors.statusHarvested,
                        onTap: () => context.push('/reports/quarterly-production'),
                      ),
                      const SizedBox(height: 80), // Espacio para el BottomNav
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET TARJETA DE REPORTE (UI REUTILIZABLE) ---
class _ReportCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isAdvanced;

  const _ReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isAdvanced = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        border: isAdvanced ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ICONO CIRCULAR
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                
                // TEXTOS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                            ),
                          ),
                          if (isAdvanced)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "PRO",
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.surfaceWhite,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 13,
                              color: AppColors.iconGrey,
                              height: 1.4,
                            ),
                      ),
                      const SizedBox(height: 12),
                      
                      // CALL TO ACTION PEQUEÑO
                      Row(
                        children: [
                          Text(
                            "Ver reporte",
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: color),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
