import 'package:flutter/material.dart';

import '../../models/enums.dart';

IconData paymentMethodIconData(PaymentMethod method) => switch (method) {
      PaymentMethod.pix => Icons.bolt_rounded,
      PaymentMethod.debit => Icons.credit_card_rounded,
      PaymentMethod.credit => Icons.credit_score_rounded,
      PaymentMethod.cash => Icons.payments_rounded,
      PaymentMethod.boleto => Icons.receipt_long_rounded,
      PaymentMethod.transfer => Icons.swap_horiz_rounded,
    };
