# The Skirt & Tee Studio — POS + Inventory

A desktop point-of-sale and inventory app for **The Skirt & Tee Studio**, a small clothing boutique. It runs offline on a single shop computer, stores everything in a local SQLite database, and is built with Flutter.

![POS screen](docs/screenshots/pos.png)

## Features

- **POS**: search and filter items by category, build a sale, and take payment by cash, GCash, Maya, or card. Cash payments work out the change.
- **Inventory**: items with photos, prices, stock counts, and a configurable low-stock warning. **Receive stock** records a bulk purchase lot and splits its cost (including shipping) across the pieces. **Adjust stock** records damaged, lost, or found pieces.
- **Reservations**: log orders that come in through Facebook or chat, then mark them picked up to turn them into a real sale.
- **Sales history**: every transaction with its line items, plus voiding a sale to restore stock.
- **Reports**: revenue trend, top sellers, and revenue by category for the last 7 days, 30 days, or all time.
- **Money** (owners only): money put in, expenses, money taken home, profit breakdown, and how much of the investment has been paid back.
- **Customers**: repeat customers grouped from reservation history, with their pickup rate.
- **Staff and roles**: PIN sign-in with owner and cashier roles, a lock button, and an activity log of every sale, void, and stock or price change.
- **Settings**: six color themes and a System / Light / Dark switch.
- **Backup and export**: one-click database backup, plus CSV export of inventory and sales.

## Themes

Pick a theme in **Settings** and it applies right away. Each theme has its own light and dark palette, and every text and button color meets WCAG contrast.

| Theme | Look |
|---|---|
| Studio Sage (default) | Black ink on pale sage, the shop's logo colors |
| Blush Atelier | Rosy chrome with a raspberry accent |
| Terracotta Sand | Sand and clay with a teal SALE marker |
| Slate & Cobalt | Cool slate neutrals and a crisp cobalt |
| Lavender Calm | Soft lilac with a deep violet |
| Editorial Mono | Greyscale with one red for sales |

![Settings screen](docs/screenshots/settings.png)

| Slate & Cobalt, light | Lavender Calm, dark |
|---|---|
| ![Inventory in Slate & Cobalt](docs/screenshots/inventory.png) | ![POS in Lavender Calm dark](docs/screenshots/pos_dark.png) |

## Getting started

**You need:** the [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart 3.13 or newer), plus Visual Studio with the "Desktop development with C++" workload for Windows builds.

```bash
flutter pub get
flutter run -d windows
```

**First sign-in:** on first launch, the app asks you to set up the owner account with a PIN. After that, the owner can add cashiers from the **Staff** screen.

**Where your data lives:** the database is a local SQLite file on the shop computer. Use **Back up data** in the sidebar to save a copy somewhere safe.

## Development

```bash
flutter test          # unit and widget tests
flutter analyze       # lints
flutter build windows # release build
```

To review UI changes as images, `flutter test tool/ui_snapshots_test.dart` renders every screen in light and dark to `build/ui_snapshots/`. It's Windows-only, since it reads the real Windows fonts.

### Project structure

The app uses MVVM with `provider`, in three layers:

```
lib/
  core/           theme (colors, presets, type scale), routing, DI, utilities
  domain/         entities and repository interfaces (pure Dart)
  data/           SQLite data sources and repository implementations
  presentation/   screens, view models, and shared widgets
```

Architecture, database, and sequence diagrams are in [`docs/diagrams`](docs/diagrams). The roadmap and what's planned next are in [`ROADMAP.md`](ROADMAP.md).

## Tech

Flutter (desktop) · `provider` · `sqflite_common_ffi` · `fl_chart` · `file_selector` · `window_manager` · `lottie`
