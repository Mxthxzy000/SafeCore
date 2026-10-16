import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:safecore/core/theme/app_theme.dart';
import 'package:safecore/features/areas/areas_screen.dart';
import 'package:safecore/features/auth/config_required_screen.dart';
import 'package:safecore/features/auth/login_screen.dart';
import 'package:safecore/models/area.dart';

Widget wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Login valida campos vazios sem chamar o servidor', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));

    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Avançar'), findsOneWidget);

    await tester.tap(find.text('Avançar'));
    await tester.pump();

    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
  });

  testWidgets('Login cabe em telas pequenas (320x568) sem overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tela de configuração orienta sobre o .env', (tester) async {
    await tester.pumpWidget(wrap(const ConfigRequiredScreen()));
    expect(find.text('Configuração do Supabase necessária'), findsOneWidget);
    expect(find.textContaining('service_role'), findsOneWidget);
  });

  testWidgets('Cartão de área mostra status e medições', (tester) async {
    final area = Area.fromMap({
      'id': '1',
      'code': 'CLD',
      'name': 'Caldeira',
      'area_type': 'caldeira',
      'status': 'critica',
      'sensors': [
        {
          'id': 's1',
          'area_id': '1',
          'code': 'CLD-TMP-01',
          'name': 'Temperatura Caldeira',
          'sensor_type': 'temperatura',
          'unit': '°C',
          'status': 'online',
          'level': 'critico',
          'last_value': 58.7,
        },
        {
          'id': 's2',
          'area_id': '1',
          'code': 'CLD-PRS-01',
          'name': 'Pressão Caldeira',
          'sensor_type': 'pressao',
          'unit': 'bar',
          'status': 'offline',
          'level': 'normal',
          'last_value': 1.12,
        },
      ],
    });

    await tester.pumpWidget(wrap(Scaffold(body: AreaCard(area: area))));

    expect(find.text('Caldeira'), findsOneWidget);
    expect(find.text('Crítica'), findsOneWidget);
    expect(find.text('58,7 °C'), findsOneWidget);
    // Sensor sem comunicação não exibe valor antigo
    expect(find.text('1,12 bar'), findsNothing);
    expect(find.text('Umidade'), findsOneWidget);
  });
}
