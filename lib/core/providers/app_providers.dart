import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../models/household.dart';
import '../../models/profile.dart';
import '../config/supabase_config.dart';
import 'household_selection_provider.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseConfig.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository(ref.watch(supabaseClientProvider));
});

/// Emite a cada mudança de sessão (login, logout, token refresh).
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Todos os households do usuário logado (normalmente 1, mas pode ter mais
/// de um — ex.: "Casal" e "Empresa" — sempre isolados entre si). Refaz a
/// busca a cada mudança de sessão.
final householdsProvider = FutureProvider<List<Household>>((ref) async {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  if (authState?.session == null) return const [];
  return ref.watch(householdRepositoryProvider).fetchHouseholds();
});

/// Household ativo neste dispositivo — `null` durante o onboarding. Quando
/// o usuário pertence a mais de um, respeita o espaço escolhido em
/// [activeHouseholdIdProvider]; senão cai no único que existe.
final currentHouseholdProvider = FutureProvider<Household?>((ref) async {
  final households = await ref.watch(householdsProvider.future);
  if (households.isEmpty) return null;

  final activeId = ref.watch(activeHouseholdIdProvider);
  if (activeId != null) {
    for (final household in households) {
      if (household.id == activeId) return household;
    }
  }
  return households.first;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  if (authState?.session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchCurrent();
});
