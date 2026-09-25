---
name: modern-ui-ux
description: Use when designing, building, or reviewing Flutter UI/UX — screens, widgets, themes, layouts, color, typography, spacing, motion — to avoid the generic "AI-generated" look (centered hero stacks, purple/blue gradients, uniform rounded cards, unstyled default Material widgets) and produce distinctive, modern, intentional design instead. Apply this before writing widget code for a new screen, when restyling an existing one, when picking a ColorScheme/TextTheme, or when asked to make something "look better," "more modern," or "less AI."
---

# Modern, non-generic Flutter UI/UX

Generic AI-generated UI has a recognizable signature. The goal here is to never produce that signature: every screen should look like it came from a specific design decision, not from accepting Material's defaults.

## The tell-tale signs to avoid

If a screen has three or more of these, redo it:

- Centered column: icon → headline → subtext → full-width rounded button, repeated on every screen
- Indigo/violet-to-blue gradient background, or a gradient on every button and card
- Every corner at the same large radius (16–24px) with no variation — "bubble UI"
- Heavy, uniform drop shadows on every card (`elevation: 4` everywhere)
- Default `ElevatedButton`/`Card`/`AppBar` styling untouched from Material defaults
- Equal-width card grid where every card has icon-on-top, title, one line of body text
- One font (usually the platform default or Inter/Roboto) at only 2–3 sizes for the whole app
- Emoji used as icons instead of a real icon set
- Excessive, decorative whitespace with no real content density anywhere
- Glassmorphism/blur applied because it's trendy, not because it clarifies layering

None of these are wrong in isolation. The problem is applying all of them by default with no decision behind them.

## Principles to apply instead

**1. Commit to a real type system, not two font sizes.**
Define a full `TextTheme` (display, headline, title, body, label — each with a purpose) using a custom `ThemeData(textTheme: ...)`. Pick one distinctive font for headlines (via `google_fonts` or a bundled font) and pair it with a plain, highly legible font for body text. Don't use the same font/weight for a hero headline and a button label.

**2. Build a constrained, intentional color system.**
Derive the app's `ColorScheme` from one or two brand colors (`ColorScheme.fromSeed` as a *starting point*, then hand-tune it) rather than a default seed or a random gradient. Use color with purpose: one accent for primary actions, neutral tones for structure, and reserve saturated color for the one thing that should draw the eye. Avoid rainbow gradients unless the brand specifically calls for them.

**3. Use an 4pt/8pt spacing scale, and vary density.**
Define spacing constants (4, 8, 12, 16, 24, 32, 48...) and use them consistently — but don't pad everything equally. Group related elements tightly, separate unrelated groups generously. Uniform padding everywhere is a generic-UI tell.

**4. Break symmetry deliberately.**
Not every screen needs a centered column. Use asymmetric layouts, off-center focal points, overlapping elements, full-bleed imagery, or content that runs edge-to-edge. Centering is a default, not a design choice — use it only when it's actually the best layout for that content.

**5. Give components a distinct shape language.**
Pick radii and shapes on purpose (e.g., sharp corners for structural containers, one soft radius reserved for interactive surfaces) instead of one global `BorderRadius.circular(16)` everywhere. Customize `ButtonStyle`, `CardTheme`, `AppBarTheme`, `InputDecorationTheme` explicitly in `ThemeData` — never ship unstyled default Material widgets in a production screen.

**6. Use elevation/shadow sparingly and with a reason.**
Prefer subtle borders, tonal color shifts, or minimal shadow for separating surfaces. Reserve stronger elevation for things that are actually floating above content (FAB, modal sheet, dialog).

**7. Add micro-motion, not just page transitions.**
Small, fast (~150–250ms) `AnimatedContainer`/`AnimatedSwitcher`/implicit animations on state changes (press, select, load) make an app feel crafted. Avoid motion that's just decorative bounce with no functional purpose.

**8. Real icons, real imagery.**
Use a proper icon set (`Icons`, `phosphor_flutter`, custom SVGs) sized and weighted consistently. Avoid emoji as UI icons. If using imagery/illustration, keep a consistent style — don't mix stock-photo realism with flat illustration.

**9. Respect platform and content density.**
Don't force every list into a card grid. Dense information (lists, tables, forms) should look dense and scannable; marketing/onboarding content can breathe more. Match layout to what the content actually is.

**10. Dark mode is a second design, not an inverted one.**
Define dark `ColorScheme` deliberately (don't just flip light colors) — check contrast and that accent colors still read well on dark surfaces.

## Practical Flutter checklist

Before considering a screen done, check:

- [ ] `ThemeData` (or `ThemeExtension`) defines the palette, type scale, and spacing — the screen doesn't invent one-off colors/sizes inline
- [ ] No default-styled `ElevatedButton`, `Card`, `AppBar`, or `TextField` — each has an explicit style from the theme
- [ ] Not every corner uses the same radius; not every surface has the same shadow
- [ ] At least one layout decision breaks strict centering/symmetry where the content justifies it
- [ ] Spacing follows a defined scale, and density varies with content relationship (tight vs. loose grouping)
- [ ] Any gradient, blur, or shadow used is there for a specific reason you could explain, not as decoration
- [ ] Icons come from a real icon set, sized/weighted consistently — no emoji-as-icon
- [ ] Interactive elements have a motion/feedback state (press, loading, selected), not just a static appearance
- [ ] Dark theme was checked, not just auto-derived

## When reviewing existing UI

Walk through the tell-tale-signs list first. Call out specifically which signs are present (e.g., "this uses the centered-icon-headline-button pattern on 4 of 5 screens, and every card shares one 20px radius with a uniform elevation-2 shadow"), then propose concrete theme/layout changes — not just "make it more modern."
