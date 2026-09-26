import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../../core/theme/shop_ui.dart';
import '../../widgets/shop_wordmark.dart';
import '../../widgets/ui/line_art.dart';
import '../../widgets/ui/section.dart';

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
                const SizedBox(height: Space.xxl),
                // A tee and a dress, each drawn in one line as the screen opens.
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LineArt(LineArtDrawing.tee, height: 88),
                    SizedBox(width: Space.sm),
                    LineArt(LineArtDrawing.dress, height: 88),
                  ],
                ),
                const SizedBox(height: Space.xxl),
                const SectionHeader('Sign in', top: 0),
                CupertinoFormSection.insetGrouped(
                  // Sit on the shop's page color, not iOS grey.
                  backgroundColor: const Color(0x00000000),
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
                const SectionFooter('Use the owner login from Settings → Cloud backup on the shop computer.'),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Space.gutter + Space.lg, Space.md, Space.gutter + Space.lg, 0),
                    child: Text(
                      _error!,
                      style: ShopType.footnote(context).copyWith(color: ShopColors.of(context).danger),
                    ),
                  ),
                const SizedBox(height: Space.xl),
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
