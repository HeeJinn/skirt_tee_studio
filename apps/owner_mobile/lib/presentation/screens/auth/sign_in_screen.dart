import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../../core/theme/shop_ui.dart';
import '../../widgets/shop_wordmark.dart';
import '../../widgets/ui/line_art.dart';

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
    const edge = Space.gutter + Space.xs;

    // Left-aligned and top-down, the way iOS sets up an account; the one
    // action is a capsule at the bottom, in reach of the thumb.
    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: Space.xl, bottom: Space.lg),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: edge),
                    child: ShopWordmark(scale: 0.8, alignment: CrossAxisAlignment.start),
                  ),
                  const SizedBox(height: Space.xxl),
                  // A tee and a dress, each drawn in one line as the screen opens.
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: edge),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LineArt(LineArtDrawing.tee, height: 88),
                        SizedBox(width: Space.sm),
                        LineArt(LineArtDrawing.dress, height: 88),
                      ],
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: edge),
                    child: Text(
                      'Sign in',
                      style: ShopType.hero(context).copyWith(fontFamily: ShopType.serif, fontSize: 36, letterSpacing: -0.6),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: edge),
                    child: Text(
                      "For the shop's owners. Use the owner login from Settings → Cloud backup on the shop computer.",
                      style: ShopType.subhead(context),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  CupertinoFormSection.insetGrouped(
                    // Sit on the shop's page color, not iOS grey.
                    backgroundColor: const Color(0x00000000),
                    margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
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
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            key: ValueKey(_error),
                            padding: const EdgeInsets.fromLTRB(edge, Space.md, edge, 0),
                            child: Row(
                              children: [
                                Icon(CupertinoIcons.exclamationmark_circle_fill, size: 16, color: ShopColors.of(context).danger),
                                const SizedBox(width: Space.sm),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: ShopType.footnote(context).copyWith(color: ShopColors.of(context).danger),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
              child: CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.large,
                borderRadius: BorderRadius.circular(Radii.pill),
                onPressed: busy ? null : _submit,
                child: busy
                    ? const CupertinoActivityIndicator(color: Color(0xFFFFFFFF))
                    : const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
