import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Estado visual comum (cor, fundo, ícone) usado pelos chips de status.
class StatusStyle {
  const StatusStyle(this.label, this.color, this.background, this.icon);

  final String label;
  final Color color;
  final Color background;
  final IconData icon;
}

enum AreaStatus {
  segura(StatusStyle('Segura', AppColors.safe, AppColors.safeBg, Icons.verified_user_outlined)),
  atencao(StatusStyle('Atenção', AppColors.warning, AppColors.warningBg, Icons.warning_amber_rounded)),
  critica(StatusStyle('Crítica', AppColors.critical, AppColors.criticalBg, Icons.report_outlined)),
  interditada(StatusStyle('Interditada', AppColors.blocked, AppColors.blockedBg, Icons.block)),
  desconectada(StatusStyle('Desconectada', AppColors.offline, AppColors.offlineBg, Icons.wifi_off_rounded));

  const AreaStatus(this.style);
  final StatusStyle style;

  static AreaStatus parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => AreaStatus.segura);

  /// Ordem de gravidade usada para ordenar listas (mais grave primeiro).
  int get priority => switch (this) {
        critica => 0,
        interditada => 1,
        atencao => 2,
        desconectada => 3,
        segura => 4,
      };
}

enum SensorLevel {
  normal(StatusStyle('Normal', AppColors.safe, AppColors.safeBg, Icons.check_circle_outline)),
  atencao(StatusStyle('Atenção', AppColors.warning, AppColors.warningBg, Icons.warning_amber_rounded)),
  critico(StatusStyle('Crítico', AppColors.critical, AppColors.criticalBg, Icons.report_outlined));

  const SensorLevel(this.style);
  final StatusStyle style;

  static SensorLevel parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => SensorLevel.normal);
}

enum SensorStatus {
  online('Online'),
  offline('Sem comunicação'),
  manutencao('Em manutenção');

  const SensorStatus(this.label);
  final String label;

  static SensorStatus parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => SensorStatus.online);
}

enum SensorType {
  temperatura('Temperatura', Icons.thermostat, Color(0xFF014D90)),
  pressao('Pressão', Icons.speed, Color(0xFFD32F2F)),
  umidade('Umidade', Icons.water_drop_outlined, Color(0xFF86BBD8)),
  gas('Gases', Icons.cloud_outlined, Color(0xFFE59A12)),
  fumaca('Fumaça', Icons.local_fire_department_outlined, Color(0xFF2F4858)),
  ventilacao('Ventilação', Icons.air, Color(0xFF79CC4B));

  const SensorType(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  static SensorType parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => SensorType.temperatura);
}

enum AlertSeverity {
  atencao(StatusStyle('Atenção', AppColors.warning, AppColors.warningBg, Icons.warning_amber_rounded)),
  critico(StatusStyle('Crítico', AppColors.critical, AppColors.criticalBg, Icons.report_outlined));

  const AlertSeverity(this.style);
  final StatusStyle style;

  static AlertSeverity parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => AlertSeverity.atencao);
}

enum AlertStatus {
  ativo('Ativo'),
  emAndamento('Em andamento'),
  resolvido('Resolvido');

  const AlertStatus(this.label);
  final String label;

  String get dbValue => this == emAndamento ? 'em_andamento' : name;

  static AlertStatus parse(String? v) => switch (v) {
        'em_andamento' => emAndamento,
        'resolvido' => resolvido,
        _ => ativo,
      };
}

const resolvedStyle = StatusStyle('Resolvido', AppColors.safe, AppColors.safeBg, Icons.check_circle_outline);

enum OccurrenceKind {
  aviso('Aviso', Icons.campaign_outlined),
  ocorrencia('Ocorrência', Icons.assignment_late_outlined);

  const OccurrenceKind(this.label, this.icon);
  final String label;
  final IconData icon;

  static OccurrenceKind parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => OccurrenceKind.ocorrencia);
}

enum OccurrenceStatus {
  aberta(StatusStyle('Aberta', AppColors.primary, Color(0xFFE3EEF8), Icons.radio_button_unchecked)),
  emAnalise(StatusStyle('Em análise', AppColors.warning, AppColors.warningBg, Icons.hourglass_bottom)),
  resolvida(StatusStyle('Resolvida', AppColors.safe, AppColors.safeBg, Icons.check_circle_outline));

  const OccurrenceStatus(this.style);
  final StatusStyle style;

  String get dbValue => this == emAnalise ? 'em_analise' : name;

  static OccurrenceStatus parse(String? v) => switch (v) {
        'em_analise' => emAnalise,
        'resolvida' => resolvida,
        _ => aberta,
      };
}

enum Priority {
  baixa('Baixa', AppColors.offline),
  media('Média', AppColors.warning),
  alta('Alta', AppColors.critical);

  const Priority(this.label, this.color);
  final String label;
  final Color color;

  static Priority parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => Priority.media);
}

enum UserRole {
  operador('Operador'),
  tecnico('Técnico'),
  supervisor('Supervisor'),
  admin('Administrador');

  const UserRole(this.label);
  final String label;

  /// Papel com permissão para tratar ocorrências gerais (sem área).
  bool get canOperate => this != operador;

  /// Administradores e supervisores têm gestão de todas as áreas.
  bool get managesAllAreas => this == admin || this == supervisor;

  static UserRole parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => UserRole.operador);
}

/// Origem do alerta: gerado por leitura de sensor ou cadastrado manualmente.
enum AlertOrigin {
  sensor('Gerado por sensor', Icons.sensors),
  manual('Cadastro manual', Icons.edit_note);

  const AlertOrigin(this.label, this.icon);
  final String label;
  final IconData icon;

  static AlertOrigin parse(String? v) => v == 'manual' ? manual : sensor;
}

/// Categoria (tipo de risco) do alerta.
enum AlertCategory {
  temperatura('Temperatura'),
  pressao('Pressão'),
  umidade('Umidade'),
  gas('Gases'),
  fumaca('Fumaça / incêndio'),
  ventilacao('Ventilação'),
  comunicacao('Comunicação'),
  eletrico('Elétrico'),
  mecanico('Mecânico'),
  quimico('Químico'),
  outro('Outro');

  const AlertCategory(this.label);
  final String label;

  static AlertCategory parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => AlertCategory.outro);
}

/// Nível de acesso de um funcionário a uma área (tabela area_members).
/// A ordem importa: cada nível inclui as permissões do anterior.
enum AccessLevel {
  nenhum('Sem acesso', 'Não visualiza áreas restritas'),
  leitura('Leitura', 'Visualiza sensores, alertas e ocorrências'),
  operacao('Operação', 'Trata alertas, cadastra alertas manuais e ações simuladas'),
  gestao('Gestão', 'Edita a área e exclui alertas manuais');

  const AccessLevel(this.label, this.description);
  final String label;
  final String description;

  bool operator >=(AccessLevel other) => index >= other.index;

  static AccessLevel parse(String? v) =>
      values.firstWhere((e) => e.name == v, orElse: () => AccessLevel.nenhum);
}
