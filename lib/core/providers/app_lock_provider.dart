import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _pinHashPrefsKey = 'app_lock_pin_hash';

String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

/// Bloqueio do app por PIN — gate local, por dispositivo (não é uma feature
/// de segurança da conta Supabase, é só pra alguém pegando o celular
/// destravado não abrir as finanças do casal direto).
class AppLockNotifier extends StateNotifier<AsyncValue<String?>> {
  AppLockNotifier() : super(const AsyncValue.loading()) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AsyncValue.data(prefs.getString(_pinHashPrefsKey));
  }

  bool get hasPin => state.valueOrNull != null;

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPin(pin);
    await prefs.setString(_pinHashPrefsKey, hash);
    state = AsyncValue.data(hash);
  }

  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashPrefsKey);
    state = const AsyncValue.data(null);
  }

  bool verify(String pin) {
    final hash = state.valueOrNull;
    return hash != null && hash == _hashPin(pin);
  }
}

final appLockProvider = StateNotifierProvider<AppLockNotifier, AsyncValue<String?>>((ref) {
  return AppLockNotifier();
});

/// Fica `true` assim que o PIN correto é digitado nesta sessão (em memória
/// — some ao recarregar a página, forçando o PIN de novo).
final appUnlockedProvider = StateProvider<bool>((ref) => false);
