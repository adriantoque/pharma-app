import 'package:flutter/material.dart';

import '../../data/models/order_history_model.dart';

/// Order card matching the Orders.html design.
class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.order, this.onApprove});

  final OrderHistory order;
  final VoidCallback? onApprove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build the approve button conditionally
    final Widget approveButton = order.status == OrderStatus.new_
        ? ElevatedButton(
            onPressed: onApprove,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E5A52),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Approve',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          )
        : const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFD5E0DE)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Order #, status badge, time
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Bricolage Grotesque',
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.relativeTime,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: order.statusBackgroundColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: order.statusColor),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: order.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Items list
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: const Color(0xFFD5E0DE)),
                  bottom: BorderSide(color: const Color(0xFFD5E0DE)),
                ),
              ),
              child: Column(
                children: order.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.medicine.name,
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          '× ${item.quantity}',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            // Footer: total and approve button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.formattedTotal,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Bricolage Grotesque',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                approveButton,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
