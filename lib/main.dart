import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('pt_BR', null);
  await SupabaseConfig.initialize();

  runApp(const ProviderScope(child: FinancasCasalApp()));
}

class FinancasCasalApp extends StatelessWidget {
  const FinancasCasalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Finanças do Casal',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // TODO: substituir por AppRouter (go_router) assim que as telas de
      // auth/home estiverem prontas — ver lib/core/router.
      home: const _Bootstrap(),
    );
  }
}

/// Placeholder temporário até o roteamento (auth gate + shell de navegação)
/// ser implementado na próxima etapa.
class _Bootstrap extends StatelessWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Finanças do Casal — em construção'),
      ),
    );
  }
}
