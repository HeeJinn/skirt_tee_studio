import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_stamp.dart';
import '../../data/datasources/local/database_service.dart';
import '../../domain/entities/staff.dart';
import '../screens/customers/customers_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/money/money_screen.dart';
import '../screens/pos/pos_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/reservations/reservations_screen.dart';
import '../screens/sales/sales_history_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/staff/staff_screen.dart';
import '../viewmodels/cart_view_model.dart';
import '../viewmodels/session_view_model.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/monogram.dart';

/// Desktop shell: persistent grouped sidebar + main content area.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  /// Settings lives in the sidebar footer rather than the grouped nav, so
  /// it's tracked apart from [_selectedIndex].
  bool _settingsOpen = false;

  static const _screens = <AppRoute, Widget>{
    AppRoute.pos: PosScreen(),
    AppRoute.inventory: InventoryScreen(),
    AppRoute.reservations: ReservationsScreen(),
    AppRoute.staff: StaffScreen(),
    AppRoute.sales: SalesHistoryScreen(),
    AppRoute.reports: ReportsScreen(),
    AppRoute.money: MoneyScreen(),
    AppRoute.customers: CustomersScreen(),
  };

  Future<void> _backupData() async {
    final suggestedName = 'skirt_tee_studio_backup_${dateStamp(DateTime.now())}.db';
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'SQLite database', extensions: ['db']),
      ],
    );
    if (location == null || !mounted) return;

    try {
      await DatabaseService.instance.backupTo(location.path);
      if (!mounted) return;
      showAppSnackBar(context, 'Backup saved');
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Backup failed — try again', isError: true);
    }
  }

  /// Clears any half-built sale so it can't be completed under the next
  /// person's name.
  Future<void> _lock() async {
    context.read<CartViewModel>().clear();
    await context.read<SessionViewModel>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final destinations = kAppDestinations.where((d) => session.isOwner || !d.ownerOnly).toList();
    final selected = _selectedIndex.clamp(0, destinations.length - 1);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            destinations: destinations,
            selectedIndex: _settingsOpen ? null : selected,
            onSelect: (i) => setState(() {
              _selectedIndex = i;
              _settingsOpen = false;
            }),
            settingsOpen: _settingsOpen,
            onOpenSettings: () => setState(() => _settingsOpen = true),
            user: session.current!,
            onBackup: session.isOwner ? _backupData : null,
            onLock: _lock,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              child: _settingsOpen
                  ? const KeyedSubtree(key: ValueKey('settings'), child: SettingsScreen())
                  : KeyedSubtree(
                      key: ValueKey(destinations[selected].route),
                      child: _screens[destinations[selected].route]!,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.settingsOpen,
    required this.onOpenSettings,
    required this.user,
    required this.onBackup,
    required this.onLock,
  });

  final List<AppRouteDestination> destinations;
  /// Null while the footer's Settings page is showing.
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final bool settingsOpen;
  final VoidCallback onOpenSettings;
  final StaffMember user;
  final VoidCallback? onBackup;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onSurface;
    final mist = context.colors.primaryContainer;

    final items = <Widget>[];
    String? currentSection;
    for (var i = 0; i < destinations.length; i++) {
      final destination = destinations[i];
      if (destination.section != currentSection) {
        currentSection = destination.section;
        items.add(Padding(
          padding: EdgeInsets.fromLTRB(12, items.isEmpty ? 0 : AppSpacing.lg, 12, 6),
          child: Text(destination.section.toUpperCase(), style: context.text.labelSmall),
        ));
      }
      items.add(_NavItem(
        icon: i == selectedIndex ? destination.selectedIcon : destination.icon,
        label: destination.label,
        selected: i == selectedIndex,
        onTap: () => onSelect(i),
      ));
    }

    return Container(
      width: 224,
      color: mist,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 36, AppSpacing.md, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE SKIRT & TEE',
                  style: TextStyle(
                    fontFamily: kSansFont,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    fontSize: 13,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'STUDIO',
                  style: TextStyle(
                    fontFamily: kSansFont,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 5,
                    fontSize: 10.5,
                    color: context.tokens.mutedText,
                  ),
                ),
              ],
            ),
          ),
          ...items,
          const Spacer(),
          _NavItem(
            icon: settingsOpen ? Icons.tune : Icons.tune_outlined,
            label: 'Settings',
            selected: settingsOpen,
            onTap: onOpenSettings,
            muted: true,
          ),
          if (onBackup != null)
            _NavItem(icon: Icons.backup_outlined, label: 'Back up data', selected: false, onTap: onBackup!, muted: true),
          const Divider(height: AppSpacing.lg),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              children: [
                Monogram(name: user.name, radius: 15, onSage: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(user.role == StaffRole.owner ? 'Owner' : 'Cashier', style: context.text.bodySmall),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.lock_outline, size: 18), tooltip: 'Lock', onPressed: onLock),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onSurface;
    final brand = context.colors.primary;
    final color = selected || !muted ? ink : context.tokens.mutedText;

    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? brand.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.control),
            hoverColor: ink.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: selected ? brand : context.tokens.mutedText),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: kSansFont,
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
