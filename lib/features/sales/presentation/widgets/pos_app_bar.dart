import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class PosAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PosAppBar({super.key, this.actions = const []});

  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final name = auth.user?.name?.trim() ?? '';
    final nameParts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final initials = nameParts
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();

    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_pharmacy_rounded,
            color: AppColors.secondary,
            size: 30,
          ),
          const SizedBox(width: 8),
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PharmaStaff POS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  'Pharmacy counter',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Color(0xFF9FB5CC)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Tooltip(
          message: auth.isOffline
              ? 'Changes are saved on this device only'
              : 'Connected',
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: auth.isOffline
                  ? const Color(0xFF352F1D)
                  : const Color(0xFF12392F),
              border: Border.all(
                color: auth.isOffline
                    ? const Color(0xFF927127)
                    : const Color(0xFF176B58),
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 7,
                  color: auth.isOffline ? AppColors.warning : AppColors.success,
                ),
                const SizedBox(width: 5),
                Text(
                  auth.isOffline ? 'Offline Mode' : 'Online',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: auth.isOffline
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFF6EE7B7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () => context.pushNamed('home-notifications'),
        ),
        PopupMenuButton<String>(
          tooltip: 'Profile and more',
          onSelected: (route) => context.pushNamed(route),
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'home-profile',
              child: ListTile(
                leading: Icon(Icons.account_circle_outlined),
                title: Text('Profile'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(value: 'home-expiring', child: Text('Expiring Meds')),
            PopupMenuItem(value: 'medicines', child: Text('Medicine list')),
            PopupMenuItem(value: 'orders', child: Text('Orders')),
            PopupMenuItem(value: 'orders-history', child: Text('Order history')),
          ],
          child: Padding(
            padding: const EdgeInsets.only(left: 2, right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              foregroundColor: AppColors.secondaryLight,
              child: Text(
                initials.isEmpty ? 'WP' : initials,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        ...actions,
      ],
    );
  }
}
