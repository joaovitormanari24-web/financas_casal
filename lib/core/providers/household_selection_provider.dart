import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _activeHouseholdPrefsKey = 'active_household_id';

/// Qual household está ativo neste dispositivo, para quem pertence a mais
/// de um (ex.: "Casal" e "Empresa") — persistido localmente, por dispositivo,
/// já que cada membro pode estar navegando num espaço diferente ao mesmo
/// tempo.
class ActiveHouseholdIdNotifier extends StateNotifier<String?> {
  ActiveHouseholdIdNotifier() : super(null) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_activeHouseholdPrefsKey);
  }

  Future<void> setActive(String householdId) async {
    state = householdId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeHouseholdPrefsKey, householdId);
  }
}

final activeHouseholdIdProvider =
    StateNotifierProvider<ActiveHouseholdIdNotifier, String?>((ref) {
  return ActiveHouseholdIdNotifier();
});
