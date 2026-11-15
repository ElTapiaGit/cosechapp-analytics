import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/harvest_model.dart';

class HarvestDetailScreen extends StatefulWidget {
  final HarvestModel harvest;

  const HarvestDetailScreen({super.key, required this.harvest});

  @override
  State<HarvestDetailScreen> createState() => _HarvestDetailScreenState();
}

class _HarvestDetailScreenState extends State<HarvestDetailScreen> {
  late int _selectedCycle;
  late DateTime _calculatedDate;

  @override
  void initState() {
    super.initState();
    _selectedCycle = widget.harvest.cycleMonths;
    _recalculateEstimate(_selectedCycle);
  }

  // Recalcula la simulación a partir de la fecha real de corte (cutDate)
  void _recalculateEstimate(int months) {
    final cutDate = widget.harvest.cutDate;
    var newDate = DateTime(cutDate.year, cutDate.month + months, cutDate.day);
    
    // Ajuste Domingo -> Lunes
    if (newDate.weekday == DateTime.sunday) {
      newDate = newDate.add(const Duration(days: 1));
    }
    setState(() {
      _selectedCycle = months;
      _calculatedDate = newDate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.harvest;
    final primaryColor = AppColors.primaryGreen;

    // Lógica dinámica del Banner de Alerta Temporal
    final daysRemaining = h.daysRemaining;
    final bool isReady = h.isReadyForHarvest;

    final Color timeColor = isReady ? AppColors.statusCancelled : AppColors.primaryGreen;
    String timeText;
    if (daysRemaining < 0) {
      timeText = "Atrasado por ${daysRemaining.abs()} días";
    } else if (daysRemaining == 0) {
      timeText = "¡ES HOY EL DÍA ESTIMADO!";
    } else {
      timeText = "Faltan $daysRemaining días para la cosecha";
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          "Detalle de Cosecha",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECCIÓN DE PERFIL DEL PRODUCTOR
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: primaryColor.withValues(alpha: 0.2),
                    child: Text(
                      h.producerName.isNotEmpty ? h.producerName.substring(0, 1) : "P",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    h.producerName,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, size: 16, color: primaryColor),
                      const SizedBox(width: 4),
                      Text(h.zoneName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // CHIP DE ESTADO DINÁMICO
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: h.statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: h.statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      h.computedStatus,
                      style: TextStyle(color: h.statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BANNER DINÁMICO DE TIEMPO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: timeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: timeColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isReady ? Icons.warning_amber_rounded : Icons.schedule_rounded, color: timeColor),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      timeText,
                      style: TextStyle(color: timeColor, fontWeight: FontWeight.bold, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // GRILLA DE DATOS TÉCNICOS
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: "ÚLTIMO CORTE",
                    value: DateFormat("dd MMM yyyy", "es_BO").format(h.cutDate),
                    icon: Icons.history,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: "FECHA PROGRAMADA",
                    value: DateFormat("dd MMM yyyy", "es_BO").format(h.nextEstimatedDate),
                    icon: Icons.event_available,
                    isHighlight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: "PROGRAMADOR RESPONSABLE",
                    value: h.programmer,
                    icon: Icons.engineering,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: "DOCUMENTO DCTO",
                    value: h.dctoCode.isNotEmpty ? h.dctoCode : "S/D",
                    icon: Icons.receipt_long,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // SIMULADOR DE PRÓXIMO CICLO AGRONÓMICO
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Simulador de Ciclo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Icon(Icons.tune_rounded, color: primaryColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _CycleButton(
                  text: "3 Meses", 
                  isSelected: _selectedCycle == 3,
                  onTap: () => _recalculateEstimate(3),
                ),
                const SizedBox(width: 8),
                _CycleButton(
                  text: "4 Meses", 
                  isSelected: _selectedCycle == 4,
                  onTap: () => _recalculateEstimate(4),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_outlined, color: primaryColor, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ESTIMACIÓN SIMULADA ($_selectedCycle MESES)",
                        style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat("dd MMMM yyyy", "es_BO").format(_calculatedDate).toUpperCase(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // OBSERVACIONES REGISTRADAS
            if (h.observation != null && h.observation!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Observación Registrada:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                    const SizedBox(height: 4),
                    Text(h.observation!, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

// Widgets de Soporte Visual
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlight;

  const _StatCard({required this.label, required this.value, required this.icon, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.primaryGreen.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isHighlight ? AppColors.primaryGreen.withValues(alpha: 0.3) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppColors.primaryGreen : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CycleButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _CycleButton({required this.text, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
