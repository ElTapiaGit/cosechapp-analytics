// maneja la comunicacion con supabase
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? get currentUser => _supabase.auth.currentUser;

  /// Getter verificar si el usuario logueado es Admin (blindado con appMetadata del backend)
  bool get isAdmin => currentUser?.appMetadata['role'] == 'admin';

  // Iniciar Sesion
  Future<String?> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _setLoading(false);
      return null; // Null significa exito (sin errores)
    } on AuthException catch (e) {
      _setLoading(false);
      return e.message; // Devolvemos el mensaje de error
    } catch (e) {
      _setLoading(false);
      return 'Ocurrió un error inesperado';
    }
  }

  // Registrarse
  Future<String?> signUp(String email, String password) async {
    _setLoading(true);
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      _setLoading(false);
      return null;
    } on AuthException catch (e) {
      _setLoading(false);
      return e.message;
    } catch (e) {
      _setLoading(false);
      return 'Ocurrió un error inesperado';
    }
  }

  // Cerrar Sesion
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}