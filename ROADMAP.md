# Roadmap — The Skirt & Tee Studio

POS + Inventory system for The Skirt & Tee Studio. Flutter desktop app, local-first storage (PowerSync SQLite) with Supabase cloud backup, MVVM (`provider`).

## Current state

Six-screen shell (`AppShell`): POS, Inventory, Reservations, Sales, Reports, Customers — all backed by local SQLite.

- **POS** — search/filter items by category, tap to add to cart, adjust quantities, complete sale (writes a `Sale` record and deducts stock from inventory). Item photo shown on each tile.
- **Inventory** — table view of all items with search/filter, add/edit/delete via dialog (including a photo per item), low-stock flag against a configurable store-wide threshold (⚙ icon next to "ADD ITEM", defaults to ≤5).
- **Reservations** — manually logged FB/chat orders (customer, contact, item, pickup date), filterable by Pending/Picked Up. Fully editable and cancellable; "Mark Picked Up" completes it as a real sale (deducts stock, records a `Sale`, re-checking live availability first).
- **Sales** — history of past transactions (revenue/items/transaction-count stat row, expandable line items), with void-sale to restore stock and correct a cashier mistake.
- **Reports** — revenue trend, top-selling items, and revenue-by-category charts (`fl_chart`), scoped by a shared 7-day/30-day/all-time filter.
- **Customers** — reservation history grouped by contact, so repeat customers and their pickup rate are visible at a glance.
- **Data export/backup** — CSV export of inventory and sales; one-click SQLite backup from the nav rail (⭳ icon at the bottom).

Phase 1 is done. Remaining known gaps, now tracked as their own future work:
- Reserving an item doesn't hold its stock aside — a walk-in sale at POS can still sell out an item someone already reserved; pickup then blocks with an "out of stock" error instead of silently overselling. Real fix is a "reserved" stock concept.
- Low-stock threshold is store-wide, not per item — fine for a small boutique's mixed inventory today, but a future ask if categories need very different cutoffs.
- Backup is manual (a deliberate click), not automatic/scheduled — still a single point of failure between backups.
- Customers are inferred from reservations only — a customer who only ever buys as a walk-in at POS won't show up, since POS sales don't collect a name/contact.

## Phase 1 — Close the loop (near-term) — ✅ done

These fixed places where the app already collected data but didn't do anything with it yet.

- [x] **Sales history screen** — list past sales, running totals (revenue, items sold, transaction count).
- [x] **Void a completed sale** — restores stock, for cashier mistakes.
- [x] **Reservation pickup → sale**: marking a reservation picked up deducts stock and records a `Sale`, not just a status flag.
- [x] **Edit/cancel reservations** — full edit dialog (name/contact/item/pickup date) and a cancel action, both from the reservation row.
- [x] **Configurable low-stock threshold** — store-wide setting (persisted in SQLite), editable from Inventory; replaces the hardcoded `≤ 5`.

## Phase 2 — Day-to-day usability (mid-term)

- [x] **Reports/analytics** — revenue trend, top sellers, and category breakdown (`fl_chart`), scoped by a 7/30/all-time filter.
- [x] **Item photos** — pick a photo per item (`file_selector`), copied into app-managed storage; thumbnail shown in the POS grid and Inventory table.
- [x] **Sales (was the "Bargain tier" tag).** An item can be put **On sale** at a percent off (rounded to the whole peso) or at a set sale price. POS, the cart, and reservation pickups charge the sale price. The regular price shows struck through, and the SALE tag shows how much is off. Items tagged Bargain before this keep their price and tag until an owner sets a discount. The cost of a lot is still split by the regular price. Needs migration `20260928000000_item_sales.sql` and the updated sync rules deployed before the desktop update. Not yet: putting a whole category on sale at once, or sale end dates.
- [ ] ~~Receipt output~~ — *not needed: the store doesn't issue receipts.*
- [ ] ~~Barcode/SKU support~~ — *skipped.*
- [x] **Data export/backup** — CSV export (inventory, sales) via `file_selector`; one-click database backup (SQLite `VACUUM INTO`, a consistent standalone snapshot) from the nav rail.

Phase 2 is done.

## Phase 3 — Scaling up (longer-term)

