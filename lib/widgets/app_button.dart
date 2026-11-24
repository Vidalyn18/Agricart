import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final bool isLoading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AgriCartColors.darkGreen,
                side: const BorderSide(color: AgriCartColors.cardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: content,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AgriCartColors.buttonGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AgriCartColors.buttonGreen.withValues(
                  alpha: 0.45,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: content,
            ),
    );
  }
}
