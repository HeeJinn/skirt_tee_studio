import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';

import 'package:shop_core/core/theme/app_theme.dart';

import '../../core/utils/date_stamp.dart';

import 'package:shop_core/data/datasources/local/database_service.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/domain/entities/staff.dart';

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

import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../viewmodels/session_view_model.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/cloud_status.dart';
import '../widgets/glass.dart';
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
    final cloud = context.watch<CloudSyncViewModel>().state;
    final destinations = kAppDestinations.where((d) => session.isOwner || !d.ownerOnly).toList();
    final selected = _selectedIndex.clamp(0, destinations.length - 1);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // Floats clear of the window edges, as iPadOS 26 insets it.
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, 0, AppSpacing.sm),
            child: _Sidebar(
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
              cloudState: session.isOwner && cloud.isConnected ? cloud : null,
              onLock: _lock,
            ),
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

/// The sidebar, as iPadOS 26 floats it: a glass pane inset from the
/// window's edges, the shop's mark at the top, destinations grouped under
/// sentence-case headings with their symbols in the accent, and the
/// account at the foot.
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.settingsOpen,
    required this.onOpenSettings,
    required this.user,
    required this.onBackup,
    required this.cloudState,
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

  /// Owners only, once this PC is connected to the cloud.
  final CloudSyncState? cloudState;
  final VoidCallback onLock;

  // With its 8pt inset, the same 224 the shop's screens were laid out beside.
  static const width = 216.0;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onSurface;

    final items = <Widget>[];
    String? currentSection;
    for (var i = 0; i < destinations.length; i++) {
      final destination = destinations[i];
      if (destination.section != currentSection) {
        currentSection = destination.section;
        items.add(
          Padding(
            padding: EdgeInsets.fromLTRB(12, items.isEmpty ? 0 : AppSpacing.lg, 12, 6),
            child: Semantics(
              header: true,
              child: Text(
                destination.section,
                style: context.text.labelMedium?.copyWith(color: context.tokens.mutedText),
              ),
            ),
          ),
        );
      }
      items.add(
        _NavItem(
          icon: i == selectedIndex ? destination.selectedIcon : destination.icon,
          label: destination.label,
          selected: i == selectedIndex,
          onTap: () => onSelect(i),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: LiquidGlass(
        shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 36, AppSpacing.md, AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The shop's logotype, set as its sign is.
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THE SKIRT & TEE',
                      style: TextStyle(
                        fontFamily: kSansFont,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.2,
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
              // The nav scrolls rather than overflowing when the window is
              // short (the runner allows windows down to 680 tall); the
              // footer below always stays in view.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
                ),
              ),
              if (cloudState != null) _CloudStatusItem(state: cloudState!, onTap: onOpenSettings),
              _NavItem(
                icon: settingsOpen ? CupertinoIcons.gear_solid : CupertinoIcons.gear,
                label: 'Settings',
                selected: settingsOpen,
                onTap: onOpenSettings,
              ),
              if (onBackup != null)
                _NavItem(
                  icon: CupertinoIcons.tray_arrow_down,
                  label: 'Back up data',
                  selected: false,
                  onTap: onBackup!,
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: AppSpacing.sm),
                child: Divider(),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  children: [
                    Monogram(name: user.name, radius: 16),
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
                    IconButton(icon: const Icon(CupertinoIcons.lock, size: 19), tooltip: 'Lock', onPressed: onLock),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One sidebar row: the symbol in the accent, the name beside it, and the
/// chosen row filled with a soft wash of the accent, as iPadOS marks it.
class _NavItem extends StatefulWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.onSurface;
    final brand = context.colors.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // A near-black accent (Studio Sage) would vanish in dark mode.
    final accent = dark && brand.computeLuminance() < 0.2 ? ink : brand;
    final background = widget.selected
        ? accent.withValues(alpha: dark ? 0.22 : 0.12)
        : _hovered
        ? context.tokens.sunken
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: widget.selected,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: ShapeDecoration(
                color: background,
                shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Icon(widget.icon, size: 20, color: accent)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                        color: ink,
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

/// One quiet line above Settings saying whether this PC is backed up; the
/// detail is in its tooltip, and a click opens Settings.
class _CloudStatusItem extends StatelessWidget {
  const _CloudStatusItem({required this.state, required this.onTap});

  final CloudSyncState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = CloudStatusLook.of(context, state);
    return Tooltip(
      message: look.detail,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        label: 'Cloud backup: ${look.label}. ${look.detail}',
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  SizedBox(width: 24, child: Icon(look.icon, size: 18, color: look.color)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      look.label,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(color: look.color, fontWeight: FontWeight.w600),
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
