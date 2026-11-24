import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_theme.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imagePath,
    this.imageBytes,
    this.fit = BoxFit.cover,
  });

  final String? imagePath;
  final Uint8List? imageBytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    final path = imagePath?.trim();
    if (path == null || path.isEmpty) return _fallback();
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: AgriCartColors.background,
      alignment: Alignment.center,
      child: const Icon(
        Icons.eco_outlined,
        size: 38,
        color: AgriCartColors.buttonGreen,
      ),
    );
  }
}
