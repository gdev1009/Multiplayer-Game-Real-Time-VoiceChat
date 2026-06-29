import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text.dart';

/// A large labelled text field. The label is always visible text (never an
/// icon-only control), per the senior-first rules.
class BigTextField extends StatelessWidget {
  const BigTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.autofocus = false,
    this.errorText,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.words,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.body),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          style: AppText.body,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            errorStyle: AppText.error,
          ),
        ),
      ],
    );
  }
}
