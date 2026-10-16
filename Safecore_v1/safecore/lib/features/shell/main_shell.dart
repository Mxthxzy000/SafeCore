import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/mqtt_service.dart';
import '../../services/session_controller.dart';
import '../alerts/alerts_screen.dart';
import '../areas/areas_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart';

/// Abas da navegação inferior (mesma ordem do Figma).
enum ShellTab { painel, areas, alertas, relatorios, perfil }

class _Tick extends ChangeNotifier {
  void fire() => notifyListeners();
}

/// Permite que as telas troquem de aba e peçam atualização dos dados.
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.state, required super.child});

  final MainShellState state;

  static MainShellState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellScope>()?.state;

  @override
  bool updateShouldNotify(ShellScope oldWidget) => false;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  ShellTab _tab = ShellTab.painel;
  final _ticks = {for (final t in ShellTab.values) t: _Tick()};
  RealtimeChannel? _channel;

  /// Notificador que a aba escuta para recarregar seus dados.
  Listenable refreshOf(ShellTab tab) => _ticks[tab]!;

  void goTo(ShellTab tab) {
    setState(() => _tab = tab);
    _ticks[tab]!.fire();
  }

  /// Recarrega todas as abas (ex.: após resolver um alerta ou receber telemetria MQTT).
  void refreshAll() {
    for (final t in _ticks.values) {
      t.fire();
    }
  }

  @override
  void initState() {
    super.initState();
    MqttService.instance.addListener(refreshAll);
    try {
      _channel = Repos.alerts.watchNew(_onNewAlert);
    } catch (_) {
      // Realtime indisponível: o app continua funcionando com atualização manual.
    }
  }

  void _onNewAlert(Map<String, dynamic> row) {
    if (!mounted) return;
    refreshAll();
    final prefs = SessionScope.read(context).prefs;
    final severity = AlertSeverity.parse(row['severity'] as String?);
    if (!prefs.allows(severity)) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: severity.style.color,
        duration: const Duration(seconds: 6),
        content: Text('Novo alerta ${severity.style.label.toLowerCase()}: ${row['title'] ?? ''}'),
        action: SnackBarAction(
          label: 'Ver',
          textColor: AppColors.white,
          onPressed: () async {
            await Navigator.pushNamed(context, AppRoutes.alertDetail, arguments: row['id']);
            refreshAll();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    MqttService.instance.removeListener(refreshAll);
    final channel = _channel;
    if (channel != null) Repos.alerts.stopWatching(channel);
    for (final t in _ticks.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      state: this,
      child: PopScope(
        canPop: _tab == ShellTab.painel,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) goTo(ShellTab.painel);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _tab.index,
            children: [
              DashboardScreen(refresh: refreshOf(ShellTab.painel)),
              AreasScreen(refresh: refreshOf(ShellTab.areas)),
              AlertsScreen(refresh: refreshOf(ShellTab.alertas)),
              ReportsScreen(refresh: refreshOf(ShellTab.relatorios)),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (i) => goTo(ShellTab.values[i]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Painel',
              ),
              NavigationDestination(
                icon: Icon(Icons.share_location_outlined),
                selectedIcon: Icon(Icons.share_location),
                label: 'Áreas',
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none),
                selectedIcon: Icon(Icons.notifications),
                label: 'Alertas',
              ),
              NavigationDestination(
                icon: Icon(Icons.insert_chart_outlined),
                selectedIcon: Icon(Icons.insert_chart),
                label: 'Relatórios',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
