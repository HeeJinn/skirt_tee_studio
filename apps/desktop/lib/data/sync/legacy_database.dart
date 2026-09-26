import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:shop_core/data/datasources/local/database_service.dart';

/// The pre-cloud SQLite database (schema v7), kept only so an existing
/// shop's data can be read once and imported — see LegacyImport. Nothing
/// writes to it after that.
class LegacyDatabase {
  LegacyDatabase._();

  static const fileName = 'skirt_tee_studio.db';

  /// The last version before the cloud move.
  static const schemaVersion = 7;

  static bool _ffiInitialized = false;

  /// Opens an existing file, bringing an older install up to v7 first so the
  /// import only has to understand one shape.
  static Future<Database> open(String path) {
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      _ffiInitialized = true;
    }
    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) => upgradeSchema(db, oldVersion),
        singleInstance: false,
      ),
    );
  }

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

  static Future<void> _createMoneyTables(DatabaseExecutor db) async {
    await db.insert(
      'settings',
      {'key': DatabaseService.booksStartedAtKey, 'value': DateTime.now().toIso8601String()},
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        at TEXT NOT NULL,
        staffName TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');
  }

  /// Applies schema changes for installs created before v7. Each branch is
  /// additive and re-runnable (`IF NOT EXISTS`) so upgrading across several
  /// versions at once is safe.
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
