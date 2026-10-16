import '../models/enums.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

/// Funcionários, funções e permissões por área.
/// As regras são verificadas no banco (RLS e funções `admin_set_role` /
/// `set_area_member`); a interface apenas reflete o que o usuário pode fazer.
class PermissionRepository {
  String? get _uid => SupabaseService.client.auth.currentUser?.id;

  /// Vínculos do usuário logado com as áreas.
  Future<List<AreaMember>> fetchMine() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await SupabaseService.client.from('area_members').select().eq('user_id', uid);
    return rows.map(AreaMember.fromMap).toList();
  }

  /// Lista de funcionários (visível para supervisores e administradores).
  Future<List<Profile>> fetchEmployees() async {
    final rows = await SupabaseService.client.from('profiles').select().order('full_name');
    return rows.map(Profile.fromMap).toList();
  }

  Future<Profile> fetchEmployee(String userId) async {
    final row = await SupabaseService.client.from('profiles').select().eq('id', userId).single();
    return Profile.fromMap(row);
  }

  Future<List<AreaMember>> fetchMembersOf(String userId) async {
    final rows = await SupabaseService.client.from('area_members').select().eq('user_id', userId);
    return rows.map(AreaMember.fromMap).toList();
  }

  Future<void> setRole(String userId, UserRole role) async {
    await SupabaseService.client
        .rpc('admin_set_role', params: {'p_user_id': userId, 'p_role': role.name});
  }

  /// Define o nível de acesso; [AccessLevel.nenhum] remove o vínculo.
  Future<void> setAreaLevel(String userId, String areaId, AccessLevel level) async {
    await SupabaseService.client.rpc('set_area_member', params: {
      'p_user_id': userId,
      'p_area_id': areaId,
      'p_level': level == AccessLevel.nenhum ? null : level.name,
    });
  }
}
