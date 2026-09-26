import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/household_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../models/household.dart';
import '../../models/profile.dart';
import '../config/supabase_config.dart';

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

/// Household do usuário logado, ou `null` durante o onboarding.
/// Refaz a busca a cada mudança de sessão.
final currentHouseholdProvider = FutureProvider<Household?>((ref) async {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  if (authState?.session == null) return null;
  return ref.watch(householdRepositoryProvider).fetchCurrentHousehold();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  if (authState?.session == null) return null;
  return ref.watch(profileRepositoryProvider).fetchCurrent();
});
