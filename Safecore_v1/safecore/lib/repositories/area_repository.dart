import '../core/utils/error_messages.dart';
import '../models/alert.dart';
import '../models/area.dart';
import '../services/mqtt_service.dart';
import '../services/supabase_service.dart';

/// Ações disponíveis para uma área (com envio de comando MQTT para a Caldeira).
enum AreaAction {
  ventilacao('Ativar ventilação'),
  isolamento('Isolar área'),
  liberacao('Liberar área');

  const AreaAction(this.label);
  final String label;
}

class AreaRepository {
  static const _select = '*, sensors(*)';

  /// Áreas ativas visíveis para o usuário.
  /// Apenas o setor da Caldeira permanece conectado (recebendo dados do broker MQTT `safecore/quimex/caldeira`);
  /// todos os demais setores são exibidos como desconectados.
  Future<List<Area>> fetchAll() async {
    final rows = await SupabaseService.client
        .from('areas')
        .select(_select)
        .isFilter('archived_at', null)
        .order('name');
    return rows.map(Area.fromMap).map(MqttService.instance.applyToArea).toList();
  }

  Future<Area> create(AreaInput input) async {
    final row = await SupabaseService.client
        .from('areas')
        .insert(input.toMap())
        .select(_select)
        .single();
    return MqttService.instance.applyToArea(Area.fromMap(row));
  }

  Future<void> update(String id, AreaInput input) async {
    final rows = await SupabaseService.client
        .from('areas')
        .update(input.toMap())
        .eq('id', id)
        .select('id');
    // O RLS não gera erro ao bloquear um UPDATE: apenas não altera linhas.
    if (rows.isEmpty) throw const PermissionDeniedException('editar esta área');
  }

  /// Exclui a área. Se ela tiver histórico, o banco a arquiva.
  /// Retorna `true` se foi arquivada (histórico preservado).
  Future<bool> delete(String id) async {
    final result = await SupabaseService.client.rpc<String>('delete_area', params: {'p_area_id': id});
    return result == 'arquivada';
  }

  Future<Area> fetchById(String id) async {
    final row = await SupabaseService.client.from('areas').select(_select).eq('id', id).single();
    return MqttService.instance.applyToArea(Area.fromMap(row));
  }

  Future<List<ActionLog>> fetchActions(String areaId, {int limit = 20}) async {
    final rows = await SupabaseService.client
        .from('action_logs')
        .select()
        .eq('area_id', areaId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(ActionLog.fromMap).toList();
  }

  Future<void> simulateAction(String areaId, AreaAction action, {String? alertId}) async {
    MqttService.instance.publishCommand(action.name);
    await SupabaseService.client.rpc('simulate_area_action', params: {
      'p_area_id': areaId,
      'p_action': action.name,
      'p_alert_id': alertId,
    });
  }
}

/// Dados editáveis de uma área (formulário de cadastro/edição).
class AreaInput {
  const AreaInput({
    required this.code,
    required this.name,
    required this.type,
    required this.status,
    this.description,
    this.statusNote,
    this.restricted = false,
  });

  final String code;
  final String name;
  final String type;
  final String status;
  final String? description;
  final String? statusNote;
  final bool restricted;

  Map<String, dynamic> toMap() => {
        'code': code.trim().toUpperCase(),
        'name': name.trim(),
        'area_type': type,
        'status': status,
        'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
        'status_note': (statusNote ?? '').trim().isEmpty ? null : statusNote!.trim(),
        'restricted': restricted,
      };
}
