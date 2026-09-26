enum TransactionType { income, expense, transfer }

extension TransactionTypeX on TransactionType {
  String get dbValue => switch (this) {
        TransactionType.income => 'income',
        TransactionType.expense => 'expense',
        TransactionType.transfer => 'transfer',
      };

  static TransactionType fromDb(String value) => switch (value) {
        'income' => TransactionType.income,
        'transfer' => TransactionType.transfer,
        _ => TransactionType.expense,
      };
}

enum PaymentMethod { pix, debit, credit, cash, boleto, transfer }

extension PaymentMethodX on PaymentMethod {
  String get dbValue => switch (this) {
        PaymentMethod.pix => 'pix',
        PaymentMethod.debit => 'debit',
        PaymentMethod.credit => 'credit',
        PaymentMethod.cash => 'cash',
        PaymentMethod.boleto => 'boleto',
        PaymentMethod.transfer => 'transfer',
      };

  String get label => switch (this) {
        PaymentMethod.pix => 'PIX',
        PaymentMethod.debit => 'Débito',
        PaymentMethod.credit => 'Crédito',
        PaymentMethod.cash => 'Dinheiro',
        PaymentMethod.boleto => 'Boleto',
        PaymentMethod.transfer => 'Transferência',
      };

  static PaymentMethod fromDb(String value) => switch (value) {
        'debit' => PaymentMethod.debit,
        'credit' => PaymentMethod.credit,
        'cash' => PaymentMethod.cash,
        'boleto' => PaymentMethod.boleto,
        'transfer' => PaymentMethod.transfer,
        _ => PaymentMethod.pix,
      };
}

enum TransactionStatus { paid, pending }

extension TransactionStatusX on TransactionStatus {
  String get dbValue => switch (this) {
        TransactionStatus.paid => 'paid',
        TransactionStatus.pending => 'pending',
      };

  static TransactionStatus fromDb(String value) => switch (value) {
        'pending' => TransactionStatus.pending,
        _ => TransactionStatus.paid,
      };
}

enum RecurrenceFrequency { weekly, monthly, annual }

extension RecurrenceFrequencyX on RecurrenceFrequency {
  String get dbValue => switch (this) {
        RecurrenceFrequency.weekly => 'weekly',
        RecurrenceFrequency.monthly => 'monthly',
        RecurrenceFrequency.annual => 'annual',
      };

  String get label => switch (this) {
        RecurrenceFrequency.weekly => 'Semanal',
        RecurrenceFrequency.monthly => 'Mensal',
        RecurrenceFrequency.annual => 'Anual',
      };

  static RecurrenceFrequency fromDb(String value) => switch (value) {
        'weekly' => RecurrenceFrequency.weekly,
        'annual' => RecurrenceFrequency.annual,
        _ => RecurrenceFrequency.monthly,
      };
}
