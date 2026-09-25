import 'package:flutter_test/flutter_test.dart';
import 'package:skirt_tee_studio/domain/entities/staff.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/session_view_model.dart';

import '../../fakes/fake_staff_repository.dart';

void main() {
  test('first owner is created once and signed straight in', () async {
    final session = SessionViewModel(FakeStaffRepository());
    await session.load();

    await session.createFirstOwner('Olivia', '1234');
    await session.createFirstOwner('Intruder', '0000'); // ignored: staff exist

    expect(session.current?.name, 'Olivia');
    expect(session.isOwner, isTrue);
    expect(session.staff, hasLength(1));
  });

  test('wrong PIN does not sign in', () async {
    final repo = FakeStaffRepository();
    final ana = await repo.add('Ana', StaffRole.cashier, '1234');
    final session = SessionViewModel(repo);
    await session.load();

    expect(await session.signIn(ana, '9999'), isFalse);
    expect(session.current, isNull);
  });

  test('log records the signed-in person; nothing is logged when signed out', () async {
    final session = await signedInSession(role: StaffRole.cashier);

    await session.log('Sale ₱199.00');
    expect(session.activity.first.staffName, 'Carl Cashier');
    expect(session.activity.first.action, 'Sale ₱199.00');

    await session.signOut();
    final count = session.activity.length;
    await session.log('should not appear');
    expect(session.activity, hasLength(count));
  });

  test('cashiers cannot add staff; owners cannot remove themselves or the last owner', () async {
    final cashierSession = await signedInSession(role: StaffRole.cashier);
    await cashierSession.addStaff('Sneaky', StaffRole.owner, '1111');
    expect(cashierSession.staff.where((s) => s.name == 'Sneaky'), isEmpty);

    final session = await signedInSession();
    final me = session.current!;
    expect(session.canRemove(me), isFalse);

    await session.addStaff('Carl', StaffRole.cashier, '2222');
    final carl = session.staff.firstWhere((s) => s.name == 'Carl');
    expect(session.canRemove(carl), isTrue);

    await session.addStaff('Second Owner', StaffRole.owner, '3333');
    final second = session.staff.firstWhere((s) => s.name == 'Second Owner');
    expect(session.canRemove(second), isTrue);
    await session.removeStaff(second);
    expect(session.staff.any((s) => s.id == second.id), isFalse);
  });
}
