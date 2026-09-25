import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/staff.dart';
import '../../domain/repositories/staff_repository.dart';

class StaffRepositoryImpl implements StaffRepository {
  StaffRepositoryImpl(this._db);
  final Database _db;

  // ponytail: iterated salted SHA-256; a 4–6 digit PIN is brute-forceable
  // from a stolen DB regardless — move to PBKDF2/argon2 + real passwords if
  // accounts ever guard more than this local till.
  static String hashPin(String pin, String salt) {
    List<int> bytes = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64.encode(bytes);
  }

  @override
  Future<List<StaffMember>> getAll() async {
    final rows = await _db.query('staff', orderBy: 'name');
    return [
      for (final r in rows)
        StaffMember(
          id: r['id'] as String,
          name: r['name'] as String,
          role: StaffRole.values.byName(r['role'] as String),
        ),
    ];
  }

  @override
  Future<StaffMember> add(String name, StaffRole role, String pin) async {
    final random = Random.secure();
    final salt = base64.encode(List.generate(16, (_) => random.nextInt(256)));
    final member = StaffMember(id: const Uuid().v4(), name: name, role: role);
    await _db.insert('staff', {
      'id': member.id,
      'name': name,
      'role': role.name,
      'pinHash': hashPin(pin, salt),
      'salt': salt,
    });
    return member;
  }

  @override
  Future<void> delete(String id) => _db.delete('staff', where: 'id = ?', whereArgs: [id]);

  @override
  Future<bool> verifyPin(String id, String pin) async {
    final rows = await _db.query('staff', columns: ['pinHash', 'salt'], where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return false;
    return hashPin(pin, rows.single['salt'] as String) == rows.single['pinHash'];
  }

  @override
  Future<void> log(String staffName, String action) => _db.insert('audit_log', {
        'at': DateTime.now().toIso8601String(),
        'staffName': staffName,
        'action': action,
      });

  @override
  Future<List<AuditEntry>> recentActivity({int limit = 200}) async {
    final rows = await _db.query('audit_log', orderBy: 'id DESC', limit: limit);
    return [
      for (final r in rows)
        AuditEntry(
          at: DateTime.parse(r['at'] as String),
          staffName: r['staffName'] as String,
          action: r['action'] as String,
        ),
    ];
  }
}
