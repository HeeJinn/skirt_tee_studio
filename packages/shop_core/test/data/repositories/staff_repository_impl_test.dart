import 'package:flutter_test/flutter_test.dart';
import 'package:shop_core/data/datasources/local/sql_helpers.dart';
import 'package:shop_core/data/repositories/staff_repository_impl.dart';
import 'package:shop_core/domain/entities/staff.dart';

import '../../test_helpers.dart';

void main() {
  test('PIN is stored only as a salted hash and verifies correctly', () async {
    final db = await openTestDatabase();
    final repo = StaffRepositoryImpl(db);

    final a = await repo.add('Ana', StaffRole.cashier, '1234');
    final b = await repo.add('Bea', StaffRole.cashier, '1234');

    final rows = await db.query('staff');
    expect(rows.every((r) => r['pinHash'] != '1234'), isTrue);
    // Same PIN, different salts → different hashes.
    expect(rows[0]['pinHash'], isNot(rows[1]['pinHash']));

    expect(await repo.verifyPin(a.id, '1234'), isTrue);
    expect(await repo.verifyPin(a.id, '4321'), isFalse);
    expect(await repo.verifyPin('no-such-id', '1234'), isFalse);
    expect(await repo.verifyPin(b.id, '1234'), isTrue);
  });

  test('audit log returns newest first and survives removing the staff member', () async {
    final repo = StaffRepositoryImpl(await openTestDatabase());
    final ana = await repo.add('Ana', StaffRole.cashier, '1234');

    await repo.log('Ana', 'Sale ₱100.00');
    await repo.log('Ana', 'Signed out');
    await repo.delete(ana.id);

    final activity = await repo.recentActivity();
    expect(activity.map((e) => e.action), ['Signed out', 'Sale ₱100.00']);
    expect(activity.first.staffName, 'Ana');
  });
}
