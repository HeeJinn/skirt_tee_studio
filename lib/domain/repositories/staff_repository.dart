import '../entities/staff.dart';

abstract class StaffRepository {
  Future<List<StaffMember>> getAll();
  Future<StaffMember> add(String name, StaffRole role, String pin);
  Future<void> delete(String id);
  Future<bool> verifyPin(String id, String pin);

  Future<void> log(String staffName, String action);

  /// Newest first.
  Future<List<AuditEntry>> recentActivity({int limit = 200});
}
