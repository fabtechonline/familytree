import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_providers.dart';

class PlatformStats {
  const PlatformStats({
    required this.totalUsers,
    required this.totalFamilies,
    required this.premiumFamilies,
    required this.blockedUsers,
  });
  final int totalUsers;
  final int totalFamilies;
  final int premiumFamilies;
  final int blockedUsers;

  factory PlatformStats.fromMap(Map<String, dynamic> m) => PlatformStats(
        totalUsers: (m['total_users'] as num).toInt(),
        totalFamilies: (m['total_families'] as num).toInt(),
        premiumFamilies: (m['premium_families'] as num).toInt(),
        blockedUsers: (m['blocked_users'] as num).toInt(),
      );
}

class Account {
  const Account({
    required this.id,
    this.email,
    this.displayName,
    required this.status,
    required this.isSuperAdmin,
    this.createdAt,
    this.lastActiveAt,
  });
  final String id;
  final String? email;
  final String? displayName;
  final String status;
  final bool isSuperAdmin;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  String get label => (displayName ?? '').trim().isNotEmpty
      ? displayName!.trim()
      : (email ?? 'Unknown');

  factory Account.fromMap(Map<String, dynamic> m) => Account(
        id: m['id'] as String,
        email: m['email'] as String?,
        displayName: m['display_name'] as String?,
        status: m['status'] as String? ?? 'active',
        isSuperAdmin: m['is_super_admin'] as bool? ?? false,
        createdAt: m['created_at'] == null
            ? null
            : DateTime.tryParse(m['created_at'] as String),
        lastActiveAt: m['last_active_at'] == null
            ? null
            : DateTime.tryParse(m['last_active_at'] as String),
      );
}

class AdminFamily {
  const AdminFamily({
    required this.id,
    required this.name,
    required this.tier,
    required this.userCount,
    required this.personCount,
    this.createdAt,
    this.isSuspended = false,
    this.planKey = 'free',
    this.isComp = false,
  });
  final String id;
  final String name;
  final String tier;

  /// App users (logins) in this family.
  final int userCount;

  /// People in the family tree.
  final int personCount;
  final DateTime? createdAt;
  final bool isSuspended;
  final String planKey;
  final bool isComp;

  factory AdminFamily.fromMap(Map<String, dynamic> m) => AdminFamily(
        id: m['id'] as String,
        name: m['name'] as String,
        tier: m['subscription_tier'] as String? ?? 'free',
        userCount: (m['member_count'] as num?)?.toInt() ?? 0,
        personCount: (m['person_count'] as num?)?.toInt() ?? 0,
        createdAt: m['created_at'] == null
            ? null
            : DateTime.tryParse(m['created_at'] as String),
        isSuspended: m['is_suspended'] as bool? ?? false,
        planKey: m['plan_key'] as String? ?? 'free',
        isComp: m['is_comp'] as bool? ?? false,
      );
}

class AuditEntry {
  const AuditEntry({
    required this.action,
    this.targetId,
    required this.metadata,
    required this.createdAt,
  });
  final String action;
  final String? targetId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  factory AuditEntry.fromMap(Map<String, dynamic> m) => AuditEntry(
        action: m['action'] as String,
        targetId: m['target_id'] as String?,
        metadata: Map<String, dynamic>.from(m['metadata'] as Map? ?? {}),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  Future<bool> isSuperAdmin() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('profiles')
        .select('is_super_admin')
        .eq('id', uid)
        .maybeSingle();
    return row?['is_super_admin'] == true;
  }

  Future<PlatformStats> stats() async {
    final result = await _client.rpc('admin_platform_stats');
    final m = (result is List ? result.first : result) as Map<String, dynamic>;
    return PlatformStats.fromMap(m);
  }

  Future<List<Account>> accounts({String? search}) async {
    var query = _client.from('profiles').select(
        'id, email, display_name, status, is_super_admin, created_at, last_active_at');
    if (search != null && search.trim().isNotEmpty) {
      final s = '%${search.trim()}%';
      query = query.or('email.ilike.$s,display_name.ilike.$s');
    }
    final rows = await query.order('created_at', ascending: false).limit(500);
    return (rows as List)
        .map((r) => Account.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> setStatus(String userId, String status) async {
    await _client
        .rpc('admin_set_account_status', params: {'p_user': userId, 'p_status': status});
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<List<AdminFamily>> families() async {
    final rows = await _client.rpc('admin_list_families');
    return (rows as List)
        .map((r) => AdminFamily.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> setSubscription(String familyId, String tier) async {
    await _client.rpc('admin_set_subscription',
        params: {'p_family': familyId, 'p_tier': tier});
  }

  /// Assign a plan to a family (optionally free/comp, with an optional expiry).
  Future<void> setFamilyPlan(String familyId, String planKey,
      {bool comp = false, DateTime? expiresAt}) async {
    await _client.rpc('admin_set_family_plan', params: {
      'p_family': familyId,
      'p_plan_key': planKey,
      'p_comp': comp,
      'p_expires_at': expiresAt?.toIso8601String(),
    });
  }

  Future<void> suspendFamily(String familyId, bool suspend,
      {String? reason}) async {
    await _client.rpc('admin_suspend_family', params: {
      'p_family': familyId,
      'p_reason': reason,
      'p_suspend': suspend,
    });
  }

  Future<void> setMemberLimit(String familyId, int? limit) async {
    await _client.rpc('admin_set_member_limit',
        params: {'p_family': familyId, 'p_limit': limit});
  }

  Future<List<AuditEntry>> audit({int limit = 100}) async {
    final rows = await _client
        .from('audit_log')
        .select('action, target_id, metadata, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => AuditEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> signOut() => _client.auth.signOut();
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

/// Whether the signed-in user is a platform super-admin (profiles.is_super_admin).
final isSuperAdminProvider = FutureProvider<bool>((ref) async {
  return ref.watch(adminRepositoryProvider).isSuperAdmin();
});

final adminStatsProvider =
    FutureProvider<PlatformStats>((ref) => ref.watch(adminRepositoryProvider).stats());

final adminAccountsProvider = FutureProvider.family<List<Account>, String>(
    (ref, search) => ref.watch(adminRepositoryProvider).accounts(search: search));

final adminFamiliesProvider =
    FutureProvider<List<AdminFamily>>((ref) => ref.watch(adminRepositoryProvider).families());

final adminAuditProvider =
    FutureProvider<List<AuditEntry>>((ref) => ref.watch(adminRepositoryProvider).audit());
