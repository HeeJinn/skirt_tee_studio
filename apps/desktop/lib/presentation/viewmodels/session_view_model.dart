import 'package:flutter/foundation.dart';

import 'package:shop_core/domain/entities/staff.dart';
import 'package:shop_core/domain/repositories/staff_repository.dart';

/// Who is at the till. Every mutating action in the UI calls [log], so the
/// audit trail records the signed-in staff member against it.
class SessionViewModel extends ChangeNotifier {
  SessionViewModel(this._repository);
  final StaffRepository _repository;

  List<StaffMember> _staff = [];
  List<StaffMember> get staff => List.unmodifiable(_staff);

  StaffMember? _current;
  StaffMember? get current => _current;
  bool get isOwner => _current?.role == StaffRole.owner;

  List<AuditEntry> _activity = [];
  List<AuditEntry> get activity => List.unmodifiable(_activity);

  Future<void> load() async {
    _staff = await _repository.getAll();
    _activity = await _repository.recentActivity();
    notifyListeners();
  }

  /// First-run only: there's no one to authorize an owner, so the first
  /// account is created unauthenticated and signed straight in.
  Future<void> createFirstOwner(String name, String pin) async {
    if (_staff.isNotEmpty) return;
    _current = await _repository.add(name, StaffRole.owner, pin);
    await log('Created the owner account');
    await load();
  }

  Future<bool> signIn(StaffMember member, String pin) async {
    if (!await _repository.verifyPin(member.id, pin)) return false;
    _current = member;
    await log('Signed in');
    return true;
  }

  Future<void> signOut() async {
    await log('Signed out');
    _current = null;
    notifyListeners();
  }

  Future<void> addStaff(String name, StaffRole role, String pin) async {
    if (!isOwner) return;
    await _repository.add(name, role, pin);
    await log('Added ${role.name} "$name"');
    await load();
  }

  /// Refuses to remove yourself or the last owner — either would lock the
  /// shop out of owner-only functions.
  bool canRemove(StaffMember member) =>
      isOwner &&
      member.id != _current?.id &&
      (member.role != StaffRole.owner || _staff.where((s) => s.role == StaffRole.owner).length > 1);

  Future<void> removeStaff(StaffMember member) async {
    if (!canRemove(member)) return;
    await _repository.delete(member.id);
    await log('Removed ${member.role.name} "${member.name}"');
    await load();
  }

  Future<void> log(String action) async {
    final user = _current;
    if (user == null) return;
    await _repository.log(user.name, action);
    _activity = await _repository.recentActivity();
    notifyListeners();
  }
}
