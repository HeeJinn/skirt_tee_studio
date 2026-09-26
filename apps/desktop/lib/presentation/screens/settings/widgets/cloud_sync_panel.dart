import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/cloud_sync.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';
import '../../../widgets/app_snackbar.dart';
import '../../../widgets/cloud_status.dart';

/// Owners only: connect this computer to the shop's cloud backup, see how
/// it's doing, or disconnect.
class CloudSyncPanel extends StatelessWidget {
  const CloudSyncPanel({super.key});

  Future<void> _connect(BuildContext context) async {
    final connected = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ConnectDialog(),
    );
    if (connected == true && context.mounted) {
      showAppSnackBar(context, 'Connected — this computer now backs up to the cloud');
    }
  }

  Future<void> _disconnect(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('DISCONNECT FROM CLOUD'),
        content: const SizedBox(
          width: 380,
          child: Text(
            'This computer stops backing up. Everything stays on this computer, and anything '
            'changed meanwhile uploads when you connect again with the same account.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('CANCEL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dialogContext.tokens.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DISCONNECT'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<CloudSyncViewModel>().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<CloudSyncViewModel>();
    final state = sync.state;
    final look = CloudStatusLook.of(context, state);
    final tokens = context.tokens;

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.container),
        border: Border.all(color: tokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(look.icon, size: 22, color: look.color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(look.label, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(look.detail, style: context.text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (state.status == CloudStatus.signedOut) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Keep a copy of every sale, stock change and money entry in the cloud. '
              'If this computer breaks, sign in on a new one and everything comes back.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: sync.busy ? null : () => _connect(context),
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('CONNECT TO CLOUD'),
            ),
          ],
          if (state.isConnected) ...[
            if (state.status == CloudStatus.paused && state.error != null) ...[
              const SizedBox(height: AppSpacing.md),
              SelectableText(state.error!, style: context.text.bodySmall?.copyWith(color: tokens.danger)),
            ],
            const Divider(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Signed in as ${state.email ?? 'owner account'}',
                    style: context.text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: sync.busy ? null : () => _disconnect(context),
                  child: const Text('DISCONNECT'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog();

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    final error = await context.read<CloudSyncViewModel>().signIn(_email.text, _password.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<CloudSyncViewModel>().busy;

    return AlertDialog(
      title: const Text('CONNECT TO CLOUD'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sign in with the shop\'s owner account.', style: context.text.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                autofocus: true,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v ?? '').contains('@') ? null : 'Enter the account\'s email',
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _password,
                enabled: !busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (v) => (v ?? '').isEmpty ? 'Enter the password' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(_error!, style: context.text.bodySmall?.copyWith(color: context.tokens.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('CONNECT'),
        ),
      ],
    );
  }
}
