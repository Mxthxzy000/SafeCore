import 'package:flutter_test/flutter_test.dart';
import 'package:safecore/models/alert.dart';
import 'package:safecore/models/enums.dart';
import 'package:safecore/models/profile.dart';
import 'package:safecore/repositories/repositories.dart';
import 'package:safecore/services/session_controller.dart';

Profile user(UserRole role) => Profile(id: 'u', fullName: 'Teste', email: 't@t.com', role: role);

Alert alert({required String areaId, required bool manual}) => Alert.fromMap({
      'id': 'a1',
      'area_id': areaId,
      'title': 'Alerta',
      'severity': 'atencao',
      'status': 'ativo',
      'detected_at': '2026-10-09T10:00:00Z',
      'origin': manual ? 'manual' : 'sensor',
      'category': 'mecanico',
    });

void main() {
  test('níveis de acesso são cumulativos', () {
    expect(AccessLevel.gestao >= AccessLevel.operacao, isTrue);
    expect(AccessLevel.operacao >= AccessLevel.leitura, isTrue);
    expect(AccessLevel.leitura >= AccessLevel.operacao, isFalse);
    expect(AccessLevel.parse('desconhecido'), AccessLevel.nenhum);
  });

  group('SessionController (espelha a função SQL area_access)', () {
    test('administrador e supervisor têm gestão em todas as áreas', () {
      for (final role in [UserRole.admin, UserRole.supervisor]) {
        final s = SessionController()..debugSet(user(role), const {});
        expect(s.levelFor('qualquer'), AccessLevel.gestao);
        expect(s.canCreateAreas, isTrue);
        expect(s.canDeleteAreas, isTrue);
        expect(s.canManageEmployees, isTrue);
      }
      expect((SessionController()..debugSet(user(UserRole.admin), const {})).canChangeRoles, isTrue);
      expect((SessionController()..debugSet(user(UserRole.supervisor), const {})).canChangeRoles, isFalse);
    });

    test('técnico atua somente nas áreas vinculadas', () {
      final s = SessionController()
        ..debugSet(user(UserRole.tecnico), {'cld': AccessLevel.gestao, 'lab': AccessLevel.leitura});
      expect(s.canManageArea('cld'), isTrue);
      expect(s.canOperateArea('lab'), isFalse);
      expect(s.canOperateArea('esc'), isFalse, reason: 'sem vínculo = somente leitura');
      expect(s.canCreateAreas, isFalse);
      expect(s.canDeleteAreas, isFalse);
      expect(s.canManageEmployees, isFalse);
      expect(s.canCreateAlerts, isTrue);
    });

    test('operador sem vínculo apenas visualiza', () {
      final s = SessionController()..debugSet(user(UserRole.operador), const {});
      expect(s.levelFor('prd'), AccessLevel.leitura);
      expect(s.canCreateAlerts, isFalse);
      expect(s.canOperateGeneral, isFalse);
    });

    test('exclusão de alertas: manual com gestão; de sensor só administrador', () {
      final tec = SessionController()
        ..debugSet(user(UserRole.tecnico), {'cld': AccessLevel.gestao, 'prd': AccessLevel.operacao});
      expect(tec.canDeleteAlert(alert(areaId: 'cld', manual: true)), isTrue);
      expect(tec.canDeleteAlert(alert(areaId: 'cld', manual: false)), isFalse);
      expect(tec.canDeleteAlert(alert(areaId: 'prd', manual: true)), isFalse);
      expect(tec.canEditAlert(alert(areaId: 'prd', manual: false)), isTrue);

      final admin = SessionController()..debugSet(user(UserRole.admin), const {});
      expect(admin.canDeleteAlert(alert(areaId: 'cld', manual: false)), isTrue);
    });
  });

  group('Dados enviados ao banco', () {
    test('AreaInput normaliza código e campos vazios', () {
      final map = const AreaInput(
        code: ' mnt ',
        name: ' Oficina ',
        type: 'producao',
        status: 'segura',
        description: '  ',
      ).toMap();
      expect(map['code'], 'MNT');
      expect(map['name'], 'Oficina');
      expect(map['description'], isNull);
      expect(map['restricted'], isFalse);
    });

    test('AlertInput usa os valores do banco para status e categoria', () {
      final map = AlertInput(
        areaId: 'a',
        title: 'Vazamento',
        severity: AlertSeverity.critico,
        status: AlertStatus.emAndamento,
        category: AlertCategory.quimico,
        detectedAt: DateTime.utc(2026, 10, 9, 12),
        detectedValue: 3.5,
        unit: 'ppm',
      ).toMap();
      expect(map['status'], 'em_andamento');
      expect(map['severity'], 'critico');
      expect(map['category'], 'quimico');
      expect(map['detected_at'], '2026-10-09T12:00:00.000Z');
      expect(map.containsKey('origin'), isFalse, reason: 'a origem é definida pelo banco');
      expect(map.containsKey('sensor_id'), isFalse);
    });

    test('origem do alerta', () {
      expect(alert(areaId: 'x', manual: true).isManual, isTrue);
      expect(AlertOrigin.parse(null), AlertOrigin.sensor);
    });
  });
}
