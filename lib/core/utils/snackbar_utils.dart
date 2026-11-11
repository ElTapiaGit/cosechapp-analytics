import 'package:flutter/material.dart';

class SnackbarUtils {
  static const Color _primaryColor = Color(0xFF2E7D32);
  static const Color _errorColor = Color(0xFFD32F2F);

  static void showSuccess(BuildContext context, String message) {
    _showCustomSnackbar(
      context: context,
      message: message,
      backgroundColor: _primaryColor,
      icon: Icons.check_circle_outline,
    );
  }

  static void showError(BuildContext context, String message, {Duration duration = const Duration(seconds: 4)}) {
    // Limpiamos el prefijo "Exception: " si viene de un bloque try-catch
    final cleanMessage = message.replaceAll('Exception: ', '');
    
    _showCustomSnackbar(
      context: context,
      message: cleanMessage,
      backgroundColor: _errorColor,
      icon: Icons.error_outline,
      duration: duration,
    );
  }

  static void _showCustomSnackbar({
    required BuildContext context,
    required String message,
    required Color backgroundColor,
    required IconData icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Oculta el snackbar anterior si hubiera uno en pantalla
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating, // Lo hace flotante
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Bordes redondeados
        ),
        margin: const EdgeInsets.all(20), // Margen para que no toque los bordes
        elevation: 6,
        duration: duration,
      ),
    );
  }
}