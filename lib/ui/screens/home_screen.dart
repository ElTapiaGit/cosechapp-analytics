import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../logic/providers/harvest_provider.dart';
import '../../data/models/harvest_model.dart';
import '../../logic/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchamos al provider de cosechas
    final harvestProvider = context.watch<HarvestProvider>();
    final isLoading = harvestProvider.isLoading;
    // Obtenemos la lista filtrada directamente del provider
    final List<HarvestModel> harvests = harvestProvider.harvests;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      
      // 1. APP BAR PERSONALIZADO
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent, // Evita tinte al scrollear
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Próximas Cosechas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryGreen),
            onPressed: () => context.read<HarvestProvider>().loadHarvests(),
          ),
          // Boton salir pequeño
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: AppColors.iconGrey),
            onPressed: () {
              context.read<AuthProvider>().signOut();
              context.go('/login');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1024),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        context.read<HarvestProvider>().searchProducers(value);
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar productor o DCTO...',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.iconGrey),
                    prefixIcon: const Icon(Icons.search, color: AppColors.iconGrey),
                    filled: true,
                    fillColor: AppColors.searchBarFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      // 2. CUERPO DE LA LISTA ADAPTADO A DESKTOP/WEB (maxWidth: 1024)
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1024),
          child: Column(
            children: [
              // BARRA DE FILTROS (Horizontal Scroll)
              if (!isLoading)
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    children: [
                      // FILTRO: MES DE CORTE
                      _FilterBadge(
                        label: harvestProvider.selectedMonth ?? 'Mes Corte',
                        isActive: harvestProvider.selectedMonth != null,
                        items: harvestProvider.availableMonths,
                        onSelected: (val) {
                          context.read<HarvestProvider>().setFilter(month: val);
                        },
                      ),
                      const SizedBox(width: 8),

                      // FILTRO: ZONA
                      _FilterBadge(
                        label: harvestProvider.selectedZone ?? 'Zona',
                        isActive: harvestProvider.selectedZone != null,
                        items: harvestProvider.availableZones,
                        onSelected: (val) => context.read<HarvestProvider>().setFilter(zone: val),
                      ),
                      const SizedBox(width: 8),

                      // FILTRO: PROGRAMADOR
                      _FilterBadge(
                        label: harvestProvider.selectedProgrammer ?? 'Programador',
                        isActive: harvestProvider.selectedProgrammer != null,
                        items: harvestProvider.availableProgrammers,
                        onSelected: (val) => context.read<HarvestProvider>().setFilter(programmer: val),
                      ),
                      
                      // Botón limpiar filtros
                      if (harvestProvider.selectedZone != null || harvestProvider.selectedProgrammer != null || harvestProvider.selectedMonth != null)
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.iconGrey),
                          onPressed: () {
                            _searchController.clear();
                            context.read<HarvestProvider>().setFilter(month: null, zone: null, programmer: null);
                            context.read<HarvestProvider>().searchProducers(""); 
                          },
                        ),
                    ],
                  ),
                ),

              // LISTA DE TARJETAS
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : harvests.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: harvests.length,
                            itemBuilder: (context, index) {
                              return _HarvestCard(harvest: harvests[index]);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      
      // BOTON FLOTANTE (Para agregar o exportar) - Mantener intacto con acción vacía
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aquí pondremos la lógica de agregar manual o exportar Excel
        },
        backgroundColor: AppColors.primaryGreen,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: AppColors.surfaceWhite, size: 30),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.filter_list_off, size: 64, color: AppColors.iconGrey),
          const SizedBox(height: 16),
          Text(
            "No se encontraron cosechas con esos filtros",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.iconGrey),
          ),
        ],
      ),
    );
  }
}

// Widget para los Chips de Filtro (Estilo Dropdown)
class _FilterBadge extends StatelessWidget {
  final String label;
  final bool isActive;
  final List<String> items;
  final Function(String?) onSelected;

