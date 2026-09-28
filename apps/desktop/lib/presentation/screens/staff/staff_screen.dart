import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/staff.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/ios_alert.dart';
import '../../widgets/monogram.dart';
import '../../widgets/screen_header.dart';
import '../../widgets/status_pill.dart';
import '../auth/sign_in_screen.dart';

final _when = DateFormat('MMM d · h:mm a');

/// Owner-only: who can sign in, and the audit trail of what they did.
class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  Future<void> _confirmRemove(BuildContext context, StaffMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => IosAlert(
        title: const Text('Remove Staff'),
        content: Text('${member.name} will no longer be able to sign in. Their past activity stays in the log.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.tokens.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SessionViewModel>().removeStaff(member);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Staff',
            subtitle: '${session.staff.length} people can sign in · every sale and edit is logged below',
            actions: [
              ElevatedButton.icon(
                onPressed: () => showDialog<void>(context: context, builder: (_) => const _AddStaffDialog()),
                icon: const Icon(CupertinoIcons.add, size: 18),
                label: const Text('Add Staff'),
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const SectionLabel('Team'),
                ListSurface(
                  children: [
                    for (final member in session.staff)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.sm, 10),
                        child: Row(
                          children: [
                            Monogram(name: member.name),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                member.id == session.current?.id ? '${member.name} (you)' : member.name,
                                style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            StatusPill(
                              label: member.role == StaffRole.owner ? 'Owner' : 'Cashier',
                              tone: member.role == StaffRole.owner ? PillTone.accent : PillTone.neutral,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              icon: const Icon(CupertinoIcons.person_badge_minus, size: 18),
                              tooltip: session.canRemove(member) ? 'Remove' : 'Can\'t remove yourself or the last owner',
                              onPressed: session.canRemove(member) ? () => _confirmRemove(context, member) : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                SectionLabel('Activity', trailing: 'Latest ${session.activity.length}'),
                if (session.activity.isEmpty)
                  const SizedBox(height: 160, child: EmptyState(icon: CupertinoIcons.clock, message: 'No activity yet'))
                else
                  ListSurface(
                    children: [
                      for (final entry in session.activity)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 140,
                                child: Text(
                                  _when.format(entry.at),
                                  style: context.text.bodySmall?.copyWith(fontFeatures: kTabularFigures),
                                ),
                              ),
                              SizedBox(
                                width: 140,
                                child: Text(
                                  entry.staffName,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(child: Text(entry.action, style: context.text.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddStaffDialog extends StatefulWidget {
  const _AddStaffDialog();

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  StaffRole _role = StaffRole.cashier;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<SessionViewModel>().addStaff(_name.text.trim(), _role, _pin.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Staff'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<StaffRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: StaffRole.cashier, child: Text('Cashier — POS, reservations, view stock')),
                  DropdownMenuItem(value: StaffRole.owner, child: Text('Owner — everything')),
                ],
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: pinInputFormatters,
                      decoration: const InputDecoration(labelText: 'PIN'),
                      validator: validatePin,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: pinInputFormatters,
                      decoration: const InputDecoration(labelText: 'Confirm PIN'),
                      validator: (v) => v == _pin.text ? null : 'Doesn\'t match',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
