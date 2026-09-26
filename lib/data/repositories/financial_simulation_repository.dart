import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/financial_simulation.dart';

class FinancialSimulationRepository {
  FinancialSimulationRepository(this._client);

  final SupabaseClient _client;

  Future<void> save(FinancialSimulation simulation) async {
    await _client.from('financial_simulations').insert(simulation.toInsertJson());
  }
}
