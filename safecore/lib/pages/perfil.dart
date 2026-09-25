import 'package:flutter/material.dart';

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  bool _notificationsEnabled = true;
  bool _emailSummaryEnabled = false;
  bool _autoSyncEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final profileCard = Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0F5EC8),
                          Color(0xFF2E91FF),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Ana Moura',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2A37),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Coordenadora de Segurança',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF5E6C82),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'ana.moura@safecore.com',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F5EC8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final summaryWrap = Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _MiniStatCard(label: 'Turno', value: '08:00-18:00'),
                _MiniStatCard(label: 'Zonas', value: '18 ativas'),
                _MiniStatCard(label: 'Alertas', value: '12 hoje'),
                _MiniStatCard(label: 'Status', value: 'Estável'),
              ],
            );

            final permissionsPanel = const _PermissionPanel();
            final preferencesPanel = _PreferencesPanel(
              notificationsEnabled: _notificationsEnabled,
              emailSummaryEnabled: _emailSummaryEnabled,
              autoSyncEnabled: _autoSyncEnabled,
              onNotificationsChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
              onEmailSummaryChanged: (value) {
                setState(() {
                  _emailSummaryEnabled = value;
                });
              },
              onAutoSyncChanged: (value) {
                setState(() {
                  _autoSyncEnabled = value;
                });
              },
            );

            final content = isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            profileCard,
                            const SizedBox(height: 20),
                            const Text(
                              'Resumo da operação',
                              style: TextStyle(
                                color: Color(0xFF1F2A37),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            summaryWrap,
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            permissionsPanel,
                            const SizedBox(height: 20),
                            const Text(
                              'Preferências',
                              style: TextStyle(
                                color: Color(0xFF1F2A37),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            preferencesPanel,
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      profileCard,
                      const SizedBox(height: 20),
                      const Text(
                        'Resumo da operação',
                        style: TextStyle(
                          color: Color(0xFF1F2A37),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      summaryWrap,
                      const SizedBox(height: 20),
                      const Text(
                        'Permissões',
                        style: TextStyle(
                          color: Color(0xFF1F2A37),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      permissionsPanel,
                      const SizedBox(height: 20),
                      const Text(
                        'Preferências',
                        style: TextStyle(
                          color: Color(0xFF1F2A37),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      preferencesPanel,
                    ],
                  );

            return Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 20,
                isDesktop ? 24 : 18,
                isDesktop ? 28 : 20,
                isDesktop ? 32 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perfil',
                    style: TextStyle(
                      color: Color(0xFF1F2A37),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: SingleChildScrollView(
                      child: content,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5E6C82),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1F2A37),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;

  const _PermissionRow({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1F2A37),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF5E6C82),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDFF5EC),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1F9D6A),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1F2A37),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Switch(
        value: value,
        activeThumbColor: const Color(0xFF0F5EC8),
        activeTrackColor: const Color(0xFF0F5EC8).withValues(alpha: 0.35),
        onChanged: onChanged,
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Column(
        children: [
          _PermissionRow(
            title: 'Acesso à operação',
            subtitle: 'Nível administrativo',
            value: 'Ativo',
          ),
          Divider(height: 24),
          _PermissionRow(
            title: 'Configuração de alertas',
            subtitle: 'Escalonamento e regras',
            value: 'Disponível',
          ),
          Divider(height: 24),
          _PermissionRow(
            title: 'Relatórios e auditoria',
            subtitle: 'Geração e exportação',
            value: 'Liberado',
          ),
        ],
      ),
    );
  }
}

class _PreferencesPanel extends StatelessWidget {
  final bool notificationsEnabled;
  final bool emailSummaryEnabled;
  final bool autoSyncEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final ValueChanged<bool> onEmailSummaryChanged;
  final ValueChanged<bool> onAutoSyncChanged;

  const _PreferencesPanel({
    required this.notificationsEnabled,
    required this.emailSummaryEnabled,
    required this.autoSyncEnabled,
    required this.onNotificationsChanged,
    required this.onEmailSummaryChanged,
    required this.onAutoSyncChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingRow(
            title: 'Notificações de risco',
            value: notificationsEnabled,
            onChanged: onNotificationsChanged,
          ),
          const Divider(height: 1),
          _SettingRow(
            title: 'Resumo diário por e-mail',
            value: emailSummaryEnabled,
            onChanged: onEmailSummaryChanged,
          ),
          const Divider(height: 1),
          _SettingRow(
            title: 'Sincronização automática',
            value: autoSyncEnabled,
            onChanged: onAutoSyncChanged,
          ),
        ],
      ),
    );
  }
}
