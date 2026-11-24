import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../utils/format_currency.dart';

class PriceSummary extends StatelessWidget {
  const PriceSummary({
    super.key,
    required this.subtotal,
    this.deliveryFee = 0,
    this.showDeliveryFee = true,
    this.showTotal = true,
    this.title,
  });

  final double subtotal;
  final double deliveryFee;
  final bool showDeliveryFee;
  final bool showTotal;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AgriCartColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
          ],
          _PriceRow(label: 'Subtotal', amount: formatPeso(subtotal)),
          if (showDeliveryFee) ...[
            const SizedBox(height: 7),
            _PriceRow(
              label: 'Delivery fee',
              amount: deliveryFee == 0 ? 'Free' : formatPeso(deliveryFee),
            ),
          ],
          if (showTotal) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1, color: AgriCartColors.cardBorder),
            ),
            _PriceRow(
              label: 'Total',
              amount: formatPeso(
                subtotal + (showDeliveryFee ? deliveryFee : 0),
              ),
              emphasize: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final String amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? AgriCartColors.darkGreen : Colors.black87;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: emphasize ? 15 : 13,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            color: color,
            fontSize: emphasize ? 15 : 13,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
