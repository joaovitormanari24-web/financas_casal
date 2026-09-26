import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/utils/category_icons.dart';

/// Ícones e cores disponíveis pra uma categoria personalizada — mesmo
/// conjunto que [categoryIconData]/[colorFromHex] já sabem desenhar.
const _iconChoices = [
  'home',
  'restaurant',
  'directions_car',
  'local_hospital',
  'sports_esports',
  'shopping_bag',
  'school',
  'subscriptions',
  'receipt_long',
  'pets',
  'flight',
  'payments',
  'trending_up',
  'target',
  'more_horiz',
];

const _colorChoices = [
  '#1F6F5C',
  '#B8862F',
  '#2E6B8F',
  '#C0562F',
  '#8F5FA6',
  '#A6738F',
  '#3A6B4F',
  '#5F7A8F',
  '#8F6B3A',
  '#2E8B75',
];

class NewCategoryResult {
  const NewCategoryResult({required this.name, required this.icon, required this.colorHex});

  final String name;
  final String icon;
  final String colorHex;
}

Future<NewCategoryResult?> showAddCategoryDialog(BuildContext context) {
  return showDialog<NewCategoryResult>(
    context: context,
    builder: (context) => const _AddCategoryDialog(),
  );
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  String _icon = _iconChoices.first;
  String _colorHex = _colorChoices.first;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(_colorHex);

    return AlertDialog(
      title: const Text('Nova categoria'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'Nome'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Ícone', style: AppTypography.captionEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _iconChoices.map((icon) {
                final selected = icon == _icon;
                return GestureDetector(
                  onTap: () => setState(() => _icon = icon),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? color : color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Icon(
                      categoryIconData(icon),
                      size: 18,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Cor', style: AppTypography.captionEmphasis),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _colorChoices.map((hex) {
                final swatch = colorFromHex(hex);
                final selected = hex == _colorHex;
                return GestureDetector(
                  onTap: () => setState(() => _colorHex = hex),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _nameController.text.trim().isEmpty
              ? null
              : () => Navigator.of(context).pop(
                    NewCategoryResult(
                      name: _nameController.text.trim(),
                      icon: _icon,
                      colorHex: _colorHex,
                    ),
                  ),
          child: const Text('Criar'),
        ),
      ],
    );
  }
}
