import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/models/harvest_model.dart';
import '../../logic/providers/harvest_provider.dart';

class HarvestDetailScreen extends StatefulWidget {
  final HarvestModel harvest;

  const HarvestDetailScreen({super.key, required this.harvest});

  @override
  State<HarvestDetailScreen> createState() => _HarvestDetailScreenState();
}

class _HarvestDetailScreenState extends State<HarvestDetailScreen> {
  // Estado local para simular el cambio de ciclo (3 o 4 meses)
  late int _selectedCycle;
  late DateTime _calculatedDate; 
  bool _isUpdating = false; 

  @override
  void initState() {
    super.initState();
    _selectedCycle = widget.harvest.cycleMonths;
    _recalculateEstimate(_selectedCycle);
  }

  // Recalcular si el ingeniero cambia el ciclo manual (solo vista)
  void _recalculateEstimate(int months) {
    final cutDate = widget.harvest.nextEstimatedDate;
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

  // Calcular dias restantes (Basado en la fecha de BD)
  int get _daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Usamos la fecha REAL (nextEstimatedDate) para la alerta
    final target = DateTime(widget.harvest.nextEstimatedDate.year, widget.harvest.nextEstimatedDate.month, widget.harvest.nextEstimatedDate.day);
    return target.difference(today).inDays;
  }

  // Funcion para traducir estados (Ingles -> Español)
  String _translateStatus(String status) {
    switch (status) {
      case 'PENDING': return 'Pendiente';
      case 'HARVESTED': return 'Cosechado';
      case 'TO_VISIT': return 'Por Visitar';
      case 'VISITED': return 'Visitado';
      case 'CANCELLED': return 'Cancelado';
      default: return status;
    }
  }

