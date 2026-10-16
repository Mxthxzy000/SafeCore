import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/error_messages.dart';
import '../models/alert.dart';
import '../models/enums.dart';
import '../services/supabase_service.dart';

class AlertRepository {
  static const _select = '*, areas(name), sensors(name)';

  Future<List<Alert>> fetchAll({String? areaId, bool openOnly = false, int limit = 200}) async {
    var query = SupabaseService.client.from('alerts').select(_select);
    if (areaId != null) query = query.eq('area_id', areaId);
    if (openOnly) query = query.neq('status', 'resolvido');
    final rows = await query.order('detected_at', ascending: false).limit(limit);
    return rows.map(Alert.fromMap).toList();
  }

  Future<List<Alert>> fetchInPeriod(DateTime from, DateTime to) async {
    final rows = await SupabaseService.client
        .from('alerts')
        .select(_select)
        .gte('detected_at', from.toUtc().toIso8601String())
        .lt('detected_at', to.toUtc().toIso8601String())
        .order('detected_at', ascending: false);
    return rows.map(Alert.fromMap).toList();
  }

  Future<Alert> fetchById(String id) async {
    final row = await SupabaseService.client.from('alerts').select(_select).eq('id', id).single();
    return Alert.fromMap(row);
  }

  Future<List<ActionLog>> fetchActions(String alertId) async {
    final rows = await SupabaseService.client
        .from('action_logs')
        .select()
        .eq('alert_id', alertId)
        .order('created_at', ascending: false);
    return rows.map(ActionLog.fromMap).toList();
  }

  /// Cadastra um alerta manual (o banco define origem 'manual').
  Future<Alert> create(AlertInput input) async {
    final row = await SupabaseService.client
        .from('alerts')
        .insert(input.toMap())
        .select(_select)
        .single();
    return Alert.fromMap(row);
  }

  /// Atualiza o alerta. Para alertas de sensor, envie `sensorAlert: true`:
  /// somente título, descrição e status são alterados.
  Future<void> update(String id, AlertInput input, {required bool sensorAlert}) async {
    final data = input.toMap();
    if (sensorAlert) {
      data.removeWhere((key, _) => !{'title', 'description', 'status'}.contains(key));
    }
    final rows =
        await SupabaseService.client.from('alerts').update(data).eq('id', id).select('id');
    if (rows.isEmpty) throw const PermissionDeniedException('editar este alerta');
  }

  Future<void> delete(String id) async {
    final rows = await SupabaseService.client.from('alerts').delete().eq('id', id).select('id');
    if (rows.isEmpty) throw const PermissionDeniedException('excluir este alerta');
  }

  Future<void> addComment(String alertId, String text) => _action(alertId, 'comentario', text);

  Future<void> acknowledge(String alertId) =>
      _action(alertId, 'reconhecido', 'Alerta assumido para tratamento.');

  Future<void> resolve(String alertId, String note) async {
    await SupabaseService.client
        .rpc('resolve_alert', params: {'p_alert_id': alertId, 'p_note': note});
  }

  Future<void> _action(String alertId, String type, String text) async {
    await SupabaseService.client.rpc('add_alert_action', params: {
      'p_alert_id': alertId,
      'p_action': type,
      'p_description': text,
    });
  }

  /// Escuta novos alertas em tempo real (Supabase Realtime).
  RealtimeChannel watchNew(void Function(Map<String, dynamic> row) onInsert) {
    return SupabaseService.client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alerts',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> stopWatching(RealtimeChannel channel) =>
      SupabaseService.client.removeChannel(channel);
}

/// Dados editáveis de um alerta (formulário de cadastro/edição).
class AlertInput {
  const AlertInput({
    required this.areaId,
    required this.title,
    required this.severity,
    required this.status,
    required this.category,
    required this.detectedAt,
    this.description,
    this.detectedValue,
    this.unit,
  });

  final String areaId;
  final String title;
  final AlertSeverity severity;
  final AlertStatus status;
  final AlertCategory category;
  final DateTime detectedAt;
  final String? description;
  final double? detectedValue;
  final String? unit;

  Map<String, dynamic> toMap() => {
        'area_id': areaId,
        'title': title.trim(),
        'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
        'severity': severity.name,
        'status': status.dbValue,
        'category': category.name,
        'detected_at': detectedAt.toUtc().toIso8601String(),
        'detected_value': detectedValue,
        'unit': (unit ?? '').trim().isEmpty ? null : unit!.trim(),
      };
}
