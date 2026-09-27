import 'package:flutter/cupertino.dart';

import '../../../core/period.dart';
import '../../../core/theme/shop_ui.dart';
import 'section.dart';
import 'segmented_control.dart';

/// Picks the period a screen shows: a switch between the kinds on offer
/// (all, a month, a day), and for a month or day, a stepper to go back and
/// forth one at a time. Tapping the date opens a wheel to jump straight to
/// any month or day.
class PeriodBar extends StatelessWidget {
  const PeriodBar({
    super.key,
    required this.period,
    required this.now,
    required this.onChanged,
    this.kinds = const [PeriodKind.all, PeriodKind.month, PeriodKind.day],
    this.allLabel = 'All',
    this.earliest,
  });

  final Period period;
  final DateTime now;
  final ValueChanged<Period> onChanged;
  final List<PeriodKind> kinds;

  /// What the all-time choice is called ("Since start" on Money).
  final String allLabel;

  /// The oldest record, so the stepper doesn't walk back into empty
  /// months. Null leaves it unbounded.
  final DateTime? earliest;

  bool get _canGoBack => earliest == null || earliest!.isBefore(period.start!);
  bool get _canGoForward => !period.end!.isAfter(now);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kinds.length > 1)
          ShopSegmentedControl<PeriodKind>(
            value: period.kind,
            onChanged: (kind) => onChanged(period.asKind(kind, now)),
            segments: {
              for (final kind in kinds)
                kind: switch (kind) {
                  PeriodKind.all => allLabel,
                  PeriodKind.month => 'Month',
                  PeriodKind.day => 'Day',
                },
            },
          ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: period.kind == PeriodKind.all
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: EdgeInsets.only(top: kinds.length > 1 ? Space.md : 0),
                  child: _Stepper(
                    label: period.label(now),
                    pickLabel: period.kind == PeriodKind.month ? 'Pick a month' : 'Pick a day',
                    onBack: _canGoBack ? () => onChanged(period.shift(-1)) : null,
                    onForward: _canGoForward ? () => onChanged(period.shift(1)) : null,
                    onPick: () => _pick(context),
                  ),
                ),
        ),
      ],
    );
  }

  /// A wheel of months or days, from the oldest record up to today. The
  /// screen follows the wheel as it turns.
  Future<void> _pick(BuildContext context) {
    final byMonth = period.kind == PeriodKind.month;
    final max = now;
    final floor = earliest == null ? null : (byMonth ? Period.month(earliest!) : Period.day(earliest!)).start!;
    final min = floor != null && !floor.isAfter(max) ? floor : null;
    var initial = period.start!;
    if (initial.isAfter(max)) initial = Period.current(period.kind, now).start!;
    if (min != null && initial.isBefore(min)) initial = min;

    // An iOS 26 partial sheet: it floats clear of the screen's edges with
    // every corner rounded, no rule under its header, and Done as the one
    // prominent action.
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        final colors = ShopColors.of(sheetContext);
        final bottom = MediaQuery.paddingOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(Space.sm, 0, Space.sm, bottom > 0 ? bottom : Space.sm),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: colors.card, borderRadius: BorderRadius.circular(Radii.sheet)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xs, Space.md, Space.lg, 0),
                  child: Row(
                    children: [
                      CupertinoButton(
                        onPressed: () {
                          onChanged(Period.current(period.kind, now));
                          Navigator.of(sheetContext).pop();
                        },
                        child: Text(byMonth ? 'This Month' : 'Today'),
                      ),
                      const Spacer(),
                      CupertinoButton.filled(
                        sizeStyle: CupertinoButtonSize.medium,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    mode: byMonth ? CupertinoDatePickerMode.monthYear : CupertinoDatePickerMode.date,
                    initialDateTime: initial,
                    minimumDate: min,
                    maximumDate: max,
                    onDateTimeChanged: (at) => onChanged(byMonth ? Period.month(at) : Period.day(at)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The date as a capsule button on the left (tap for the wheel), and round
/// earlier/later buttons on the right — iOS 26's capsules, left-aligned.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.pickLabel,
    required this.onBack,
    required this.onForward,
    required this.onPick,
  });

  final String label;
  final String pickLabel;
  final VoidCallback? onBack;
  final VoidCallback? onForward;
  final VoidCallback onPick;

  /// The height of the date capsule and the width of the round buttons.
  static const _size = 36.0;

  @override
  Widget build(BuildContext context) {
    final colors = ShopColors.of(context);
    // The same quiet fill as the segmented control's track: these are
    // controls on the page, not cards.
    final fill = colors.isDark ? const Color(0xFFFFFFFF).withValues(alpha: 0.09) : colors.ink.withValues(alpha: 0.06);
    final capsule = BorderRadius.circular(Radii.pill);

    Widget step(IconData icon, String semantics, VoidCallback? onTap) => Semantics(
          button: true,
          enabled: onTap != null,
          label: semantics,
          excludeSemantics: true,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(44),
            onPressed: onTap,
            child: AnimatedOpacity(
              duration: Motion.fast,
              opacity: onTap == null ? 0.35 : 1,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Icon(icon, size: 17, color: colors.ink),
              ),
            ),
          ),
        );

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: pickLabel,
              value: label,
              excludeSemantics: true,
              child: ClipRRect(
                borderRadius: capsule,
                child: Pressable(
                  onTap: onPick,
                  child: Container(
                    height: _size,
                    padding: const EdgeInsets.only(left: Space.md, right: Space.md - 2),
                    decoration: BoxDecoration(color: fill, borderRadius: capsule),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.calendar, size: 17, color: colors.accent),
                        const SizedBox(width: Space.sm),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ShopType.subhead(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.ink,
                              fontFeatures: ShopType.tabular,
                            ),
                          ),
                        ),
                        const SizedBox(width: Space.xs + 2),
                        Icon(CupertinoIcons.chevron_up_chevron_down, size: 13, color: colors.secondaryInk),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.sm),
        step(CupertinoIcons.chevron_left, 'Earlier', onBack),
        step(CupertinoIcons.chevron_right, 'Later', onForward),
      ],
    );
  }
}
