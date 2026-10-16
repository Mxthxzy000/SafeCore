import '../models/plant_summary.dart';
import '../services/supabase_service.dart';

class ReportRepository {
  /// Médias de temperatura e pressão agrupadas por hora ou dia.
  Future<List<ReportPoint>> fetchSeries({
    required DateTime from,
    required DateTime to,
    required bool hourly,
  }) async {
    final rows = await SupabaseService.client.rpc<List<dynamic>>('report_series', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_bucket': hourly ? 'hour' : 'day',
    });
    return rows.map((r) => ReportPoint.fromMap(Map<String, dynamic>.from(r as Map))).toList();
  }
}
