import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:safecore/core/utils/formatters.dart';
import 'package:safecore/core/utils/validators.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('Validators', () {
    test('e-mail', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('invalido'), isNotNull);
      expect(Validators.email('luiz.paulo@empresa.com'), isNull);
    });

    test('senha nova exige 8 caracteres com letras e números', () {
      expect(Validators.password('abc'), isNotNull);
      expect(Validators.password('abcdefgh'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('Senha123'), isNull);
    });

    test('nome', () {
      expect(Validators.name(' '), isNotNull);
      expect(Validators.name('Lu'), isNotNull);
      expect(Validators.name('Luiz Paulo'), isNull);
    });

    test('telefone é opcional mas validado', () {
      expect(Validators.phone(''), isNull);
      expect(Validators.phone('123'), isNotNull);
      expect(Validators.phone('(11) 99765-4321'), isNull);
    });
  });

  group('Fmt', () {
    test('medidas no padrão brasileiro', () {
      expect(Fmt.measure(58.7, '°C'), '58,7 °C');
      expect(Fmt.measure(1.4, 'bar'), '1,40 bar');
      expect(Fmt.measure(45.4, '%'), '45 %');
      expect(Fmt.measure(null, 'bar'), '—');
    });

    test('dia relativo', () {
      final now = DateTime(2026, 10, 9, 15);
      expect(Fmt.relativeDay(DateTime(2026, 10, 9, 10, 24), now: now), 'Hoje, 10:24');
      expect(Fmt.relativeDay(DateTime(2026, 10, 8, 18, 0), now: now), 'Ontem, 18:00');
      expect(Fmt.relativeDay(DateTime(2026, 10, 5, 9, 12), now: now), '05/10/2026, 09:12');
    });

    test('iniciais e nome curto', () {
      expect(Fmt.initials('Luiz Paulo Pereira'), 'LP');
      expect(Fmt.initials('Ana'), 'A');
      expect(Fmt.shortName('Luiz Paulo Pereira'), 'Luiz Paulo');
    });

    test('tempo decorrido', () {
      final now = DateTime(2026, 10, 9, 12);
      expect(Fmt.ago(now.subtract(const Duration(minutes: 5)), now: now), 'há 5 min');
      expect(Fmt.ago(now.subtract(const Duration(hours: 3)), now: now), 'há 3 h');
      expect(Fmt.ago(now.subtract(const Duration(days: 2)), now: now), 'há 2 dias');
    });
  });
}
