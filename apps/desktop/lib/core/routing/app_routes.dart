import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
    icon: CupertinoIcons.cart,
    selectedIcon: CupertinoIcons.cart_fill,
  ),
  AppRouteDestination(
    route: AppRoute.inventory,
    label: 'Inventory',
    section: 'Manage',
    icon: CupertinoIcons.cube_box,
    selectedIcon: CupertinoIcons.cube_box_fill,
  ),
  AppRouteDestination(
    route: AppRoute.reservations,
    label: 'Reservations',
    section: 'Manage',
    icon: CupertinoIcons.calendar,
    selectedIcon: CupertinoIcons.calendar_today,
  ),
  AppRouteDestination(
    route: AppRoute.staff,
    label: 'Staff',
    section: 'Manage',
    icon: CupertinoIcons.person_2,
    selectedIcon: CupertinoIcons.person_2_fill,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.sales,
    label: 'Sales',
    section: 'Review',
    icon: CupertinoIcons.doc_text,
    selectedIcon: CupertinoIcons.doc_text_fill,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.reports,
    label: 'Reports',
    section: 'Review',
    icon: CupertinoIcons.chart_bar,
    selectedIcon: CupertinoIcons.chart_bar_fill,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.money,
    label: 'Money',
    section: 'Review',
    icon: CupertinoIcons.briefcase,
    selectedIcon: CupertinoIcons.briefcase_fill,
    ownerOnly: true,
  ),
  AppRouteDestination(
    route: AppRoute.customers,
    label: 'Customers',
    section: 'Review',
    icon: CupertinoIcons.person_3,
    selectedIcon: CupertinoIcons.person_3_fill,
    ownerOnly: true,
  ),
];
