import '../models/enums.dart';
import '../models/occurrence.dart';
import '../services/supabase_service.dart';

class OccurrenceRepository {
  static const _select = '*, areas(name)';

  Future<List<Occurrence>> fetchAll({String? areaId}) async {
    var query = SupabaseService.client.from('occurrences').select(_select);
    if (areaId != null) query = query.eq('area_id', areaId);
    final rows = await query.order('created_at', ascending: false).limit(200);
    return rows.map(Occurrence.fromMap).toList();
  }

  Future<List<Occurrence>> fetchInPeriod(DateTime from, DateTime to) async {
    final rows = await SupabaseService.client
        .from('occurrences')
        .select(_select)
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return rows.map(Occurrence.fromMap).toList();
  }

  Future<Occurrence> fetchById(String id) async {
    final row =
        await SupabaseService.client.from('occurrences').select(_select).eq('id', id).single();
    return Occurrence.fromMap(row);
  }

  Future<void> create({
    required OccurrenceKind kind,
    required String title,
    required String description,
    required Priority priority,
    String? areaId,
  }) async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    await SupabaseService.client.from('occurrences').insert({
      'kind': kind.name,
      'title': title.trim(),
      'description': description.trim(),
      'priority': priority.name,
      'area_id': areaId,
      'reported_by': uid,
    });
  }

  Future<void> updateStatus(String id, OccurrenceStatus status) async {
    await SupabaseService.client.rpc('update_occurrence_status', params: {
      'p_id': id,
      'p_status': status.dbValue,
    });
  }
}
