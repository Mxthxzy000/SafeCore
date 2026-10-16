import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/area.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../repositories/repositories.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';

class _EmployeeData {
  const _EmployeeData(this.profile, this.areas, this.levels);

  final Profile profile;
  final List<Area> areas;
  final Map<String, AccessLevel> levels;
}

/// Função no sistema e permissões por área de um funcionário.
/// Cada alteração é salva imediatamente e validada no banco.
class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  final _loaderKey = GlobalKey<AsyncLoaderState<_EmployeeData>>();
  String? _busyKey;

  Future<_EmployeeData> _load() async {
    final (profile, areas, members) = await (
      Repos.permissions.fetchEmployee(widget.userId),
      Repos.areas.fetchAll(),
      Repos.permissions.fetchMembersOf(widget.userId),
    ).wait;
    return _EmployeeData(profile, areas, {for (final m in members) m.areaId: m.level});
  }

  Future<void> _run(String key, Future<void> Function() task, String success) async {
    setState(() => _busyKey = key);
    try {
      await task();
      if (!mounted) return;
      showMessage(context, success);
      await _loaderKey.currentState?.reload();
      // Se o usuário alterou as próprias permissões, atualiza a sessão
      if (widget.userId == appSession.profile?.id) await appSession.refreshPermissions();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busyKey = null);
    }
  }

  Future<void> _changeRole(Profile p, UserRole role) async {
    if (role == p.role) return;
    final ok = await confirmDialog(
      context,
      title: 'Alterar função',
      message: 'Alterar ${p.displayName} de "${p.role.label}" para "${role.label}"?'
          '${role.managesAllAreas ? '\n\nEssa função terá acesso de gestão a TODAS as áreas.' : ''}',
      confirmLabel: 'Alterar',
      destructive: role == UserRole.admin,
    );
    if (!ok) return;
    await _run('role', () => Repos.permissions.setRole(p.id, role), 'Função alterada para ${role.label}.');
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Permissões'),
      body: AsyncLoader<_EmployeeData>(
        key: _loaderKey,
        load: _load,
        builder: (context, data, reload) {
          final p = data.profile;
          final isMe = p.id == session.profile?.id;
          final canChangeRole = session.canChangeRoles && !isMe;
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                AccentCard(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.primary,
                        child: Text(Fmt.initials(p.displayName),
                            style: const TextStyle(color: AppColors.white, fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.displayName, style: AppText.title),
                            Text(p.email, style: AppText.caption),
                            if ((p.jobTitle ?? '').isNotEmpty) Text(p.jobTitle!, style: AppText.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Função no sistema',
                  icon: Icons.admin_panel_settings_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<UserRole>(
                        key: ValueKey(p.role),
                        initialValue: p.role,
                        isExpanded: true,
                        items: [
                          for (final r in UserRole.values)
                            DropdownMenuItem(value: r, child: Text(r.label)),
                        ],
                        onChanged: canChangeRole && _busyKey == null
                            ? (r) => r == null ? null : _changeRole(p, r)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isMe
                            ? 'Você não pode alterar a sua própria função.'
                            : !session.canChangeRoles
                                ? 'Somente administradores alteram a função.'
                                : _roleHelp(p.role),
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Acesso por área',
                  icon: Icons.share_location_outlined,
                  child: p.role.managesAllAreas
                      ? Text(
                          '${p.role.label}es têm acesso de gestão a todas as áreas automaticamente.',
                          style: AppText.bodySecondary,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Áreas não restritas podem ser visualizadas por todos. '
                              'Áreas restritas exigem ao menos acesso de leitura.',
                              style: AppText.caption,
                            ),
                            const SizedBox(height: 8),
                            for (final a in data.areas)
                              _AreaLevelRow(
                                area: a,
                                level: data.levels[a.id] ?? AccessLevel.nenhum,
                                maxLevel: p.role == UserRole.operador
                                    ? AccessLevel.operacao
                                    : AccessLevel.gestao,
                                busy: _busyKey == a.id,
                                enabled: _busyKey == null,
                                onChanged: (level) => _run(
                                  a.id,
                                  () => Repos.permissions.setAreaLevel(p.id, a.id, level),
                                  '${a.name}: ${level.label}.',
                                ),
                              ),
                            const SizedBox(height: 8),
                            const _LevelLegend(),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _roleHelp(UserRole role) => switch (role) {
        UserRole.admin => 'Gerencia funcionários, funções, áreas e alertas.',
        UserRole.supervisor => 'Gerencia áreas, alertas e o acesso dos funcionários às áreas.',
        UserRole.tecnico => 'Atua nas áreas em que tiver acesso de operação ou gestão.',
        UserRole.operador => 'Visualiza as áreas e executa apenas as ações autorizadas.',
      };
}

class _AreaLevelRow extends StatelessWidget {
  const _AreaLevelRow({
    required this.area,
    required this.level,
    required this.maxLevel,
    required this.busy,
    required this.enabled,
    required this.onChanged,
  });

  final Area area;
  final AccessLevel level;
  final AccessLevel maxLevel;
  final bool busy;
  final bool enabled;
  final ValueChanged<AccessLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(area.name, style: AppText.itemTitle),
                if (area.restricted)
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 13, color: AppColors.blocked),
                      SizedBox(width: 3),
                      Text('Restrita', style: TextStyle(fontSize: 11.5, color: AppColors.blocked)),
                    ],
                  ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<AccessLevel>(
                key: ValueKey('${area.id}-${level.name}'),
                initialValue: level,
                isExpanded: true,
                isDense: true,
                items: [
                  for (final l in AccessLevel.values)
                    if (!(l.index > maxLevel.index))
                      DropdownMenuItem(
                        value: l,
                        child: Text(
                          // Sem vínculo, áreas não restritas continuam visíveis
                          l == AccessLevel.nenhum && !area.restricted ? 'Padrão (leitura)' : l.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                ],
                onChanged: enabled ? (l) => l == null || l == level ? null : onChanged(l) : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelLegend extends StatelessWidget {
  const _LevelLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in AccessLevel.values.skip(1))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${l.label}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: l.description),
                ]),
                style: AppText.caption,
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('Operadores podem receber no máximo acesso de operação.', style: AppText.caption),
          ),
        ],
      ),
    );
  }
}
