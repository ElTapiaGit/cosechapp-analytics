import 'package:flutter/material.dart';

/// Centralización de la paleta cromática institucional de CosechApp.
/// Basado en la auditoría técnica y especificaciones de Material Design 3.
class AppColors {
  AppColors._();

  // Color primario institucional
  static const Color primaryGreen = Color(0xFF2F7F34);
  static final Color primaryGreenLight = const Color(0xFF2F7F34).withValues(alpha: 0.1);

  // Fondos y superficies neutras
  static const Color scaffoldBackground = Color(0xFFF6F8F6);
  static const Color searchBarFill = Color(0xFFF0F2F0);
  static const Color surfaceWhite = Colors.white;

  // Tipografía y textos
  static const Color textDark = Color(0xFF111811);

  // Grises, bordes y sombras
  static const Color iconGrey = Colors.grey;
  static final Color borderGrey = Colors.grey.shade300;
  static final Color shadowLight = Colors.black.withValues(alpha: 0.05);

  // Colores de estados operativos de cosecha
  // 1. Cancelado
  static const Color statusCancelled = Color(0xFFD32F2F);
  static final Color statusCancelledBg = const Color(0xFFD32F2F).withValues(alpha: 0.1);

  // 2. Atrasado crítico
  static const Color statusOverdue = Color(0xFFB71C1C);

  // 3. Por visitar / Urgente
  static const Color statusUrgent = Color(0xFFFF9800);

  // 4. Cosechado
  static const Color statusHarvested = Colors.blue;

  // 5. Visitado
  static const Color statusVisited = Colors.purple;
}

