# The Skirt & Tee Studio — POS + Inventory

A desktop point-of-sale and inventory app for **The Skirt & Tee Studio**, a small clothing boutique. It runs on the shop computer and keeps working offline. Once an owner connects it, it also backs everything up to the cloud (Supabase). It's built with Flutter.

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
- **Cloud backup** (owners only): connect the shop computer to the cloud in **Settings**. Every sale, stock change, money entry, and item photo is copied up whenever the internet is on. If the computer breaks, sign in on a new one and everything comes back.
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

The repo is a Dart workspace: the desktop app lives in `apps/desktop`, and the code it will share with the planned owner mobile app lives in `packages/shop_core`. One `flutter pub get` at the root sets up both.

```bash
flutter pub get
cd apps/desktop
flutter run -d windows
```

**First sign-in:** on first launch, the app asks you to set up the owner account with a PIN. After that, the owner can add cashiers from the **Staff** screen.

**Where your data lives:** on the shop computer, in a local database that works without internet. If an owner has connected **Cloud backup**, it's copied to Supabase too. **Back up data** in the sidebar still saves a local copy.

### Cloud backup setup

Cloud backup needs a Supabase project and a PowerSync instance. A build without them runs offline-only, exactly as before.

1. **Supabase:** apply the schema with the Supabase CLI (installed per-project: `npm install`), then create each owner's login under **Authentication → Users**:

   ```bash
   npx supabase login
   npx supabase link --project-ref <project-ref>
   npx supabase db push
   ```

   `npx supabase db query --linked -f supabase/tests/smoke_test.sql` checks the live schema and rolls itself back. It should end with `SMOKE TEST PASSED`.
2. **PowerSync:** create an instance connected to the Supabase database, turn on Supabase Auth, and deploy [`supabase/powersync/sync-rules.yaml`](supabase/powersync/sync-rules.yaml) as its sync rules.
3. **App config:** at the repo root, copy `cloud.example.json` to `cloud.json` and fill in the Supabase URL, the **publishable** key, and the PowerSync URL. `cloud.json` is gitignored. Never put the Supabase *secret* key in it: the app ships to the shop computer, and the secret key bypasses every access rule.

   ```bash
   cd apps/desktop
   flutter run -d windows --dart-define-from-file=../../cloud.json
   ```

**First run after updating:** the app copies the old local database into the new one once. The original file stays untouched, and a copy is saved next to it as `skirt_tee_studio.pre-cloud.db`.

**Restoring on a new computer:** install the app, set up the owner PIN (staff PINs never leave the computer they were made on), then **Settings → Connect to cloud** with the owner login. Everything downloads, photos included.

## Development

Run these inside `packages/shop_core` or `apps/desktop`; each has its own tests:

```bash
flutter test          # unit and widget tests
flutter analyze       # lints
flutter build windows # release build (apps/desktop only)
```

To review UI changes as images, run `flutter test tool/ui_snapshots_test.dart` in `apps/desktop`. It renders every screen in light and dark to `build/ui_snapshots/`. It's Windows-only, since it reads the real Windows fonts.

### Project structure

```
apps/desktop/         the Windows POS app (MVVM with `provider`)
  lib/core/           routing, DI, utilities
  lib/data/sync/      one-time import of the pre-cloud database
  lib/presentation/   screens, view models, and widgets
packages/shop_core/   shared by the desktop app and the planned mobile app
  lib/domain/         entities and repository interfaces
  lib/data/           local database, repositories, and cloud sync (data/sync)
  lib/calculations/   profit, payback, reports, and customer/sales grouping
  lib/core/           cloud config and the theme presets
supabase/             database migrations, PowerSync sync config, smoke test
```

Architecture, database, and sequence diagrams are in [`docs/diagrams`](docs/diagrams). The roadmap and what's planned next are in [`ROADMAP.md`](ROADMAP.md).

## Tech

Flutter (desktop) · `provider` · PowerSync (`powersync`, `sqlite_async`) · Supabase (`supabase_flutter`) · `fl_chart` · `file_selector` · `window_manager` · `lottie`
