import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Acesso centralizado às variáveis de ambiente. Nunca hardcode
/// credenciais no código (briefing, seção 59) — tudo vem do `.env`
/// (não versionado; ver `.env.example`).
class Env {
  Env._();

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String _require(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Variável de ambiente "$key" não encontrada. '
        'Copie .env.example para .env e preencha os valores.',
      );
    }
    return value;
  }
}
