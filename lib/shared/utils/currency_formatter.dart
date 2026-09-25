import 'package:intl/intl.dart';

/// Formatação de moeda e data no padrão brasileiro (briefing, seção 7).
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _brl = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 2,
  );

  static final NumberFormat _brlCompact = NumberFormat.compactCurrency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 1,
  );

  /// Ex.: R$ 1.250,90
  static String format(num value) => _brl.format(value);

  /// Ex.: R$ 1,2 mil — para espaços com pouco espaço horizontal.
  static String formatCompact(num value) => _brlCompact.format(value);

  static final DateFormat _dateShort = DateFormat('dd/MM/yyyy', 'pt_BR');

  /// Ex.: 24/09/2026
  static String formatDate(DateTime date) => _dateShort.format(date);
}
