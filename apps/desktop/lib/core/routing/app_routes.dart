import 'package:flutter/material.dart';

/// Kept as an enum + destination list (rather than named Navigator routes)
/// since the shell is a single persistent sidebar switching content in
/// place, not a stack of pushed pages.
enum AppRoute { pos, inventory, reservations, staff, sales, reports, money, customers }

class AppRouteDestination {
  const AppRouteDestination({
    required this.route,
    required this.label,
    required this.section,
    required this.icon,
    required this.selectedIcon,
    this.ownerOnly = false,
  });

  final AppRoute route;
  final String label;

  /// Sidebar group heading — destinations are grouped by the job they serve.
  final String section;
  final IconData icon;
  final IconData selectedIcon;

  /// Hidden from cashiers: money, customer data, and staff management.
  final bool ownerOnly;
}

const List<AppRouteDestination> kAppDestinations = [
  AppRouteDestination(
    route: AppRoute.pos,
    label: 'POS',
    section: 'Sell',
    icon: Icons.point_of_sale_outlined,
    selectedIcon: Icons.point_of_sale,
  ),
  AppRouteDestination(
    route: AppRoute.inventory,
    label: 'Inventory',
    section: 'Manage',
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2,
  ),
  AppRouteDestination(
    route: AppRoute.reservations,
    label: 'Reservations',
    section: 'Manage',
    icon: Icons.event_note_outlined,
    selectedIcon: Icons.event_note,
  ),
  AppRouteDestination(
    route: AppRoute.staff,
    label: 'Staff',
    section: 'Manage',
    icon: Icons.badge_outlined,
    selectedIcon: Icons.badge,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.sales,
    label: 'Sales',
    section: 'Review',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.reports,
    label: 'Reports',
    section: 'Review',
    icon: Icons.bar_chart_outlined,
    selectedIcon: Icons.bar_chart,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.money,
    label: 'Money',
    section: 'Review',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.customers,
    label: 'Customers',
    section: 'Review',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    ownerOnly: true,
  ),
];
