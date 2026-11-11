import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorTranslator {
  static String translate(dynamic error) {
    if (error is PostgrestException) {
      final msg = error.message.toLowerCase();
      
      // Errores de restricciones de base de datos (Not Null)
      if (msg.contains("null value in column 'cut_date'")) {
        return "Falta la Fecha de Corte (F. CORTE) en uno o más registros. Revisa que las fechas sean válidas (ej. no sean muy antiguas) y no estén vacías.";
      }
      if (msg.contains("null value in column 'full_name'")) {
        return "El nombre del Productor no puede estar vacío en el Excel.";
      }
      
      // Errores de duplicados (Unique constraints)
      if (msg.contains("unique constraint") || msg.contains("duplicate key")) {
        if (msg.contains("producers_full_name_zone_id_key")) {
          return "Ya existe un productor con el mismo nombre en esa zona.";
        }
        return "Se intentó guardar un registro duplicado.";
      }

      // Error de llave foránea (Foreign key)
      if (msg.contains("foreign key constraint")) {
        return "Hay un problema de referencia con la Zona o el Productor. Verifica que los nombres de las zonas coincidan.";
      }
      
      // Mensaje por defecto para excepciones de Supabase
      return "Error en la base de datos: ${error.message}";
    }
    
    // Si es un Exception estándar (como las que lanzamos manualmente)
    if (error is Exception) {
      return error.toString().replaceAll("Exception: ", "");
    }
    
    // Para otros tipos de errores
    return "Ocurrió un error inesperado: $error";
  }
}
