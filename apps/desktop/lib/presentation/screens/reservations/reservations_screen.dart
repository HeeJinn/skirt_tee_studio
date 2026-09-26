import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/reservation.dart';
import 'package:shop_core/domain/entities/sale.dart';
import '../../viewmodels/inventory_view_model.dart';
import '../../viewmodels/reservation_view_model.dart';
import '../../viewmodels/sales_view_model.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/payment_icon.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_pill.dart';
import '../pos/cash_tender_dialog.dart';
import 'package:shop_core/calculations/reservation_grouping.dart';
import 'widgets/reservation_form_dialog.dart';

/// Core function: log online (FB/chat) reservations and get them picked up.
/// Sectioned by urgency — overdue first — because "who hasn't collected
/// yet?" is the question staff open this screen to answer.
class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});

  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  ReservationStatus? _statusFilter = ReservationStatus.pending;

  Future<void> _openAddDialog() async {
    final items = context.read<InventoryViewModel>().items;
    final result = await showDialog<Reservation>(
      context: context,
      builder: (_) => ReservationFormDialog(items: items),
    );
    if (result != null && mounted) {
      await context.read<ReservationViewModel>().addReservation(result);
      if (!mounted) return;
      await context.read<SessionViewModel>().log('Added reservation: ${result.customerName} · ${result.itemName}');
    }
  }

  Future<void> _openEditDialog(Reservation reservation) async {
    final items = context.read<InventoryViewModel>().items;
    final result = await showDialog<Reservation>(
      context: context,
      builder: (_) => ReservationFormDialog(items: items, reservation: reservation),
    );
    if (result != null && mounted) {
      await context.read<ReservationViewModel>().updateReservation(result);
      if (!mounted) return;
      await context.read<SessionViewModel>().log('Edited reservation: ${result.customerName} · ${result.itemName}');
    }
  }

  Future<void> _confirmCancel(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CANCEL RESERVATION'),
        content: Text('Remove ${reservation.customerName}\'s reservation for ${reservation.itemName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('KEEP IT')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.tokens.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CANCEL RESERVATION'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ReservationViewModel>().deleteReservation(reservation.id);
      if (!mounted) return;
      await context
          .read<SessionViewModel>()
          .log('Cancelled reservation: ${reservation.customerName} · ${reservation.itemName}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final all = context.watch<ReservationViewModel>().reservations;
    final visible = all.where((r) => _statusFilter == null || r.status == _statusFilter).toList();
    final groups = groupReservations(visible, now);

    final pending = all.where((r) => r.status == ReservationStatus.pending).toList();
    final overdue = pending.where((r) => bucketOf(r, now) == ReservationBucket.overdue).length;
    final dueToday = pending.where((r) => bucketOf(r, now) == ReservationBucket.today).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Reservations',
            subtitle: '${pending.length} pending · $overdue overdue · $dueToday due today',
            actions: [
              ElevatedButton.icon(
                onPressed: _openAddDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('ADD RESERVATION'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ChoiceStrip<ReservationStatus?>(
            options: const [
              (ReservationStatus.pending, 'Pending'),
              (ReservationStatus.pickedUp, 'Picked up'),
              (null, 'All'),
            ],
            selected: _statusFilter,
            onSelected: (s) => setState(() => _statusFilter = s),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: groups.isEmpty
                ? const EmptyState(icon: Icons.event_available_outlined, message: 'No reservations here')
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      for (final entry in groups.entries) ...[
                        SectionLabel(
                          entry.key.label,
                          trailing: '${entry.value.length}',
                          color: entry.key == ReservationBucket.overdue ? context.tokens.danger : null,
                        ),
                        ListSurface(
                          children: [
                            for (final r in entry.value)
                              _ReservationRow(
                                key: ValueKey(r.id),
                                reservation: r,
                                bucket: entry.key,
                                now: now,
                                onEdit: () => _openEditDialog(r),
                                onCancel: () => _confirmCancel(r),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReservationRow extends StatefulWidget {
  const _ReservationRow({
    super.key,
    required this.reservation,
    required this.bucket,
    required this.now,
    required this.onEdit,
    required this.onCancel,
  });

  final Reservation reservation;
  final ReservationBucket bucket;
  final DateTime now;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  State<_ReservationRow> createState() => _ReservationRowState();
}

class _ReservationRowState extends State<_ReservationRow> {
  bool _processing = false;

  Future<void> _markPickedUp() async {
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('PAID BY · ${widget.reservation.customerName}'),
        children: [
          for (final m in PaymentMethod.selectable)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(m),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                children: [
                  Icon(paymentIcon(m), size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Text(m.label, style: dialogContext.text.bodyLarge),
                ],
              ),
            ),
        ],
      ),
    );
    if (method == null || !mounted) return;

    final inventory = context.read<InventoryViewModel>();
    double? received;
    if (method == PaymentMethod.cash) {
      // Missing item: skip straight to completePickup, which explains why
      // the pickup can't go through.
      final item = inventory.items.where((i) => i.id == widget.reservation.itemId).firstOrNull;
      if (item != null) {
        received = await showCashTenderDialog(context, total: item.unitPrice, confirmLabel: 'COMPLETE PICKUP');
        if (received == null || !mounted) return;
      }
    }

    setState(() => _processing = true);
    try {
      await context
          .read<ReservationViewModel>()
          .completePickup(widget.reservation, inventory.items, method, amountTendered: received);
      if (!mounted) return;
      final r = widget.reservation;
      await Future.wait([
        inventory.load(),
        context.read<SalesViewModel>().load(),
        context
            .read<SessionViewModel>()
            .log('Completed pickup (sale): ${r.customerName} · ${r.itemName} · ${method.label}'),
      ]);
    } on PickupBlockedException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reservation;
    final tokens = context.tokens;
    final pending = r.status == ReservationStatus.pending;

    final (pillLabel, pillTone) = switch (widget.bucket) {
      ReservationBucket.overdue => (relativePickupLabel(r.pickupDate, widget.now).toUpperCase(), PillTone.danger),
      ReservationBucket.today => ('TODAY', PillTone.warning),
      ReservationBucket.upcoming => (relativePickupLabel(r.pickupDate, widget.now).toUpperCase(), PillTone.neutral),
      ReservationBucket.pickedUp => ('PICKED UP', PillTone.success),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 12, AppSpacing.sm, 12),
      child: Row(
        children: [
          _DateBlock(date: r.pickupDate, color: widget.bucket == ReservationBucket.overdue ? tokens.danger : null),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.customerName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${r.itemName}  ·  ${r.contact}', style: context.text.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          StatusPill(label: pillLabel, tone: pillTone),
          const SizedBox(width: AppSpacing.lg),
          if (pending)
            SizedBox(
              width: 152,
              height: 36,
              child: ElevatedButton(
                onPressed: _processing ? null : _markPickedUp,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                child: _processing
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: tokens.mutedText),
                      )
                    : const Text('MARK PICKED UP'),
              ),
            ),
          PopupMenuButton<VoidCallback>(
            tooltip: 'More actions',
            icon: Icon(Icons.more_horiz, color: tokens.mutedText),
            enabled: !_processing,
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(value: widget.onEdit, child: const Text('Edit')),
              PopupMenuItem(
                value: widget.onCancel,
                child: Text('Cancel reservation', style: TextStyle(color: context.tokens.danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Calendar-tile date ("SEP / 24") — the visual anchor of a date-driven list.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, this.color});
  final DateTime date;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurface;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: context.tokens.sunken,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Column(
        children: [
          Text(
            DateFormat('MMM').format(date).toUpperCase(),
            style: context.text.labelSmall?.copyWith(color: color ?? context.tokens.mutedText, fontSize: 10),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontFamily: kSansFont,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: c,
              height: 1.2,
              fontFeatures: kTabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
