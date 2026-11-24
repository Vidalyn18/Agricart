String formatPeso(num amount) => '₱${amount.toStringAsFixed(2)}';

double roundCurrency(num amount) => (amount * 100).roundToDouble() / 100;
