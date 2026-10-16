import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'services/mqtt_service.dart';
import 'services/supabase_service.dart';
import 'shared/widgets/brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  await BrandAssets.detect();

  var configured = false;
  Object? initError;
  try {
    configured = await SupabaseService.init();
  } catch (e) {
    initError = e;
  }

  // Inicia conexão com o broker público MQTT (sala safecore/quimex/caldeira)
  unawaited(MqttService.instance.init());

  runApp(SafeCoreApp(configured: configured, initError: initError));
}

void unawaited(Future<void> future) {}

