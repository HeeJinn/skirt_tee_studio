// PowerSync's attachment queue is marked experimental; it's pinned by
// pubspec.lock, so an API change shows up as a compile error on upgrade.
// ignore_for_file: experimental_member_use

import 'package:powersync/attachments/attachments.dart';
import 'package:powersync/powersync.dart';

/// The app's local tables. PowerSync adds the text `id` column to every
/// table itself, and exposes each one as a view — so there are no foreign
/// keys, AUTOINCREMENT, or NOT NULL here; integrity comes from the code that
/// writes inside transactions, as before.
///
/// Synced tables mirror the Supabase schema (snake_case there, aliased back
/// to these camelCase names by supabase/powersync/sync-rules.yaml). Changing
/// a synced table means changing the migration and sync rules too.
final appSchema = Schema([
  Table('items', [
    Column.text('name'),
    Column.text('category'),
    Column.real('unitPrice'),
    Column.integer('qtyOnHand'),
    // "On sale" (named from when it was a Bargain tag), and the discount:
    // a percent off or a set price.
    Column.integer('isBargain'),
    Column.real('salePercent'),
    Column.real('salePrice'),
    // File name in the item images folder (and the cloud bucket), not a
    // path: the path differs on every PC.
    Column.text('imageKey'),
    Column.real('unitCost'),
  ]),
  Table('sales', [
    Column.text('dateTime'),
    Column.text('paymentMethod'),
    Column.real('amountTendered'),
  ]),
  Table('sale_line_items', [
    Column.text('saleId'),
    Column.text('itemId'),
    Column.text('itemName'),
    Column.real('unitPrice'),
    Column.integer('qty'),
    Column.real('unitCost'),
  ], indexes: [
    Index('by_sale', [IndexedColumn('saleId')]),
  ]),
  Table('reservations', [
    Column.text('customerName'),
    Column.text('contact'),
    Column.text('itemId'),
    Column.text('itemName'),
    Column.text('pickupDate'),
    Column.text('status'),
  ]),
  // Shop-wide settings, keyed by name: lowStockThreshold, booksStartedAt.
  Table('shop_settings', [Column.text('value')]),
  Table('money_entries', [
    Column.text('at'),
    Column.text('kind'),
    Column.real('amount'),
    Column.text('category'),
    Column.text('paidFrom'),
    Column.text('person'),
    Column.text('note'),
  ]),
  Table('stock_lots', [
    Column.text('at'),
    Column.text('supplier'),
    Column.real('itemsCost'),
    Column.real('fees'),
    Column.text('paidFrom'),
    Column.text('person'),
    Column.text('note'),
  ]),
  Table('stock_movements', [
    Column.text('at'),
    Column.text('itemId'),
    Column.text('itemName'),
    Column.text('type'),
    Column.integer('qty'),
    Column.real('unitCost'),
    Column.text('reason'),
    Column.text('lotId'),
    Column.text('note'),
  ]),
  Table('audit_log', [
    Column.text('at'),
    Column.text('staffName'),
    Column.text('action'),
  ]),

  // Never uploaded. PIN hashes stay on the PC: a 4–6 digit PIN is
  // brute-forceable from any copy of its hash.
  Table.localOnly('staff', [
    Column.text('name'),
    Column.text('role'),
    Column.text('pinHash'),
    Column.text('salt'),
  ]),
  // Per-PC preferences, keyed by name: themePreset, appearanceMode.
  Table.localOnly('device_settings', [Column.text('value')]),
  // Which item photos still need uploading or downloading (ItemPhotoSync).
  AttachmentsQueueTable(),
]);
