import 'package:flutter/widgets.dart';

import '../models/alert.dart';
import '../models/enums.dart';
import '../models/profile.dart';
import '../repositories/repositories.dart';

/// Guarda o perfil e as preferências do usuário logado para todas as telas.
class SessionController extends ChangeNotifier {
  Profile? _profile;
  NotificationPrefs _prefs = const NotificationPrefs();
  Map<String, AccessLevel> _areaLevels = const {};

  Profile? get profile => _profile;
  NotificationPrefs get prefs => _prefs;
  UserRole get role => _profile?.role ?? UserRole.operador;

  /// Vínculos do usuário com as áreas (id da área -> nível).
  Map<String, AccessLevel> get areaLevels => _areaLevels;

  // ---------------------------------------------------------------------
  // Permissões. Espelham a função SQL `area_access`; o banco é quem decide
  // (RLS), a interface só evita oferecer ações que seriam negadas.
  // ---------------------------------------------------------------------

  /// Nível do usuário na área. Áreas listadas já são visíveis (leitura mínima).
  AccessLevel levelFor(String areaId) {
    if (role.managesAllAreas) return AccessLevel.gestao;
    return _areaLevels[areaId] ?? AccessLevel.leitura;
  }

  bool canOperateArea(String areaId) => levelFor(areaId) >= AccessLevel.operacao;
  bool canManageArea(String areaId) => levelFor(areaId) >= AccessLevel.gestao;

  /// Pode cadastrar alertas em ao menos uma área.
  bool get canCreateAlerts =>
      role.managesAllAreas || _areaLevels.values.any((l) => l >= AccessLevel.operacao);

  bool get canCreateAreas => role.managesAllAreas;
  bool get canDeleteAreas => role.managesAllAreas;
  bool get canManageEmployees => role.managesAllAreas;
  bool get canChangeRoles => role == UserRole.admin;

  /// Ocorrências e avisos gerais (sem área) seguem o papel do usuário.
  bool get canOperateGeneral => role.canOperate;

  bool canEditAlert(Alert alert) => canOperateArea(alert.areaId);

  bool canDeleteAlert(Alert alert) =>
      role == UserRole.admin || (alert.isManual && canManageArea(alert.areaId));

  Future<void> load() async {
    _profile = await Repos.profile.fetchMine();
    try {
      _prefs = await Repos.profile.fetchPrefs();
    } catch (_) {
      _prefs = const NotificationPrefs();
    }
    await _loadAreaLevels();
    notifyListeners();
  }

  Future<void> _loadAreaLevels() async {
    try {
      final members = await Repos.permissions.fetchMine();
      _areaLevels = {for (final m in members) m.areaId: m.level};
    } catch (_) {
      _areaLevels = const {}; // banco sem a migração 002
    }
  }

  /// Recarrega perfil e permissões (ex.: após um administrador alterar o acesso).
  Future<void> refreshPermissions() async {
    _profile = await Repos.profile.fetchMine();
    await _loadAreaLevels();
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    _profile = await Repos.profile.fetchMine();
    notifyListeners();
  }

  Future<void> savePrefs(NotificationPrefs prefs) async {
    await Repos.profile.savePrefs(prefs);
    _prefs = prefs;
    notifyListeners();
  }

  /// Define perfil e vínculos sem acessar o banco (usado nos testes).
  @visibleForTesting
  void debugSet(Profile profile, Map<String, AccessLevel> areaLevels) {
    _profile = profile;
    _areaLevels = areaLevels;
    notifyListeners();
  }

  void clear() {
    _profile = null;
    _areaLevels = const {};
    _prefs = const NotificationPrefs();
    notifyListeners();
  }
}

/// Sessão única do aplicativo.
final appSession = SessionController();

/// Disponibiliza o [SessionController] na árvore de widgets.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({super.key, required SessionController controller, required super.child})
      : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope não encontrado');
    return scope!.notifier!;
  }

  /// Acesso sem registrar dependência (para callbacks).
  static SessionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<SessionScope>();
    return scope!.notifier!;
  }
}
