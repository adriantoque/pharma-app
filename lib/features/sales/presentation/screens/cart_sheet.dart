import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../orders/data/models/order_line_model.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../domain/payment_method.dart';

/// What the cart sheet hands back when it closes.
///
/// A record rather than a bool because the user can change the payment method
/// while the sheet is open, and the sale screen needs to hear about it whether
/// or not Complete Sale was tapped. Returning `null` means the user dismissed
/// the sheet without committing to anything.
@immutable
class CartResult {
  const CartResult({required this.proceed, required this.payment});

  /// Whether the user asked to complete the sale. A dismissal returns null
  /// from the sheet, not a false here -- both mean the same thing, but null is
  /// what `Navigator.pop` gives you for free.
  final bool proceed;

  /// The payment method as it stood when the sheet was closed. May differ from
  /// the one it was opened with.
  final PaymentMethod payment;
}

/// Opens the cart as the sample's bottom sheet.
///
/// The sheet does not touch [OrderProvider] to *complete* the sale -- that
/// stays on the sale screen, which reads [CartResult] back and runs the
/// confirmation. Its only job is to show the cart and hand back what the user
/// decided.
Future<CartResult?> showCartSheet(
  BuildContext context, {
  required PaymentMethod initialPayment,
}) {
  return showModalBottomSheet<CartResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // The sheet is most of the screen, so a long cart does not become a list
    // inside a scroll view inside itself.
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CartSheet(initialPayment: initialPayment),
  );
}

class _CartSheet extends StatefulWidget {
  const _CartSheet({required this.initialPayment});

  /// The payment method that was selected when the sheet was opened. The user
  /// can change it here; the final value goes back through [CartResult].
  final PaymentMethod initialPayment;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late PaymentMethod _payment = widget.initialPayment;

  /// Closes with a result that carries whatever the user selected, so the sale
  /// screen stays in step even when Complete Sale was never tapped.
  void _close({required bool proceed}) {
    Navigator.of(context).pop(
      CartResult(proceed: proceed, payment: _payment),
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text(
          'Remove every item from this order? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.brandGreenSurface,
              foregroundColor: AppColors.brandGreen,
              side: const BorderSide(
                color: AppColors.brandGreenSurfaceBorder,
              ),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    context.read<OrderProvider>().clear();
    // Stay on the sheet so the empty state is visible -- an instant close
    // would leave the user wondering whether anything happened.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = context.watch<OrderProvider>();
    final lines = order.lines;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The header the sample draws: the count is the one fact the sheet
            // exists to state, and the X dismisses it in one tap.
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Current Cart (${order.itemCount})',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (lines.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear cart',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: _confirmClear,
                  ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => _close(proceed: false),
                ),
              ],
            ),
            const Divider(),

            if (lines.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Cart is empty',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else ...[
              Expanded(
                child: ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) => _CartItemTile(
                    line: lines[index],
                    compact: false,
                  ),
                ),
              ),
              const Divider(),
              _CheckoutFooter(
                order: order,
                selectedPayment: _payment,
                onPaymentChanged: (v) => setState(() => _payment = v),
                onProceed: () => _close(proceed: true),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The pinned bottom section: payment method, the total, and the button that
/// ends the sale.
///
/// Kept out of the scroll view on purpose. A cart whose total scrolls off the
/// screen is a cart the user has to scroll to check out of, and the total is
/// the one number the entire sheet exists to show.
class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({
    required this.order,
    required this.selectedPayment,
    required this.onPaymentChanged,
    required this.onProceed,
  });

  final OrderProvider order;
  final PaymentMethod selectedPayment;
  final ValueChanged<PaymentMethod> onPaymentChanged;
  final VoidCallback onProceed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaymentMethodSelector(
          selectedPayment: selectedPayment,
          onChanged: onPaymentChanged,
        ),
        const SizedBox(height: 14),
        // One total, the way this app has always tallied: no subtotal, no tax
        // rows, just the figure that leaves the counter.
        Row(
          children: [
            Expanded(
              child: Text(
                '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text('Total', style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              order.formattedTotal,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brandGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // The one button that ends the sale, so it is the one solid green
        // thing on the sheet.
        FilledButton(
          key: const Key('proceedButton'),
          onPressed: onProceed,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: AppColors.brandGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Complete Sale'),
        ),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.line, this.compact = false});

  final OrderLineModel line;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = context.read<OrderProvider>();
    final medicine = line.medicine;
    final atMax = line.quantity >= OrderProvider.capFor(medicine);

    final hPadding = compact ? 12.0 : 4.0;
    final vPadding = compact ? 6.0 : 8.0;
    final nameStyle = compact
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    final qtyStyle = compact
        ? theme.textTheme.bodySmall
        : theme.textTheme.bodyLarge;
    final totalStyle = compact
        ? theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          )
        : theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          );
    final iconSize = compact ? 20.0 : 24.0;
    final qtyWidth = compact ? 24.0 : 28.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, vPadding, hPadding / 2, vPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicine.name,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${line.formattedQuantity} × ${medicine.formattedPrice}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(line.formattedTotal, style: totalStyle),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => order.setQuantity(medicine, line.quantity - 1),
            icon: Icon(Icons.remove_circle_outline, size: iconSize),
            tooltip: 'One fewer ${medicine.name}',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: qtyWidth,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.center,
              style: qtyStyle,
            ),
          ),
          IconButton(
            onPressed: atMax
                ? null
                : () => order.setQuantity(medicine, line.quantity + 1),
            icon: Icon(Icons.add_circle_outline, size: iconSize),
            tooltip: 'One more ${medicine.name}',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: () => order.remove(medicine),
            icon: Icon(Icons.delete_outline, size: iconSize),
            tooltip: 'Remove ${medicine.name}',
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector({
    required this.selectedPayment,
    required this.onChanged,
  });

  final PaymentMethod selectedPayment;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Payment Method', style: theme.textTheme.labelSmall),
        const SizedBox(height: 6),
        // The group owns the selection, so the radios below do not each have to
        // be handed the same value and a change handler.
        RadioGroup<PaymentMethod>(
          groupValue: selectedPayment,
          // The group reports a nullable value; this sheet has no third state,
          // so a deselection is simply ignored.
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _PaymentMethodTile(
                key: const Key('paymentCashOnHand'),
                label: 'Cash on Hand',
                value: PaymentMethod.cashOnHand,
                selectedPayment: selectedPayment,
                onChanged: onChanged,
              ),
              _PaymentMethodTile(
                key: const Key('paymentGCash'),
                label: 'GCash',
                subtitle: 'Coming soon',
                value: PaymentMethod.gcash,
                selectedPayment: selectedPayment,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.selectedPayment,
    required this.onChanged,
  });

  final String label;
  final String? subtitle;
  final PaymentMethod value;
  final PaymentMethod selectedPayment;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = selectedPayment == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selection comes from the surrounding RadioGroup.
            Radio<PaymentMethod>(value: value),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
