import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../utils/validators.dart';

/// Rules of a new password, under its field : what is missing in red, the rest in green.
/// Hidden while the field is empty.
class PasswordRules extends StatelessWidget {
  const PasswordRules({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.text.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8, left: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final rule in Validators.passwordRules)
                _RuleRow(
                  text: 'validation.password_rule_${rule.key}'.tr(args: ['${AppConstants.passwordMinLength}']),
                  ok: rule.test(value.text),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel, size: 16, color: color),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: TextStyle(fontSize: 13, color: color))),
        ],
      ),
    );
  }
}