  const _FilterBadge({
    required this.label,
    required this.isActive,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      constraints: const BoxConstraints(maxHeight: 400),
      color: AppColors.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      itemBuilder: (BuildContext context) {
        return [
          PopupMenuItem<String?>(
            value: null, 
            child: Text(
              'Ver Todos',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          ...items.map((String item) {
            return PopupMenuItem<String?>(
              value: item,
              child: Text(
                item,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textDark,
                ),
              ),
            );
          }),
        ];
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? Colors.transparent : AppColors.borderGrey),
          boxShadow: [
            if (!isActive) BoxShadow(color: AppColors.shadowLight, blurRadius: 2, offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive ? AppColors.surfaceWhite : AppColors.textDark,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 18,
              color: isActive ? AppColors.surfaceWhite : AppColors.iconGrey,
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET PERSONALIZADO DE LA TARJETA 
class _HarvestCard extends StatelessWidget {
  final HarvestModel harvest;

  const _HarvestCard({required this.harvest});

  @override
  Widget build(BuildContext context) {
    // Definir colores segun estado con constantes semánticas de AppColors
    Color statusColor;
    Color statusBgColor;
    String statusText;
    final daysLeft = harvest.nextEstimatedDate.difference(DateTime.now()).inDays;
    
    // Estados Finales (Prioridad Alta)
    if (harvest.status == 'CANCELLED') {
      statusColor = AppColors.statusCancelled;
      statusBgColor = AppColors.statusCancelledBg;
      statusText = "CANCELADO";
    } else if (harvest.status == 'HARVESTED') {
      statusColor = AppColors.statusHarvested;
      statusBgColor = AppColors.statusHarvestedBg;
      statusText = "COSECHADO";
    } else if (harvest.status == 'VISITED') {
      statusColor = AppColors.statusVisited;
      statusBgColor = AppColors.statusVisitedBg;
      statusText = "VISITADO";
    } else {
      if (daysLeft < 0) {
        statusColor = AppColors.statusOverdue;
        statusBgColor = AppColors.statusOverdueBg;
        statusText = "ATRASADO (${daysLeft.abs()} días)";
      } else if (harvest.isUrgent) {
        statusColor = AppColors.statusUrgent;
        statusBgColor = AppColors.statusUrgentBg;
        statusText = "POR VISITAR";
      } else {
        statusColor = AppColors.statusPending;
        statusBgColor = AppColors.statusPendingBg;
        statusText = "PENDIENTE";
      }
    }

    final dateFormattedDay = DateFormat('dd').format(harvest.nextEstimatedDate);
    final dateFormattedMonth = DateFormat('MMM', 'es_BO').format(harvest.nextEstimatedDate).toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.shadowLight, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.push('/detail', extra: harvest);
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                // BARRA LATERAL DE COLOR de ESTADO
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                
                // CONTENIDO
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera: Chip de Estado y Fecha
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusBgColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                statusText,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            // Caja de Fecha
                            Column(
                              children: [
                                Text(
                                  dateFormattedMonth,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.iconGrey,
                                  ),
                                ),
                                Text(
                                  dateFormattedDay,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Nombre Productor
                        Text(
                          harvest.producerName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Datos Secundarios 
                        Wrap(
                          spacing: 12,       // espacio horizontal entre datos
                          runSpacing: 4,     // espacio si baja abajo
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _InfoPill(icon: Icons.location_on, text: harvest.zoneName),
                            _InfoPill(icon: Icons.receipt_long, text: harvest.dctoCode),
                            _InfoPill(icon: Icons.person, text: harvest.programmer),
                          ],
                        ),
                      ],
                    ),
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Ocupa solo lo necesario
      children: [
        Icon(icon, size: 14, color: AppColors.iconGrey),
        const SizedBox(width: 4),
        // Flexible ayuda a que si el texto es muy largo, no rompa la tarjeta
        Flexible( 
          child: Text(
            text, 
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.iconGrey,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis, // Pone "..." si no entra
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
