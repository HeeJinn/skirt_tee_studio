import 'package:shop_core/domain/entities/staff.dart';
import 'package:shop_core/domain/repositories/staff_repository.dart';
import 'package:skirt_tee_studio/presentation/viewmodels/session_view_model.dart';

class FakeStaffRepository implements StaffRepository {
  final _staff = <StaffMember>[];
  final _pins = <String, String>{};
  final _log = <AuditEntry>[];

  @override
  Future<List<StaffMember>> getAll() async => List.of(_staff);

  @override
  Future<StaffMember> add(String name, StaffRole role, String pin) async {
    final member = StaffMember(id: 'staff-${_staff.length}', name: name, role: role);
    _staff.add(member);
    _pins[member.id] = pin;
    return member;
  }

  @override
  Future<void> delete(String id) async => _staff.removeWhere((s) => s.id == id);

  @override
  Future<bool> verifyPin(String id, String pin) async => _pins[id] == pin;

  @override
  Future<void> log(String staffName, String action) async =>
      _log.insert(0, AuditEntry(at: DateTime.now(), staffName: staffName, action: action));

  @override
  Future<List<AuditEntry>> recentActivity({int limit = 200}) async => _log.take(limit).toList();
}

/// A session already signed in as [role] — for widget tests of the shell.
Future<SessionViewModel> signedInSession({StaffRole role = StaffRole.owner}) async {
  final repository = FakeStaffRepository();
  final member = await repository.add(role == StaffRole.owner ? 'Olivia Owner' : 'Carl Cashier', role, '1234');
  final session = SessionViewModel(repository);
  await session.load();
  await session.signIn(member, '1234');
  return session;
}
