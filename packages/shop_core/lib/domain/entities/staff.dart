enum StaffRole { owner, cashier }

class StaffMember {
  const StaffMember({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final StaffRole role;
}

class AuditEntry {
  const AuditEntry({required this.at, required this.staffName, required this.action});

  final DateTime at;
  final String staffName;
  final String action;
}
