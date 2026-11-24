import 'package:flutter/material.dart';

import '../app_theme.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.labelAbove = true,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool labelAbove;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  void _toggleVisibility() {
    final selection = widget.controller.selection;
    setState(() => _obscure = !_obscure);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !selection.isValid) return;
      if (selection.end <= widget.controller.text.length) {
        widget.controller.selection = selection;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibilityLabel = _obscure ? 'Show password' : 'Hide password';
    final field = TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.labelAbove ? null : widget.label,
        hintText: widget.hint,
        hintStyle: const TextStyle(
          color: AgriCartColors.mutedText,
          fontSize: 14,
        ),
        suffixIcon: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Semantics(
            label: visibilityLabel,
            button: true,
            child: IconButton(
              tooltip: visibilityLabel,
              mouseCursor: SystemMouseCursors.click,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: EdgeInsets.zero,
              color: AgriCartColors.darkGreen,
              onPressed: _toggleVisibility,
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
      ),
    );

    if (!widget.labelAbove) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: AgriCartColors.darkGreen,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        field,
      ],
    );
  }
}
