import 'package:supabase_flutter/supabase_flutter.dart';

/// Encapsula toda a interação com `supabase.auth`. Nenhuma tela deve
/// chamar [Supabase.instance.client.auth] diretamente.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  bool get isAuthenticated => currentUser != null;

  /// Link usado nos e-mails de confirmação/redefinição de senha. Sem isso,
  /// o Supabase usa o "Site URL" padrão do projeto (localhost por padrão),
  /// quebrando o link pra quem abre o e-mail em outro dispositivo.
  /// [Uri.base] é a URL atual da página no Flutter web — funciona mesmo se
  /// o app for publicado em outro domínio no futuro.
  String get _emailRedirectTo => Uri.base.origin;

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: _emailRedirectTo,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPasswordForEmail(String email) => _client.auth.resetPasswordForEmail(
        email,
        redirectTo: _emailRedirectTo,
      );
}
