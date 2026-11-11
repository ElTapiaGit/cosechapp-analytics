import 'package:flutter/material.dart';
import '../screens/home_screen.dart'; // Tu lista de tarjetas
import '../screens/reports_screen.dart';
import '../screens/stats_screen.dart'; // La nueva pantalla

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;
  
  // Lista de pantallas
  final List<Widget> _screens = [
    const HomeScreen(),  // Index 0: Dashboard (Cosechas)
    const StatsScreen(), // Index 1: Estadísticas (Reemplaza a Mapa)
    const ReportsScreen(), // Index 2
    const Center(child: Text("Perfil (Próximamente)")),   // Index 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF2F7F34).withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF2F7F34)),
            label: 'Cosechas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined), // CAMBIO AQUI: Icono de Barras
            selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF2F7F34)),
            label: 'Estadísticas', // CAMBIO AQUI: Nombre
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            label: 'Reportes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}