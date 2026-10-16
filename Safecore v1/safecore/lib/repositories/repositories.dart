import 'alert_repository.dart';
import 'area_repository.dart';
import 'auth_repository.dart';
import 'occurrence_repository.dart';
import 'permission_repository.dart';
import 'profile_repository.dart';
import 'report_repository.dart';
import 'sensor_repository.dart';

export 'alert_repository.dart';
export 'area_repository.dart';
export 'auth_repository.dart';
export 'occurrence_repository.dart';
export 'permission_repository.dart';
export 'profile_repository.dart';
export 'report_repository.dart';
export 'sensor_repository.dart';

/// Ponto único de acesso aos repositórios usados pelas telas.
abstract final class Repos {
  static final auth = AuthRepository();
  static final profile = ProfileRepository();
  static final areas = AreaRepository();
  static final sensors = SensorRepository();
  static final alerts = AlertRepository();
  static final occurrences = OccurrenceRepository();
  static final reports = ReportRepository();
  static final permissions = PermissionRepository();
}
