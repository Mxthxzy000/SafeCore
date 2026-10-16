import '../models/sensor.dart';
import '../services/mqtt_service.dart';
import '../services/supabase_service.dart';

class SensorRepository {
  static const _select = '*, areas(name)';

  Future<List<Sensor>> fetchAll() async {
    final rows = await SupabaseService.client.from('sensors').select(_select).order('code');
    return rows.map(Sensor.fromMap).map(MqttService.instance.applyToSensor).toList();
  }

  Future<Sensor> fetchById(String id) async {
    final row = await SupabaseService.client.from('sensors').select(_select).eq('id', id).single();
    return MqttService.instance.applyToSensor(Sensor.fromMap(row));
  }

  /// Histórico de leituras a partir de [since], em ordem cronológica.
  /// Para sensores da Caldeira, retorna as leituras recebidas do broker MQTT (`esp32`);
  /// para sensores de setores desconectados, não retorna leituras simuladas.
  Future<List<SensorReading>> fetchReadings(String sensorId, DateTime since) async {
    final sensorRow = await SupabaseService.client
        .from('sensors')
        .select('code')
        .eq('id', sensorId)
        .maybeSingle();
    final code = (sensorRow?['code'] as String?) ?? '';

    if (!code.toUpperCase().startsWith('CLD-')) {
      return const [];
    }

    final live = MqttService.instance.liveReadingsFor(code, since);
    if (live.isNotEmpty) return live;

    final rows = await SupabaseService.client
        .from('sensor_readings')
        .select('value, recorded_at, source')
        .eq('sensor_id', sensorId)
        .eq('source', 'esp32')
        .gte('recorded_at', since.toUtc().toIso8601String())
        .order('recorded_at')
        .limit(1000);
    return rows.map(SensorReading.fromMap).toList();
  }
}

