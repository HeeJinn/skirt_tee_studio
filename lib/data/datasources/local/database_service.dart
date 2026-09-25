import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens (and creates, on first run) the app's local SQLite database.
/// Desktop-only (sqflite_common_ffi) — matches the MVP's single-machine,
/// single-user scope.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  /// Bump alongside a new branch in [upgradeSchema].
  static const schemaVersion = 7;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  /// Writes a complete, transactionally-consistent snapshot to
  /// [destinationPath] via SQLite's own `VACUUM INTO` — safer than copying
  /// the live file, which risks capturing a half-written page. `VACUUM INTO`
  /// refuses to overwrite an existing file, so a prior file at the
  /// destination (the user picked an existing name to overwrite) is removed
  /// first.
  Future<void> backupTo(String destinationPath) async {
    final destination = File(destinationPath);
    if (await destination.exists()) {
      await destination.delete();
    }
    final db = await database;
    await db.execute('VACUUM INTO ?', [destinationPath]);
  }

  Future<Database> _open() async {
    sqfliteFfiInit();
    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'skirt_tee_studio.db');
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) => upgradeSchema(db, oldVersion),
      ),
    );
  }

  /// Schema creation, shared with tests so they exercise the exact same
  /// table definitions against an in-memory database.
  static Future<void> createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        qtyOnHand INTEGER NOT NULL,
        isBargain INTEGER NOT NULL DEFAULT 0,
        imagePath TEXT,
        unitCost REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        dateTime TEXT NOT NULL,
        paymentMethod TEXT,
        amountTendered REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE sale_line_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        saleId TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        unitPrice REAL NOT NULL,
        qty INTEGER NOT NULL,
        unitCost REAL,
        FOREIGN KEY (saleId) REFERENCES sales (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE reservations (
        id TEXT PRIMARY KEY,
        customerName TEXT NOT NULL,
        contact TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        pickupDate TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await _createStaffTables(db);
    await _createMoneyTables(db);
  }

  /// Settings key for when the money books start. Sales before it carry no
  /// cost and the money behind them was never recorded, so profit and
  /// payback count from here — "start from zero", per the owners.
  static const booksStartedAtKey = 'booksStartedAt';

  /// Everything the owners' profit and payback figures are built from,
  /// besides sales themselves.
  static Future<void> _createMoneyTables(DatabaseExecutor db) async {
    await db.insert(
      'settings',
      {'key': booksStartedAtKey, 'value': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS money_entries (
        id TEXT PRIMARY KEY,
        at TEXT NOT NULL,
        kind TEXT NOT NULL,
        amount REAL NOT NULL,
        category TEXT,
        paidFrom TEXT NOT NULL,
        person TEXT,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_lots (
        id TEXT PRIMARY KEY,
        at TEXT NOT NULL,
        supplier TEXT NOT NULL,
        itemsCost REAL NOT NULL,
        fees REAL NOT NULL DEFAULT 0,
        paidFrom TEXT NOT NULL,
        person TEXT,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
    // itemName is a snapshot, not a foreign key, for the same reason as the
    // audit log: losses must stay on the books after an item is deleted.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        type TEXT NOT NULL,
        qty INTEGER NOT NULL,
        unitCost REAL NOT NULL,
        reason TEXT,
        lotId TEXT,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  static Future<void> _createStaffTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS staff (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        pinHash TEXT NOT NULL,
        salt TEXT NOT NULL
      )
    ''');
    // staffName is a snapshot, not a foreign key: the trail must survive a
    // staff member being removed.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at TEXT NOT NULL,
        staffName TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');
  }

  /// Applies schema changes for installs created before the current
  /// version. Each branch is additive and re-runnable (`IF NOT EXISTS`) so
  /// upgrading across several versions at once is safe.
  static Future<void> upgradeSchema(DatabaseExecutor db, int oldVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE items ADD COLUMN imagePath TEXT');
    }
    if (oldVersion < 4) {
      await _createStaffTables(db);
    }
    if (oldVersion < 5) {
      // Nullable on purpose: earlier sales' method is genuinely unknown.
      await db.execute('ALTER TABLE sales ADD COLUMN paymentMethod TEXT');
    }
    if (oldVersion < 6) {
      // Nullable: only cash sales from now on carry an amount tendered.
      await db.execute('ALTER TABLE sales ADD COLUMN amountTendered REAL');
    }
    if (oldVersion < 7) {
      // Nullable: existing stock and past sales have no recorded cost, and
      // aren't back-filled with a guess — the books start from zero.
      await db.execute('ALTER TABLE items ADD COLUMN unitCost REAL');
      await db.execute('ALTER TABLE sale_line_items ADD COLUMN unitCost REAL');
      await _createMoneyTables(db);
    }
  }
}
