import 'package:flutter/material.dart';

import '../providers/orders_provider.dart';

/// Tab segment control matching the Orders.html design.
class OrderTabs extends StatelessWidget {
  const OrderTabs({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    this.allCount = 0,
    this.newCount = 0,
    this.approvedCount = 0,
  });

  final OrderTab selectedTab;
  final ValueChanged<OrderTab> onTabChanged;
  final int allCount;
  final int newCount;
  final int approvedCount;

  @override
  Widget build(BuildContext context) {
    final brandColor = const Color(0xFF0E5A52);
    final muteColor = const Color(0xFF5B7079);
    final lineColor = const Color(0xFFD5E0DE);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: lineColor)),
      ),
      child: Row(
        children: [
          _TabButton(
            tab: OrderTab.all,
            label: 'All',
            count: allCount,
            selected: selectedTab == OrderTab.all,
            onTap: () => onTabChanged(OrderTab.all),
            brandColor: brandColor,
            muteColor: muteColor,
            lineColor: lineColor,
          ),
          _TabButton(
            tab: OrderTab.new_,
            label: 'New',
            count: newCount,
            selected: selectedTab == OrderTab.new_,
            onTap: () => onTabChanged(OrderTab.new_),
            brandColor: brandColor,
            muteColor: muteColor,
            lineColor: lineColor,
          ),
          _TabButton(
            tab: OrderTab.approved,
            label: 'Approved',
            count: approvedCount,
            selected: selectedTab == OrderTab.approved,
            onTap: () => onTabChanged(OrderTab.approved),
            brandColor: brandColor,
            muteColor: muteColor,
            lineColor: lineColor,
          ),
        ],
      ),
    );
  }
}

/// Individual tab button matching the HTML design.
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.brandColor,
    required this.muteColor,
    required this.lineColor,
  });

  final OrderTab tab;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color brandColor;
  final Color muteColor;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? brandColor : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? brandColor : muteColor,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7ECE8), // brand-soft
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: brandColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
