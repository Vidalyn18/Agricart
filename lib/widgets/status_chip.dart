import 'package:flutter/material.dart';

import '../models/order.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      OrderStatus.pending => (const Color(0xFFFFF2D8), const Color(0xFF805900)),
      OrderStatus.confirmed => (
        const Color(0xFFE5F0FF),
        const Color(0xFF245A9B),
      ),
      OrderStatus.preparing => (
        const Color(0xFFF2E9FF),
        const Color(0xFF65449A),
      ),
      OrderStatus.outForDelivery => (
        const Color(0xFFE2F6F5),
        const Color(0xFF176D69),
      ),
      OrderStatus.readyForPickup => (
        const Color(0xFFE4F2FF),
        const Color(0xFF28638E),
      ),
      OrderStatus.completed => (
        const Color(0xFFE5F5E9),
        const Color(0xFF236B3A),
      ),
      OrderStatus.cancelled => (
        const Color(0xFFFFE8E6),
        const Color(0xFF9A3832),
      ),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
