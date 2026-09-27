import '../entities/staff.dart';

abstract class StaffRepository {
  Future<List<StaffMember>> getAll();
  Future<StaffMember> add(String name, StaffRole role, String pin);
  Future<void> delete(String id);

  /// Also moves money entries and stock lots recorded under the old name,
  /// since those name the owner rather than point at an id.
  Future<void> rename(String id, String name);
  Future<bool> verifyPin(String id, String pin);

  Future<void> log(String staffName, String action);

  /// Newest first.
  Future<List<AuditEntry>> recentActivity({int limit = 200});
}
