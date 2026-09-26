import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:shop_core/viewmodels/cloud_sync_view_model.dart';

import '../../../core/theme/shop_ui.dart';
import '../../widgets/ui/line_art.dart';

/// Sign in with the shop's owner account — the same login used under
/// Settings → Cloud backup on the shop computer.
///
/// Laid out the way iOS signs in to an Apple Account: the shop's drawing,
/// a centered title and why to sign in, then the email alone. Continue
/// brings in the password beneath it, in the same rounded group. When
/// Password AutoFill fills both at once, it goes straight to the password
/// step.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _askPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Enables Continue and Sign In as soon as there's something to send.
    _email.addListener(_changed);
    _password.addListener(_changed);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _changed() {
    // AutoFill filled the hidden password along with the email.
    if (!_askPassword && _password.text.isNotEmpty) _askPassword = true;
    setState(() {});
  }

  bool get _ready => _askPassword ? _password.text.isNotEmpty : _email.text.trim().isNotEmpty;

  void _continue() {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return setState(() => _error = "Enter the account's email.");
    }
    setState(() {
      _error = null;
      _askPassword = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _passwordFocus.requestFocus());
  }

  Future<void> _signIn() async {
    if (_password.text.isEmpty) return setState(() => _error = 'Enter the password.');
    setState(() => _error = null);
    final error = await context.read<CloudSyncViewModel>().signIn(_email.text.trim(), _password.text);
    if (mounted && error != null) setState(() => _error = error);
  }

  void _forgotPassword() => showCupertinoDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Forgot Password?'),
          content: const Text(
            "It's the owner login the shop computer uses, under Settings → Cloud backup. "
            'If no one remembers it, ask whoever set up the cloud backup to reset it.',
          ),
          actions: [
            CupertinoDialogAction(isDefaultAction: true, onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<CloudSyncViewModel>().busy;
    final colors = ShopColors.of(context);

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(Space.gutter, 56, Space.gutter, Space.lg),
                children: [
                  // A tee and a dress, each drawn in one line as the screen
                  // opens: the shop's mark, where iOS puts an app's icon.
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LineArt(LineArtDrawing.tee, height: 72),
                      SizedBox(width: Space.sm),
                      LineArt(LineArtDrawing.dress, height: 72),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      'Sign In',
                      textAlign: TextAlign.center,
                      style: ShopType.hero(context).copyWith(fontFamily: ShopType.serif, fontSize: 34, letterSpacing: -0.5),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    child: Text(
                      "Use the shop computer's owner login to see sales, stock, and money from anywhere.",
                      textAlign: TextAlign.center,
                      style: ShopType.subhead(context),
                    ),
                  ),
                  const SizedBox(height: Space.xxl),
                  AutofillGroup(
                    child: _Fields(
                      email: _email,
                      password: _password,
                      passwordFocus: _passwordFocus,
                      askPassword: _askPassword,
                      enabled: !busy,
                      onEmailDone: _continue,
                      onPasswordDone: _signIn,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: Motion.medium,
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            key: ValueKey(_error),
                            padding: const EdgeInsets.fromLTRB(Space.xs, Space.md, Space.xs, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.exclamationmark_circle_fill, size: 16, color: colors.danger),
                                const SizedBox(width: Space.sm),
                                Flexible(
                                  child: Text(_error!, style: ShopType.footnote(context).copyWith(color: colors.danger)),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: Space.sm),
                  Center(
                    child: CupertinoButton(
                      onPressed: _forgotPassword,
                      child: Text('Forgot password?', style: ShopType.subhead(context).copyWith(color: colors.accent)),
                    ),
                  ),
                ],
              ),
            ),
            // The one action, a capsule in reach of the thumb; it rides up
            // with the keyboard.
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.sm, Space.gutter, Space.lg),
              child: CupertinoButton.filled(
                sizeStyle: CupertinoButtonSize.large,
                borderRadius: BorderRadius.circular(Radii.pill),
                onPressed: busy || !_ready ? null : (_askPassword ? _signIn : _continue),
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: busy
                      ? Row(
                          key: const ValueKey('busy'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CupertinoActivityIndicator(color: CupertinoTheme.of(context).primaryContrastingColor),
                            const SizedBox(width: Space.sm),
                            const Text('Signing In…', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        )
                      : Text(
                          _askPassword ? 'Sign In' : 'Continue',
                          key: ValueKey(_askPassword),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The email, and once it's in, the password beneath it: one rounded
/// group, as iOS lists its fields. The password field is always there for
/// Password AutoFill to fill, just folded away until it's asked for.
class _Fields extends StatelessWidget {
  const _Fields({
    required this.email,
    required this.password,
    required this.passwordFocus,
    required this.askPassword,
    required this.enabled,
    required this.onEmailDone,
    required this.onPasswordDone,
  });

  final TextEditingController email;
  final TextEditingController password;
  final FocusNode passwordFocus;
  final bool askPassword;
  final bool enabled;
  final VoidCallback onEmailDone;
  final VoidCallback onPasswordDone;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.group),
      child: ColoredBox(
        color: colors.card,
        child: AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              _Field(
                controller: email,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                textInputAction: askPassword ? TextInputAction.next : TextInputAction.go,
                enabled: enabled,
                onSubmitted: askPassword ? passwordFocus.requestFocus : onEmailDone,
              ),
              Visibility(
                visible: askPassword,
                maintainState: true,
                child: Column(
                  children: [
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.only(left: Space.lg),
                      color: colors.hairline,
                    ),
                    _Field(
                      controller: password,
                      focusNode: passwordFocus,
                      placeholder: 'Password',
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.go,
                      enabled: enabled,
                      onSubmitted: onPasswordDone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One borderless row of the group.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.placeholder,
    required this.autofillHints,
    required this.textInputAction,
    required this.enabled,
    required this.onSubmitted,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String placeholder;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final bool enabled;
  final VoidCallback onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => CupertinoTextField(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        placeholderStyle: ShopType.body(context).copyWith(color: ShopColors.of(context).tertiaryInk),
        style: ShopType.body(context),
        decoration: null,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 15),
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: false,
        enableSuggestions: !obscureText,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        enabled: enabled,
        clearButtonMode: obscureText ? OverlayVisibilityMode.never : OverlayVisibilityMode.editing,
        onSubmitted: (_) => onSubmitted(),
      );
}
