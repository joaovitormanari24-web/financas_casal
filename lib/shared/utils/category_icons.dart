import 'package:flutter/material.dart';

/// Mapeia o nome de ícone salvo em `categories.icon` (banco) para o
/// [IconData] correspondente. Mantém a UI independente do valor salvo.
IconData categoryIconData(String icon) => switch (icon) {
      'home' => Icons.home_rounded,
      'restaurant' => Icons.restaurant_rounded,
      'directions_car' => Icons.directions_car_rounded,
      'local_hospital' => Icons.local_hospital_rounded,
      'sports_esports' => Icons.sports_esports_rounded,
      'shopping_bag' => Icons.shopping_bag_rounded,
      'school' => Icons.school_rounded,
      'subscriptions' => Icons.subscriptions_rounded,
      'receipt_long' => Icons.receipt_long_rounded,
      'pets' => Icons.pets_rounded,
      'flight' => Icons.flight_rounded,
      'payments' => Icons.payments_rounded,
      'trending_up' => Icons.trending_up_rounded,
      'target' => Icons.track_changes_rounded,
      _ => Icons.more_horiz_rounded,
    };

/// Converte `#RRGGBB` (formato salvo em `categories.color_hex`) em [Color].
Color colorFromHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  return Color(int.parse('FF$normalized', radix: 16));
}
