import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shop_core/core/theme/app_theme.dart';
import 'package:shop_core/domain/entities/appearance.dart';
import '../../viewmodels/session_view_model.dart';
import '../../viewmodels/settings_view_model.dart';
import '../../widgets/list_surface.dart';
import '../../widgets/screen_header.dart';
import 'widgets/cloud_sync_panel.dart';

/// Appearance for this computer: light/dark mode and the color theme.
/// Changes apply the moment they're picked — there's no save step. Owners
/// also get the shop's cloud backup here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final isOwner = context.select<SessionViewModel, bool>((s) => s.isOwner);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            title: 'Settings',
            subtitle: '${settings.themePreset.name} · applies to everyone who signs in on this computer',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                if (isOwner) ...[
                  const SectionLabel('Your name'),
                  const Align(alignment: Alignment.centerLeft, child: _OwnerNamePanel()),
                  const SizedBox(height: AppSpacing.md),
                  const SectionLabel('Cloud backup'),
                  const Align(alignment: Alignment.centerLeft, child: CloudSyncPanel()),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SectionLabel('Mode'),
                _ModeToggle(
                  selected: settings.appearanceMode,
                  onSelected: settings.selectAppearanceMode,
                ),
                const SizedBox(height: AppSpacing.md),
                const SectionLabel('Theme'),
                Wrap(
                  spacing: AppSpacing.lg,
                  runSpacing: AppSpacing.lg,
                  children: [
                    for (final preset in ThemePresets.all)
                      _PresetCard(
                        preset: preset,
                        selected: preset.id == settings.themePreset.id,
                        onTap: () => settings.selectThemePreset(preset),
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

/// The signed-in owner's name — what the sign-in screen, the activity log
/// and the "who paid" choices in Money and Inventory show.
class _OwnerNamePanel extends StatelessWidget {
  const _OwnerNamePanel();

  @override
  Widget build(BuildContext context) {
    final name = context.select<SessionViewModel, String>((s) => s.current?.name ?? '');
    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.container),
        border: Border.all(color: context.tokens.hairline),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 22, color: context.tokens.mutedText),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(name, style: context.text.titleMedium, overflow: TextOverflow.ellipsis)),
          TextButton(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const _RenameDialog()),
            child: const Text('CHANGE'),
          ),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog();

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: context.read<SessionViewModel>().current?.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<SessionViewModel>().renameSelf(_name.text);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionViewModel>();
    return AlertDialog(
      title: const Text('CHANGE YOUR NAME'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => session.checkName(session.current!, v ?? ''),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Money and stock you\'ve recorded move to the new name. Past activity log lines keep the old one.',
                style: context.text.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL')),
        ElevatedButton(onPressed: _submit, child: const Text('SAVE')),
      ],
    );
  }
}

/// Three-way System / Light / Dark switch — one connected control rather
/// than three loose chips, since exactly one is always on.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.selected, required this.onSelected});

  final AppearanceMode selected;
  final ValueChanged<AppearanceMode> onSelected;

  static const _options = [
    (AppearanceMode.system, 'System', Icons.brightness_auto_outlined),
    (AppearanceMode.light, 'Light', Icons.light_mode_outlined),
    (AppearanceMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: tokens.sunken,
          borderRadius: BorderRadius.circular(AppRadius.control + 2),
          border: Border.all(color: tokens.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (mode, label, icon) in _options)
              _ModeSegment(
                label: label,
                icon: icon,
                selected: mode == selected,
                onTap: () => onSelected(mode),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.onPrimary : context.tokens.mutedText;
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? context.colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: context.text.labelLarge?.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A theme option shown as a miniature of the app itself, painted in that
/// preset's colors for the current light/dark mode — so the choice is made
/// by seeing it, not by reading a color name.
class _PresetCard extends StatefulWidget {
  const _PresetCard({required this.preset, required this.selected, required this.onTap});

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  static const width = 272.0;

  @override
  State<_PresetCard> createState() => _PresetCardState();
}

class _PresetCardState extends State<_PresetCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? widget.preset.dark : widget.preset.light;
    final tokens = context.tokens;

    final borderColor = widget.selected
        ? context.colors.primary
        : _hovered
            ? context.colors.outline
            : tokens.hairline;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.preset.name} theme',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: _PresetCard.width,
            // The border swaps width on selection; padding shrinks to match
            // so the card never shifts its contents.
            padding: EdgeInsets.all(widget.selected ? 5 : 6),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.container),
              border: Border.all(color: borderColor, width: widget.selected ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniApp(palette: palette),
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, AppSpacing.md, 6, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(widget.preset.name, style: context.text.titleMedium)),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: widget.selected
                                ? Icon(Icons.check_circle, key: const ValueKey(true), size: 18, color: context.colors.primary)
                                : const SizedBox(key: ValueKey(false), width: 18, height: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(widget.preset.blurb, style: context.text.bodySmall, maxLines: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar, a header, a two-series chart, a SALE tag and a primary button —
/// the handful of surfaces where a theme actually shows.
class _MiniApp extends StatelessWidget {
  const _MiniApp({required this.palette});
  final ThemePalette palette;

  @override
  Widget build(BuildContext context) {
    final t = palette.tokens;

    Widget bar(double width, Color color, {double height = 4}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.container - 4),
      child: SizedBox(
        height: 132,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sidebar
            Container(
              width: 66,
              color: palette.mist,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(34, palette.ink, height: 5),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: palette.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(children: [bar(6, palette.brand), const SizedBox(width: 4), bar(24, palette.ink)]),
                  ),
                  for (final w in const [28.0, 20.0, 30.0])
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 7, 0, 0),
                      child: Row(children: [bar(6, t.mutedText), const SizedBox(width: 4), bar(w, t.mutedText)]),
                    ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                color: palette.bg,
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        bar(54, palette.ink, height: 6),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            border: Border.all(color: t.accent),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'SALE',
                            style: TextStyle(
                              fontFamily: kSansFont,
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: t.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    bar(80, t.mutedText, height: 3),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                        decoration: BoxDecoration(
                          color: t.sunken,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: t.hairline),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (final (sales, costs) in const [(0.55, 0.35), (0.8, 0.4), (0.45, 0.3), (0.95, 0.5), (0.7, 0.38)])
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _ChartBar(fraction: sales, color: t.chartSales),
                                    const SizedBox(width: 1.5),
                                    _ChartBar(fraction: costs, color: t.chartCosts),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 12,
                          decoration: BoxDecoration(
                            border: Border.all(color: palette.outline),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 56,
                          height: 14,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.brand,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: bar(26, palette.onBrand, height: 3),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({required this.fraction, required this.color});
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: fraction,
      child: Container(
        width: 5,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(1.5)),
        ),
      ),
    );
  }
}
