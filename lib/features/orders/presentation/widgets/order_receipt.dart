import 'package:flutter/material.dart';

import '../../../../core/utils/currency.dart';
import '../../data/models/order_history_model.dart';
import 'print_receipt_helper.dart';

/// A clean, thermal-receipt-styled view of an approved [OrderHistory].
///
/// Rendered inside a modal dialog from the Order History screen, but kept as
/// a standalone widget so it can be tested and reused independently.
class OrderReceipt extends StatelessWidget {
  const OrderReceipt({super.key, required this.order});

  final OrderHistory order;

  // Store / business details shown in the receipt header.
  static const String _storeName = 'PharmaGuide Pharmacy';
  static const String _storeAddress = '123 Health Street, City';
  static const String _storeContact = 'Tel: (000) 000-0000';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 8,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _storeName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _storeAddress,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
                Text(
                  _storeContact,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                const _DashedDivider(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(label: 'OFFICIAL RECEIPT', color: Colors.black87),
                    const SizedBox(width: 8),
                    _Badge(label: 'APPROVED', color: const Color(0xFF2E7D4F)),
                  ],
                ),
                const SizedBox(height: 12),
                const _DashedDivider(),
                const SizedBox(height: 12),
                _metaRow('Order ID', order.id),
                _metaRow('Receipt No.', '#${order.id}'),
                _metaRow('Date & Time', order.formattedDate(context: context)),
                _metaRow('Customer Name', 'Walk-in Customer'),
                _metaRow('Payment Method', 'Cash'),
                const SizedBox(height: 12),
                const _DashedDivider(),
                const SizedBox(height: 8),
                // Itemized table header.
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Item',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Qty',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        'Price',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        'Total',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final line in order.items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            line.medicine.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${line.quantity}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            formatCentavos(line.medicine.priceCentavos),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            formatCentavos(line.totalCentavos),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const _DashedDivider(),
                const SizedBox(height: 8),
                _totalRow('Subtotal', formatCentavos(order.totalCentavos)),
                _totalRow('Tax (VAT)', formatCentavos(0)),
                _totalRow('Discount', formatCentavos(0)),
                _totalRow(
                  'Grand Total',
                  formatCentavos(order.totalCentavos),
                  bold: true,
                ),
                const SizedBox(height: 8),
                const _DashedDivider(),
                const SizedBox(height: 12),
                Text(
                  'Thank you for your order!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: printReceipt,
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const Text('Print / Save as PDF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashWidth = 6.0;
        final dashSpace = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) {
            return SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black26),
              ),
            );
          }),
        );
      },
    );
  }
}