import 'package:flutter/material.dart';

import '../../../../core/utils/currency.dart';
import '../../data/models/receipt_model.dart';

/// A thermal-receipt-styled rendering of a [ReceiptModel].
///
/// Used both on screen (inside [ReceiptScreen]) and as the visual source of
/// truth that the PDF service mirrors. Keeping them in sync means what the
/// cashier shows the customer is what lands in the PDF.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key, required this.receipt});

  final ReceiptModel receipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 8,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Text(
                  receipt.storeName.isNotEmpty ? receipt.storeName : 'PharmaGuide Pharmacy',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'OFFICIAL RECEIPT',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: const Color(0xFF059669),
                  ),
                ),
                if (receipt.storeAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    receipt.storeAddress,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (receipt.storePhone.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    receipt.storePhone,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _dashedDivider(),
                const SizedBox(height: 10),

                // ── Meta ──
                _metaRow('Receipt #', receipt.receiptId),
                _metaRow('Date', receipt.formattedDateTime),
                _metaRow('Cashier', receipt.cashierName),
                _metaRow('Payment', receipt.paymentMethod),
                const SizedBox(height: 10),
                _dashedDivider(),
                const SizedBox(height: 8),

                // ── Item table header ──
                _tableHeader(),
                const SizedBox(height: 4),

                // ── Item rows ──
                for (final item in receipt.items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.name,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            formatCentavos(item.unitPriceCentavos),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text(
                            item.formattedTotal,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _dashedDivider(),
                const SizedBox(height: 8),

                // ── Totals ──
                _totalRow(context, 'Subtotal', receipt.subtotalCentavos),
                if (receipt.discountCentavos > 0)
                  _totalRow(
                    context,
                    'Discount',
                    -receipt.discountCentavos,
                  ),
                if (receipt.taxCentavos > 0)
                  _totalRow(context, 'Tax (VAT)', receipt.taxCentavos),
                _totalRow(
                  context,
                  'TOTAL',
                  receipt.totalCentavos,
                  bold: true,
                  color: const Color(0xFF059669),
                ),
                const SizedBox(height: 10),

                // ── Cash breakdown ──
                if (receipt.cashTenderedCentavos != null &&
                    receipt.changeCentavos != null) ...[
                  _totalRow(
                    context,
                    'Cash tendered',
                    receipt.cashTenderedCentavos!,
                  ),
                  _totalRow(
                    context,
                    'Change',
                    receipt.changeCentavos!,
                  ),
                  const SizedBox(height: 10),
                  _dashedDivider(),
                  const SizedBox(height: 8),
                ],

                // ── Footer ──
                Text(
                  'Thank you for your patronage!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Computer-generated receipt.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.black45,
                  ),
                ),
              ],
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
              fontSize: 12.5,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            'Item',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            'Qty',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            'Price',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            'Total',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    int centavos, {
    bool bold = false,
    Color? color,
  }) {
    final formatted = formatCentavos(centavos.abs());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
          Text(
            formatted,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: bold ? 13.5 : 12.5,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dashWidth = 5.0;
        final dashSpace = 3.0;
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
