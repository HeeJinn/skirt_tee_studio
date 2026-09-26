import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../widgets/shop_wordmark.dart';

/// Sign in with the shop's owner account — the same login used under
/// Settings → Cloud backup on the shop computer.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
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
    if (!_email.text.contains('@')) return setState(() => _error = 'Enter the account\'s email.');
    if (_password.text.isEmpty) return setState(() => _error = 'Enter the password.');
    setState(() => _error = null);
    final error = await context.read<CloudSyncViewModel>().signIn(_email.text, _password.text);
    if (mounted && error != null) setState(() => _error = error);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<CloudSyncViewModel>().busy;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 32),
              children: [
                const ShopWordmark(),
                const SizedBox(height: 32),
                CupertinoFormSection.insetGrouped(
                  header: const Text('SIGN IN'),
                  footer: const Text('Use the owner login from Settings → Cloud backup on the shop computer.'),
                  children: [
                    CupertinoTextFormFieldRow(
                      controller: _email,
                      prefix: const Text('Email'),
                      placeholder: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                    ),
                    CupertinoTextFormFieldRow(
                      controller: _password,
                      prefix: const Text('Password'),
                      placeholder: 'Required',
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      enabled: !busy,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(36, 0, 36, 16),
                    child: Text(
                      _error!,
                      style: TextStyle(fontSize: 13, color: CupertinoColors.systemRed.resolveFrom(context)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CupertinoButton.filled(
                    onPressed: busy ? null : _submit,
                    child: busy ? const CupertinoActivityIndicator() : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'For the shop owners only.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: secondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
