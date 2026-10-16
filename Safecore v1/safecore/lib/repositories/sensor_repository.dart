import '../models/sensor.dart';
import '../services/supabase_service.dart';

class SensorRepository {
  static const _select = '*, areas(name)';

  Future<List<Sensor>> fetchAll() async {
    final rows = await SupabaseService.client.from('sensors').select(_select).order('code');
    return rows.map(Sensor.fromMap).toList();
  }

  Future<Sensor> fetchById(String id) async {
    final row = await SupabaseService.client.from('sensors').select(_select).eq('id', id).single();
    return Sensor.fromMap(row);
  }

  /// Histórico de leituras a partir de [since], em ordem cronológica.
  Future<List<SensorReading>> fetchReadings(String sensorId, DateTime since) async {
    final rows = await SupabaseService.client
        .from('sensor_readings')
        .select('value, recorded_at, source')
        .eq('sensor_id', sensorId)
        .gte('recorded_at', since.toUtc().toIso8601String())
        .order('recorded_at')
        .limit(1000);
    return rows.map(SensorReading.fromMap).toList();
  }

  /// Gera uma nova rodada de leituras SIMULADAS no banco.
  /// Retorna a quantidade de leituras criadas.
  Future<int> simulateReadings() async {
    final result = await SupabaseService.client.rpc<int>('simulate_readings');
    return result;
  }
}
