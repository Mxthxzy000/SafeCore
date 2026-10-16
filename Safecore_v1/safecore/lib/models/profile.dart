import 'enums.dart';

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone,
    this.jobTitle,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? jobTitle;
  final UserRole role;

  String get displayName => fullName.trim().isEmpty ? email : fullName;

  /// Texto exibido abaixo do nome (função ou papel no sistema).
  String get roleLabel =>
      (jobTitle != null && jobTitle!.trim().isNotEmpty) ? jobTitle! : role.label;

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        fullName: map['full_name'] as String? ?? '',
        email: map['email'] as String? ?? '',
        phone: map['phone'] as String?,
        jobTitle: map['job_title'] as String?,
        role: UserRole.parse(map['role'] as String?),
      );
}

class NotificationPrefs {
  const NotificationPrefs({
    this.enabled = true,
    this.criticalAlerts = true,
    this.warningAlerts = true,
    this.occurrences = true,
    this.dailySummary = false,
  });

  final bool enabled;
  final bool criticalAlerts;
  final bool warningAlerts;
  final bool occurrences;
  final bool dailySummary;

  factory NotificationPrefs.fromMap(Map<String, dynamic> map) => NotificationPrefs(
        enabled: map['enabled'] as bool? ?? true,
        criticalAlerts: map['critical_alerts'] as bool? ?? true,
        warningAlerts: map['warning_alerts'] as bool? ?? true,
        occurrences: map['occurrences'] as bool? ?? true,
        dailySummary: map['daily_summary'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'critical_alerts': criticalAlerts,
        'warning_alerts': warningAlerts,
        'occurrences': occurrences,
        'daily_summary': dailySummary,
      };

  NotificationPrefs copyWith({
    bool? enabled,
    bool? criticalAlerts,
    bool? warningAlerts,
    bool? occurrences,
    bool? dailySummary,
  }) =>
      NotificationPrefs(
        enabled: enabled ?? this.enabled,
        criticalAlerts: criticalAlerts ?? this.criticalAlerts,
        warningAlerts: warningAlerts ?? this.warningAlerts,
        occurrences: occurrences ?? this.occurrences,
        dailySummary: dailySummary ?? this.dailySummary,
      );

  /// Indica se um alerta da severidade informada deve gerar aviso no app.
  bool allows(AlertSeverity severity) =>
      enabled && (severity == AlertSeverity.critico ? criticalAlerts : warningAlerts);
}

/// Vínculo de um funcionário com uma área (area_members).
class AreaMember {
  const AreaMember({required this.userId, required this.areaId, required this.level});

  final String userId;
  final String areaId;
  final AccessLevel level;

  factory AreaMember.fromMap(Map<String, dynamic> map) => AreaMember(
        userId: map['user_id'] as String,
        areaId: map['area_id'] as String,
        level: AccessLevel.parse(map['access_level'] as String?),
      );
}
