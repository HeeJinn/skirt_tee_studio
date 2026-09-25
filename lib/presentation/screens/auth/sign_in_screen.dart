import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/staff.dart';
import '../../viewmodels/session_view_model.dart';
import '../../widgets/monogram.dart';

/// 4–6 digits: quick to type at a till, and the only format accepted.
String? validatePin(String? v) =>
    RegExp(r'^\d{4,6}$').hasMatch(v ?? '') ? null : 'Use 4 to 6 digits';

final pinInputFormatters = [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)];

/// Gate in front of the shell: first-run owner setup, otherwise pick who's
/// working and enter their PIN.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();

    return Scaffold(
      backgroundColor: context.colors.primaryContainer,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.container),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('THE SKIRT & TEE', style: context.text.headlineSmall, textAlign: TextAlign.center),
                Text('STUDIO', style: context.text.labelSmall?.copyWith(letterSpacing: 5), textAlign: TextAlign.center),
                const SizedBox(height: 28),
                if (session.staff.isEmpty) const _OwnerSetupForm() else _PickAndSignIn(staff: session.staff),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerSetupForm extends StatefulWidget {
  const _OwnerSetupForm();

  @override
  State<_OwnerSetupForm> createState() => _OwnerSetupFormState();
}

class _OwnerSetupFormState extends State<_OwnerSetupForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pin = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SessionViewModel>().createFirstOwner(_name.text.trim(), _pin.text);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Set up the owner account', style: context.text.titleMedium),
          const SizedBox(height: 4),
          Text(
            'The owner can manage stock, staff, and reports. You can add cashiers after this.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: pinInputFormatters,
            decoration: const InputDecoration(labelText: 'PIN (4–6 digits)'),
            validator: validatePin,
          ),
          const SizedBox(height: 12),
          TextFormField(
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: pinInputFormatters,
            decoration: const InputDecoration(labelText: 'Confirm PIN'),
            validator: (v) => v == _pin.text ? null : 'PINs don\'t match',
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          SizedBox(height: 48, child: ElevatedButton(onPressed: _submit, child: const Text('CREATE OWNER ACCOUNT'))),
        ],
      ),
    );
  }
}

class _PickAndSignIn extends StatefulWidget {
  const _PickAndSignIn({required this.staff});
  final List<StaffMember> staff;

  @override
  State<_PickAndSignIn> createState() => _PickAndSignInState();
}

class _PickAndSignInState extends State<_PickAndSignIn> {
  final _pin = TextEditingController();
  StaffMember? _selected;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final member = _selected;
    if (member == null || _busy) return;
    setState(() => _busy = true);
    final ok = await context.read<SessionViewModel>().signIn(member, _pin.text);
    if (!mounted || ok) return;
    setState(() {
      _busy = false;
      _error = 'Wrong PIN — try again';
      _pin.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Who\'s working?', style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.md),
        for (final member in widget.staff)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: member == _selected ? context.colors.onSurface.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: () => setState(() {
                  _selected = member;
                  _error = null;
                  _pin.clear();
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Monogram(name: member.name, radius: 16),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(member.name, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                      Text(member.role == StaffRole.owner ? 'Owner' : 'Cashier', style: context.text.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_selected != null) ...[
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: ValueKey(_selected!.id),
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: pinInputFormatters,
            decoration: InputDecoration(labelText: 'PIN for ${_selected!.name}', errorText: _error),
            onSubmitted: (_) => _signIn(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _busy ? null : _signIn,
              child: _busy
                  ? SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.mutedText))
                  : const Text('SIGN IN'),
            ),
          ),
        ],
      ],
    );
  }
}
