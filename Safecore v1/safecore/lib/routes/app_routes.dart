import 'package:flutter/material.dart';

import '../features/alerts/alert_detail_screen.dart';
import '../features/alerts/alert_form_screen.dart';
import '../features/areas/area_detail_screen.dart';
import '../features/areas/area_form_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/employees/employee_detail_screen.dart';
import '../features/employees/employees_screen.dart';
import '../features/occurrences/new_occurrence_screen.dart';
import '../features/occurrences/occurrence_detail_screen.dart';
import '../features/occurrences/occurrences_screen.dart';
import '../features/profile/change_password_screen.dart';
import '../features/profile/notification_settings_screen.dart';
import '../features/sensors/sensor_detail_screen.dart';
import '../features/sensors/sensors_screen.dart';

/// Nomes das rotas e criação das telas.
abstract final class AppRoutes {
  static const register = '/cadastro';
  static const forgotPassword = '/recuperar-senha';
  static const resetPassword = '/nova-senha';
  static const areaDetail = '/area';
  static const areaNew = '/area/nova';
  static const areaEdit = '/area/editar';
  static const sensors = '/sensores';
  static const sensorDetail = '/sensor';
  static const alertDetail = '/alerta';
  static const alertNew = '/alerta/novo';
  static const alertEdit = '/alerta/editar';
  static const occurrences = '/mural';
  static const newOccurrence = '/mural/novo';
  static const occurrenceDetail = '/mural/detalhe';
  static const changePassword = '/perfil/senha';
  static const notifications = '/perfil/notificacoes';
  static const employees = '/funcionarios';
  static const employeeDetail = '/funcionarios/detalhe';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final Widget? page = switch (settings.name) {
      register => const RegisterScreen(),
      forgotPassword => const ForgotPasswordScreen(),
      resetPassword => const ResetPasswordScreen(),
      areaDetail => AreaDetailScreen(areaId: args as String),
      areaNew => const AreaFormScreen(),
      areaEdit => AreaFormScreen(areaId: args as String),
      sensors => SensorsScreen(initialAreaId: args as String?),
      sensorDetail => SensorDetailScreen(sensorId: args as String),
      alertDetail => AlertDetailScreen(alertId: args as String),
      alertNew => AlertFormScreen(initialAreaId: args as String?),
      alertEdit => AlertFormScreen(alertId: args as String),
      occurrences => const OccurrencesScreen(),
      newOccurrence => NewOccurrenceScreen(initialAreaId: args as String?),
      occurrenceDetail => OccurrenceDetailScreen(occurrenceId: args as String),
      changePassword => const ChangePasswordScreen(),
      notifications => const NotificationSettingsScreen(),
      employees => const EmployeesScreen(),
      employeeDetail => EmployeeDetailScreen(userId: args as String),
      _ => null,
    };
    if (page == null) return null;
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }
}