- [x] **Multi-user accounts with roles** — PIN sign-in (salted, hashed), owner/cashier roles (cashiers: POS, reservations, read-only inventory), Lock button, Staff screen with an activity log of every sale, void, stock/price edit, and reservation change. Not yet: PIN reset (remove + re-add for now), auto-lock on idle.
- [x] **Cloud sync** — the shop computer keeps a local PowerSync database and syncs it with Supabase once an owner connects in Settings. Selling works offline; changes upload when the internet is back, and a new computer restores everything by signing in. Item photos sync to Supabase Storage. Staff PINs and per-computer theme stay local. Not yet: removing replaced photos from the cloud, and a second owner joining the same shop from the app (added by hand in Supabase for now). Multi-device writes arrive with the mobile app (Phase 5).
- [ ] **Returns/refunds/exchange flow.**
- [x] **Customer records** — customers grouped by contact from reservation history (not a separate database); a "Customers" screen shows each one's reservation history and pickup rate. Doesn't cover anonymous POS walk-in sales, which carry no customer info at all.
- [ ] **Restocking/purchase-order workflow** from suppliers.
- [ ] **Tax/official-receipt handling** if required for compliance.

## Phase 4 — Money: profit & payback

The owners can't tell how much they've put into the shop versus how much it has earned back. The app records sales only, never the money going out, so reports show revenue, not profit. Decisions from the owners: joint capital (married couple), stock bought in mixed bulk lots, books start from zero (no past figures), owners' own pay recorded as "taken home" rather than an expense.

- [x] **A. Data foundation.** Each item gets an average cost per piece, and every sale saves the item's cost at the moment it sold. Tables for the money log (money put in, expenses, money taken home), stock lots, and stock movements. A lot's cost, including shipping, is split across its pieces by selling price. Voids put pieces back at the cost they sold at. Profit breakdown and payback calculations.
- [x] **B. Recording.** Inventory has a **Receive stock** button: enter the lot's price, fees, supplier, and who paid, then add the pieces (existing items or new ones), and it previews each item's cost and profit before saving. **Adjust stock** on each row records damaged, lost, given away, or short-count pieces as a loss at cost, or pieces found. The item form has a "Cost each" field (owners only; cashiers never see costs), and an existing item's stock count is read-only. Deleting an item with stock left records it as a loss. The money log entry dialog (money put in, expense, taken home) is built and gets wired up in C.
- [x] **C. Money screen (owners only).** A new "Money" item under Review. **Payback** (all figures since the books started): what the owners put in (split by owner), what the shop has earned, how much of the investment that recovers, what's been taken home, and stock on the rack at cost. **Profit** for 7 days / 30 days / since the books started: summary tiles and a profit breakdown (sales − cost of items sold = gross profit − each expense − stock losses = net profit), with a note when old stock with no recorded cost is making profit look high. **Sales vs costs** by month (last 6). **Money log**: every entry and stock purchase, filterable, with Put money in / Take home / Record expense buttons, and edit/delete (confirmed, and logged in Staff activity).
- [x] **C2. Owner feedback (Sep 28).** *Money in the shop*: a figure on both apps for the money the shop is holding, meaning cash and e-wallets. It's worked out as money put in + sales − expenses and stock paid with shop money − money taken home, with the cash part of sales shown separately. **Mixed bundles**: Receive stock has a quick-add line (category, name, price, pieces) so each kind in a bundle goes in on one line. A name that's already in inventory adds to that item. **Categories** are the owners' own synced list: add one from any category dropdown ("New category…"), or add and remove them from the ✎ button beside the Inventory filters. Categories an item still uses can't be removed. Not yet: renaming a category, and a cash count to reconcile "money left" against the drawer.
- [ ] **D. Later.** Slow-moving stock, margin by item/category, CSV export for an accountant, end-of-day drawer count.

The books start the day this update is installed (the date is saved once and shown on the Money screen); sales from before then don't count toward profit or payback. Stock on hand before tracking started has no recorded cost and counts as ₱0, since the money that bought it isn't counted either. Until that stock sells through, margins look higher than they really are. The profit report calls this out.

## Phase 5 — Owner mobile app (planned)

An iOS and Android app for the owners only, reading and writing the same Supabase data as the shop computer. Selling stays on the shop computer; there's no mobile POS.

- **Today:** today's sales and profit against the same weekday last week, a live sales feed, and a "needs attention" list (low stock, reservations due, voids, shop computer offline).
- **Sales:** history with a detail view, and voiding a sale.
- **Stock:** inventory with camera photos, adjust stock, and receive a stock lot (with a photo of the supplier's receipt).
- **Money:** payback, profit, sales vs costs, and the money log (with receipt photos on expenses).
- **More:** reservations, customers, reports (shared as an image or CSV), staff activity and PIN reset, and settings.
- **Notifications:** daily close summary, low stock, voids, reservations due, shop computer not syncing.

Before it can write data, stock-changing actions (sales, voids, receiving lots) need to move into server functions, so two devices can't both change the same item's stock at once. Today only the shop computer writes, so its own logic is safe.

---
*This file tracks planned work, not a contractual timeline — reprioritize freely as the store's needs change.*