  Future<void> _handleAction(String newStatus, {String? obs}) async {
    setState(() => _isUpdating = true);
    
    final success = await context.read<HarvestProvider>().updateStatus(
      widget.harvest.id, 
      newStatus, 
      observation: obs
    );

    if (!mounted) return;
    setState(() => _isUpdating = false);

    if (success) {
      final estadoEsp = _translateStatus(newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Estado actualizado a: $estadoEsp"),
          backgroundColor: const Color(0xFF2F7F34),
        ),
      );
      context.pop(); // Volver al Home
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error actualizando. Revisa tu conexión.")),
      );
    }
  }

  // Dialogo para cancelar con motivo
  void _showCancelDialog() {
    final txtCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancelar Ciclo"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Por favor indica el motivo de cancelación:"),
            const SizedBox(height: 10),
            TextField(
              controller: txtCtrl,
              decoration: const InputDecoration(
                hintText: "Ej: Plaga, Venta a terceros...",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Volver")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (txtCtrl.text.isNotEmpty) {
                _handleAction('CANCELLED', obs: txtCtrl.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Confirmar Cancelación"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.harvest;
    final primaryColor = const Color(0xFF2F7F34);
    // Logica del Banner de Tiempo
    bool showBanner = false;
    Color timeColor = Colors.grey;
    String timeText = "";

    if (h.status != 'HARVESTED' && h.status != 'CANCELLED') {
      if (_daysRemaining < 0) {
        // Atrasado (siempre mostrar)
        showBanner = true;
        timeColor = const Color(0xFFD32F2F);
        timeText = "Atrasado por ${(_daysRemaining * -1)} días";
      } else if (_daysRemaining == 0) {
        showBanner = true;
        timeColor = const Color(0xFFD32F2F);
        timeText = "¡ES HOY!";
      } else if (_daysRemaining <= 7) {
        // Faltan 7 dias o menos (mostrar alerta naranja)
        showBanner = true;
        timeColor = const Color(0xFFFF9800); 
        timeText = "Faltan $_daysRemaining días";
      }
    } else {
      timeColor = primaryColor;
      timeText = "Ciclo Finalizado";
    }

    // Si ya se termino, no mostrar alerta
    if (h.status == 'HARVESTED' || h.status == 'CANCELLED') {
      timeColor = primaryColor;
      timeText = "Ciclo Finalizado";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      
      // HEADER (App Bar Transparente)
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F6), // color del fondo
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text("Detalle de Cosecha", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          // MENU DE 3 PUNTOS
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.black87),
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opción seleccionada: $value")));
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(children: [Icon(Icons.history, color: Colors.grey), SizedBox(width: 8), Text('Ver Historial')]),
              ),
              const PopupMenuItem<String>(
                value: 'stats',
                child: Row(children: [Icon(Icons.bar_chart, color: Colors.grey), SizedBox(width: 8), Text('Ver Estadísticas')]),
              ),
            ],
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), // Espacio abajo para el boton fijo
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECCION DE PERFIL 
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
                  Text(h.producerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min, // Centrar contenido
                    children: [
                      Icon(Icons.location_on, size: 16, color: primaryColor), // Icono agregado
                      const SizedBox(width: 4),
                      Text(h.zoneName, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Chip de Estado actual
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300)
                    ),
                    child: Text(
                      _translateStatus(h.status).toUpperCase(),
                      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BANNER DE TIEMPO 
            if (showBanner) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: timeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: timeColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer, color: timeColor),
                    const SizedBox(width: 8),
                    Text(timeText, style: TextStyle(color: timeColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // GRILLA DE DATOS (Fecha Ultimo Corte, Fecha Programada y Programador)
            Row(
              children: [
                Expanded(child: _StatCard(
                  label: "ULT. CORTE",
                  value: DateFormat("dd MMM yyyy", "es_BO").format(h.cutDate),
                  icon: Icons.history,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  label: "FECHA PROGRAMADA",
                  value: DateFormat("dd MMM yyyy", "es_BO").format(h.nextEstimatedDate),
                  icon: Icons.event_available,
                  isHighlight: true, // Destacamos esta fecha
                )),
              ],
            ),
            const SizedBox(height: 12),
            // Fila del Programador
             Row(
              children: [
                Expanded(child: _StatCard(
                  label: "PROGRAMADOR",
                  value: h.programmer, // Dato corregido
                  icon: Icons.engineering,
                )),
              ],
            ),

            const SizedBox(height: 16),

            // MAPA (Placeholder)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
                image: const DecorationImage(
                  image: NetworkImage("https://upload.wikimedia.org/wikipedia/commons/e/ec/USA_location_map.svg"), // Placeholder genérico
                  fit: BoxFit.cover,
                  opacity: 0.3
                ),
              ),
              child: Stack(
                children: [
                   const Center(child: Icon(Icons.map, size: 40, color: Colors.grey)),
                   Positioned(
                     bottom: 8,
                     left: 8,
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.white.withValues(alpha: 0.9),
                         borderRadius: BorderRadius.circular(12)
                       ),
                       child: const Text("UBICACIÓN NO REGISTRADA", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                     ),
                   )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // CALCULO DE CICLO (Interactivo)
            // Solo visible si está pendiente o visitado (no terminado)
            if (h.status != 'HARVESTED' && h.status != 'CANCELLED') ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Cálculo Próximo Ciclo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Icon(Icons.info_outline, color: primaryColor),
                ],
              ),
              const SizedBox(height: 12),

              // Toggle Buttons 
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
              
              // Resultado de la Simulacion
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.update, color: primaryColor, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("NUEVA ESTIMACIÓN (SIMULADA)", style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text(
                          DateFormat("dd MMMM yyyy", "es_BO").format(_calculatedDate).toUpperCase(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // OBSERVACIONES 
            if (h.observation != null) 
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Observación Registrada:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                    Text(h.observation!),
                  ],
                ),
              ),
          ],
        ),
      ),

      // BOTONES DE ACCION (Fijos abajo)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade100)),
        ),
        child: SafeArea(
          child: _buildActionButtons(h, context),
        ),
      ),
    );
  }

  // --- LOGICA DE BOTONES SEGUN ESTADO ---
  Widget _buildActionButtons(HarvestModel h, BuildContext context) {
    if (_isUpdating) {
      return const Center(heightFactor: 1, child: CircularProgressIndicator());
    }

    // CASO 1: PENDIENTE -> Ingeniero debe ir a visitar
    if (h.status == 'PENDING') {
      return SizedBox(
        height: 55,
        child: ElevatedButton.icon(
          onPressed: () => _handleAction('VISITED'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F7F34), 
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text("YA VISITÉ EL CAMPO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      );
    }

    // CASO 2: VISITADO o POR VISITAR -> Ingeniero decide: Cosecha o Cancela
    if (h.status == 'VISITED' || h.status == 'TO_VISIT') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: () => _handleAction('HARVESTED'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.agriculture),
              label: const Text("CONFIRMAR COSECHA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _showCancelDialog, // Abre popup
            icon: const Icon(Icons.block, color: Colors.red),
            label: const Text("Cancelar Ciclo", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )
        ],
      );
    }

    // CASO 3: FINALIZADO -> Solo lectura
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.lock, color: Colors.grey),
          SizedBox(width: 8),
          Text("Cosecha Finalizada / Cerrada", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- Widgets Internos ---

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlight;

  const _StatCard({required this.label, required this.value, required this.icon, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFE8F5E9) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isHighlight ? const Color(0xFF2F7F34) : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF2F7F34)),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isHighlight ? const Color(0xFF2F7F34) : Colors.black)),
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
            color: isSelected ? const Color(0xFF2F7F34) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? const Color(0xFF2F7F34) : Colors.grey.shade300),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}