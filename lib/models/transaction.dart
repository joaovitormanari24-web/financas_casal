import 'package:equatable/equatable.dart';
import 'enums.dart';

/// Lançamento financeiro — o núcleo do app (briefing, seção 28).
class Transaction extends Equatable {
  const Transaction({
    required this.id,
    required this.householdId,
    required this.type,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.date,
    required this.paidByMemberId,
    required this.paymentMethod,
    this.accountId,
    this.creditCardId,
    this.note,
    this.recurringTransactionId,
    this.installmentPlanId,
    this.installmentNumber,
    this.installmentTotal,
  });

  final String id;
  final String householdId;
  final TransactionType type;
  final double amount;
  final String description;
  final String categoryId;
  final DateTime date;

  /// Quem realizou o gasto/recebeu a receita (briefing, seção 9).
  final String paidByMemberId;
  final PaymentMethod paymentMethod;
  final String? accountId;
  final String? creditCardId;
  final String? note;

  /// Preenchido quando o lançamento nasceu de uma recorrência.
  final String? recurringTransactionId;

  /// Preenchidos quando o lançamento é uma parcela (briefing, seção 33).
  final String? installmentPlanId;
  final int? installmentNumber;
  final int? installmentTotal;

  bool get isInstallment => installmentPlanId != null;
  bool get isRecurring => recurringTransactionId != null;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        type: TransactionTypeX.fromDb(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        categoryId: json['category_id'] as String,
        date: DateTime.parse(json['date'] as String),
        paidByMemberId: json['paid_by_member_id'] as String,
        paymentMethod: PaymentMethodX.fromDb(json['payment_method'] as String),
        accountId: json['account_id'] as String?,
        creditCardId: json['credit_card_id'] as String?,
        note: json['note'] as String?,
        recurringTransactionId: json['recurring_transaction_id'] as String?,
        installmentPlanId: json['installment_plan_id'] as String?,
        installmentNumber: json['installment_number'] as int?,
        installmentTotal: json['installment_total'] as int?,
      );

  Map<String, dynamic> toInsertJson() => {
        'household_id': householdId,
        'type': type.dbValue,
        'amount': amount,
        'description': description,
        'category_id': categoryId,
        'date': date.toIso8601String(),
        'paid_by_member_id': paidByMemberId,
        'payment_method': paymentMethod.dbValue,
        'account_id': accountId,
        'credit_card_id': creditCardId,
        'note': note,
        'recurring_transaction_id': recurringTransactionId,
        'installment_plan_id': installmentPlanId,
        'installment_number': installmentNumber,
        'installment_total': installmentTotal,
      };

  @override
  List<Object?> get props => [
        id,
        householdId,
        type,
        amount,
        description,
        categoryId,
        date,
        paidByMemberId,
        paymentMethod,
      ];
}

/// Grupo de parcelas de uma compra parcelada (briefing, seção 33).
/// As parcelas futuras entram automaticamente na previsão do mês.
class InstallmentPlan extends Equatable {
  const InstallmentPlan({
    required this.id,
    required this.householdId,
    required this.description,
    required this.totalAmount,
    required this.installmentCount,
    required this.installmentAmount,
    required this.firstDueDate,
    required this.creditCardId,
  });

  final String id;
  final String householdId;
  final String description;
  final double totalAmount;
  final int installmentCount;
  final double installmentAmount;
  final DateTime firstDueDate;
  final String creditCardId;

  factory InstallmentPlan.fromJson(Map<String, dynamic> json) =>
      InstallmentPlan(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        description: json['description'] as String,
        totalAmount: (json['total_amount'] as num).toDouble(),
        installmentCount: json['installment_count'] as int,
        installmentAmount: (json['installment_amount'] as num).toDouble(),
        firstDueDate: DateTime.parse(json['first_due_date'] as String),
        creditCardId: json['credit_card_id'] as String,
      );

  @override
  List<Object?> get props => [id, householdId, description, totalAmount];
}

/// Gasto recorrente (briefing, seção 34): aluguel, assinaturas, etc.
class RecurringTransaction extends Equatable {
  const RecurringTransaction({
    required this.id,
    required this.householdId,
    required this.description,
    required this.amount,
    required this.categoryId,
    required this.frequency,
    required this.dayOfCycle,
    required this.active,
    required this.paymentMethod,
    this.paidByMemberId,
  });

  final String id;
  final String householdId;
  final String description;
  final double amount;
  final String categoryId;
  final RecurrenceFrequency frequency;

  /// Dia do mês (1-31) ou dia da semana ISO (1=segunda...7=domingo),
  /// conforme [frequency].
  final int dayOfCycle;
  final bool active;
  final PaymentMethod paymentMethod;

  /// Membro responsável pelo lançamento gerado. Se nulo, o gerador usa o
  /// membro mais antigo do household (ver função no banco).
  final String? paidByMemberId;

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      RecurringTransaction(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        categoryId: json['category_id'] as String,
        frequency: RecurrenceFrequencyX.fromDb(json['frequency'] as String),
        dayOfCycle: json['day_of_cycle'] as int,
        active: json['active'] as bool? ?? true,
        paymentMethod: PaymentMethodX.fromDb(json['payment_method'] as String),
        paidByMemberId: json['paid_by_member_id'] as String?,
      );

  Map<String, dynamic> toInsertJson() => {
        'household_id': householdId,
        'description': description,
        'amount': amount,
        'category_id': categoryId,
        'frequency': frequency.dbValue,
        'day_of_cycle': dayOfCycle,
        'active': active,
        'payment_method': paymentMethod.dbValue,
        'paid_by_member_id': paidByMemberId,
      };

  @override
  List<Object?> get props => [id, householdId, description, amount, active];
}
