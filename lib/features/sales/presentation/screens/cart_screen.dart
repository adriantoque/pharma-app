import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../orders/data/models/order_line_model.dart';
import '../../../orders/presentation/providers/order_provider.dart';
import '../../domain/payment_method.dart';

/// What the cart screen hands back when it pops.
///
/// A record rather than a bool because the user can change the payment method
/// while the cart is open, and the sale screen needs to hear about it whether
/// or not Proceed was tapped. Returning `null` means the user dismissed the
/// screen without committing to anything.
@immutable
class CartResult {
  const CartResult({required this.proceed, required this.payment});

  /// Whether the user asked to complete the sale. A dismiss returns null from
  /// the route, not a false here -- both mean the same thing, but null is what
  /// `Navigator.pop` gives you for free.
  final bool proceed;

  /// The payment method as it stood when the screen was closed. May differ
  /// from the one it was opened with.
  final PaymentMethod payment;
}

/// The full-screen cart.
///
/// A page rather than a bottom sheet because a cart with twenty lines is a
/// page-sized piece of content: a sheet that tall fights the keyboard and
/// makes the dismiss gesture a guessing game. Here the item list scrolls, the
/// checkout footer stays pinned, and the back arrow does what back arrows do.
///
/// The screen does not touch [OrderProvider] to *complete* the sale -- that
/// stays on the sale screen. Its only job is to build the cart and hand back
/// what the user decided.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key, required this.initialPayment});

  /// The payment method that was selected when the cart was opened. The user
  /// can change it here; the final value goes back through [CartResult].
  final PaymentMethod initialPayment;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late PaymentMethod _payment = widget.initialPayment;

  /// Pops with a result that carries whatever the user selected, so the sale
  /// screen stays in step even when Proceed was never tapped.
  void _pop({required bool proceed}) {
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
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    context.read<OrderProvider>().clear();
    // Stay on the cart screen so the empty state is visible -- an instant pop
    // would leave the user wondering whether anything happened.
  }

  @override
  Widget build(BuildContext context) {
    final order = context.watch<OrderProvider>();
    final lines = order.lines;

    return Scaffold(
      appBar: AppBar(
        // The count is the one fact a pharmacist wants from this screen's
        // chrome; the rest is in the footer.
        title: Text(
          lines.isEmpty
              ? 'Cart'
              : 'Cart · ${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
        ),
        actions: [
          if (lines.isNotEmpty)
            IconButton(
              tooltip: 'Clear cart',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: lines.isEmpty
          ? _EmptyCart(onBack: () => _pop(proceed: false))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: lines.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                    ),
                    itemBuilder: (context, index) => _CartItemTile(
                      line: lines[index],
                      compact: false,
                    ),
                  ),
                ),
                _CheckoutFooter(
                  order: order,
                  selectedPayment: _payment,
                  onPaymentChanged: (v) => setState(() => _payment = v),
                  onProceed: () => _pop(proceed: true),
                ),
              ],
            ),
    );
  }
}

/// The empty state, reachable only by deleting the last item from the cart.
///
/// Not an error: it is exactly what a user who cleared their order asked for.
/// The button is a way back, not a retry.
class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a medicine from the product list to begin a sale.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to products'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pinned bottom section: totals, payment method, and the Proceed button.
///
/// Kept out of the scroll view on purpose. A cart whose total scrolls off the
/// screen is a cart the user has to scroll to check out of, and the total is
/// the one number the entire screen exists to show.
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

    return Material(
      // Raised off the list behind it, so the boundary is a surface change
      // rather than a hairline rule.
      elevation: 4,
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _PaymentMethodSelector(
                selectedPayment: selectedPayment,
                onChanged: onPaymentChanged,
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('proceedButton'),
                onPressed: onProceed,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text('Proceed'),
              ),
            ],
          ),
        ),
      ),
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

    final hPadding = compact ? 12.0 : 16.0;
    final vPadding = compact ? 6.0 : 8.0;
    final nameStyle = compact
        ? theme.textTheme.bodyMedium
        : theme.textTheme.bodyLarge;
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
                if (!compact) const SizedBox(height: 2),
                if (!compact)
                  Text(
                    line.formattedQuantity,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
          // The group reports a nullable value; this screen has no third state,
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
