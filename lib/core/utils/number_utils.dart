import 'package:intl/intl.dart';

/// Helper centralizado para formateo de cantidades numéricas con comas como separador de miles.
class NumberUtils {
  NumberUtils._();

  static final _numberFormatter = NumberFormat("#,##0", "en_US");

  /// Formatea un número con coma como separador de miles (ej: 4,359,824).
  static String formatNumber(num value) => _numberFormatter.format(value);

  /// Formatea una cantidad acompañada de la unidad oficial 'cogollos' (ej: 4,359,824 cogollos).
  static String formatCogollos(num value) => "${_numberFormatter.format(value)} cogollos";
}

