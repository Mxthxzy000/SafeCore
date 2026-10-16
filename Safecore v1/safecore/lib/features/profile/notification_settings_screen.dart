import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/profile.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';

/// Preferências de notificação salvas no banco (notification_preferences).
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _saving = false;

  Future<void> _update(NotificationPrefs prefs) async {
    setState(() => _saving = true);
    try {
      await SessionScope.read(context).savePrefs(prefs);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = SessionScope.of(context).prefs;
    final enabled = !_saving;

    Widget toggle(String title, String subtitle, bool value, NotificationPrefs Function(bool) change,
        {bool active = true}) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeThumbColor: AppColors.green,
        onChanged: enabled && active ? (v) => _update(change(v)) : null,
      );
    }

    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Notificações'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          AccentCard(
            child: Column(
              children: [
                toggle('Notificações', 'Ativar ou desativar todos os avisos', prefs.enabled,
                    (v) => prefs.copyWith(enabled: v)),
                const Divider(),
                toggle('Alertas críticos', 'Avisar imediatamente sobre riscos críticos',
                    prefs.criticalAlerts, (v) => prefs.copyWith(criticalAlerts: v),
                    active: prefs.enabled),
                toggle('Alertas de atenção', 'Avisar sobre valores fora da faixa segura',
                    prefs.warningAlerts, (v) => prefs.copyWith(warningAlerts: v),
                    active: prefs.enabled),
                toggle('Mural de avisos', 'Novos avisos e ocorrências das áreas',
                    prefs.occurrences, (v) => prefs.copyWith(occurrences: v),
                    active: prefs.enabled),
                toggle('Resumo diário', 'Resumo das condições da planta',
                    prefs.dailySummary, (v) => prefs.copyWith(dailySummary: v),
                    active: prefs.enabled),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Com o aplicativo aberto, novos alertas aparecem em tempo real conforme estas '
            'preferências. Notificações push com o app fechado exigem configuração do '
            'Firebase Cloud Messaging (ver README).',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}
