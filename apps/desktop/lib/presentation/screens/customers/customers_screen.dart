import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import '../../viewmodels/reservation_view_model.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/monogram.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_pill.dart';
import 'package:shop_core/calculations/customer_calculations.dart';

final _date = DateFormat('MMM d, y');

/// Core function: who keeps coming back, and what have they reserved.
/// Not a separate customer database — derived by grouping reservations by
/// contact, since that's the only place customer identity already lives.
/// (POS walk-in sales carry no customer info, so they can't appear here.)
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final all = groupByCustomer(context.watch<ReservationViewModel>().reservations);
    final repeat = all.where((c) => c.totalReservations > 1).length;
    final customers = all.where((c) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return c.customerName.toLowerCase().contains(q) || c.contact.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Customers',
            subtitle: '${all.length} customers · $repeat repeat · from reservation history, not walk-in sales',
          ),
          const SizedBox(height: 20),
          SearchField(hint: 'Search name or contact', onChanged: (v) => setState(() => _search = v)),
          const SizedBox(height: 20),
          Expanded(
            child: customers.isEmpty
                ? const EmptyState(icon: CupertinoIcons.person_3, message: 'No customers found')
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ListSurface(
                      children: [for (final c in customers) _CustomerRow(key: ValueKey(c.contact), customer: c)],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerRow extends StatefulWidget {
  const _CustomerRow({super.key, required this.customer});
  final CustomerSummary customer;

  @override
  State<_CustomerRow> createState() => _CustomerRowState();
}

class _CustomerRowState extends State<_CustomerRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    final tokens = context.tokens;
    final pending = customer.totalReservations - customer.pickedUpCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
            child: Row(
              children: [
                Monogram(name: customer.customerName),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              customer.customerName,
                              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (customer.totalReservations > 1) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const StatusPill(label: 'Repeat'),
                          ],
                        ],
                      ),
                      Text(customer.contact, style: context.text.bodySmall),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    '${customer.totalReservations} reservation${customer.totalReservations == 1 ? '' : 's'}',
                    style: context.text.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: pending > 0
                      ? StatusPill(label: '$pending pending', tone: PillTone.warning)
                      : Text('All picked up', style: context.text.bodySmall),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    'Last ${_date.format(customer.lastActivity)}',
                    style: context.text.bodySmall,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(CupertinoIcons.chevron_down, size: 20, color: tokens.mutedText),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Container(
                  color: tokens.sunken,
                  padding: const EdgeInsets.fromLTRB(68, AppSpacing.sm, AppSpacing.lg + 32, AppSpacing.sm),
                  child: Column(
                    children: [
                      for (final r in customer.reservations)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(child: Text(r.itemName, style: context.text.bodySmall)),
                              SizedBox(
                                width: 120,
                                child: Text(_date.format(r.pickupDate), style: context.text.bodySmall),
                              ),
                              SizedBox(
                                width: 96,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: r.status == ReservationStatus.pickedUp
                                      ? const StatusPill(label: 'Picked up', tone: PillTone.success)
                                      : const StatusPill(label: 'Pending', tone: PillTone.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
