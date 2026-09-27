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

  /// Null if [name] is fine to use for [member]; otherwise why not. Names
  /// must be unique, since money entries record owners by name.
  String? checkName(StaffMember member, String name) {
    if (name.trim().isEmpty) return 'Required';
    final taken = _staff.any((s) => s.id != member.id && s.name.toLowerCase() == name.trim().toLowerCase());
    return taken ? 'Someone already has that name' : null;
  }

  /// Owners rename themselves; the log keeps the old name on past entries.
  Future<void> renameSelf(String name) async {
    final me = _current;
    if (me == null || !isOwner || checkName(me, name) != null) return;
    name = name.trim();
    if (name == me.name) return;
    await _repository.rename(me.id, name);
    _current = StaffMember(id: me.id, name: name, role: me.role);
    await log('Renamed "${me.name}" to "$name"');
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
