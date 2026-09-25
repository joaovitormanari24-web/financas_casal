import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';

/// Inicialização única do cliente Supabase. Somente a chave `anon`/
/// `publishable` é usada no app — nunca a `service_role` (briefing,
/// seção 59). Toda a segurança de acesso a dados fica a cargo do RLS
/// no banco.
class SupabaseConfig {
  SupabaseConfig._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
