import '../models/enums.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

class ProfileRepository {
  String get _uid {
    final id = SupabaseService.client.auth.currentUser?.id;
    if (id == null) throw StateError('Usuário não autenticado.');
    return id;
  }

  Future<Profile> fetchMine() async {
    final row = await SupabaseService.client
        .from('profiles')
        .select()
        .eq('id', _uid)
        .maybeSingle();
    if (row == null) {
      // Perfil ainda não criado (ex.: usuário criado antes do schema).
      final user = SupabaseService.client.auth.currentUser!;
      return Profile(
        id: user.id,
        fullName: (user.userMetadata?['full_name'] as String?) ?? '',
        email: user.email ?? '',
        role: UserRole.operador,
      );
    }
    return Profile.fromMap(row);
  }

  Future<void> update({String? fullName, String? phone, String? jobTitle}) async {
    await SupabaseService.client.from('profiles').update({
      if (fullName != null) 'full_name': fullName.trim(),
      if (phone != null) 'phone': phone.trim().isEmpty ? null : phone.trim(),
      if (jobTitle != null) 'job_title': jobTitle.trim().isEmpty ? null : jobTitle.trim(),
    }).eq('id', _uid);
  }

  Future<NotificationPrefs> fetchPrefs() async {
    final row = await SupabaseService.client
        .from('notification_preferences')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    return row == null ? const NotificationPrefs() : NotificationPrefs.fromMap(row);
  }

  Future<void> savePrefs(NotificationPrefs prefs) async {
    await SupabaseService.client
        .from('notification_preferences')
        .upsert({'user_id': _uid, ...prefs.toMap()});
  }
}
