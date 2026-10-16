import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../models/area.dart';
import '../../models/enums.dart';
import '../../models/profile.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/safecore_app_bar.dart';

/// Perfil com seções independentes: cada informação é editada e salva
/// separadamente, sem exigir a alteração dos demais dados.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Edita um único campo do perfil e salva somente ele.
  Future<void> _editField(
    BuildContext context, {
    required String title,
    required String label,
    required String initial,
    required String? Function(String?) validator,
    required Future<void> Function(String value) save,
    TextInputType? keyboardType,
    bool required = true,
  }) async {
    final value = await textInputDialog(
      context,
      title: title,
      label: label,
      initialValue: initial,
      maxLines: 1,
      keyboardType: keyboardType,
      required: required,
      validator: validator,
    );
    if (value == null || value == initial.trim() || !context.mounted) return;
    try {
      await save(value);
      await appSession.refreshProfile();
      if (context.mounted) showMessage(context, '$label atualizado(a).');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _changeEmail(BuildContext context, Profile profile) async {
    final email = await textInputDialog(
      context,
      title: 'Alterar e-mail',
      label: 'Novo e-mail',
      initialValue: profile.email,
      maxLines: 1,
      keyboardType: TextInputType.emailAddress,
      confirmLabel: 'Enviar confirmação',
      validator: Validators.email,
    );
    if (email == null || email == profile.email || !context.mounted) return;
    try {
      await Repos.auth.requestEmailChange(email);
      if (context.mounted) {
        showMessage(context, 'Enviamos um link de confirmação para $email. '
            'O e-mail será alterado após a confirmação.');
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Sair da conta',
      message: 'Deseja encerrar sua sessão neste aparelho?',
      confirmLabel: 'Sair',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Repos.auth.signOut();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final profile = session.profile;
    if (profile == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Perfil'),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await session.load();
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            AccentCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      Fmt.initials(profile.displayName),
                      style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: AppText.title),
                        Text(profile.email, style: AppText.bodySecondary),
                        const SizedBox(height: 2),
                        Text(profile.roleLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.slate)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Informações Pessoais',
              child: Column(
                children: [
                  _EditableRow(
                    icon: Icons.badge_outlined,
                    label: 'Nome completo',
                    value: profile.fullName.isEmpty ? 'Não informado' : profile.fullName,
                    onEdit: () => _editField(
                      context,
                      title: 'Nome completo',
                      label: 'Nome completo',
                      initial: profile.fullName,
                      keyboardType: TextInputType.name,
                      validator: Validators.name,
                      save: (v) => Repos.profile.update(fullName: v),
                    ),
                  ),
                  _EditableRow(
                    icon: Icons.mail_outline,
                    label: 'E-mail',
                    value: profile.email,
                    hint: 'Alteração confirmada por e-mail',
                    onEdit: () => _changeEmail(context, profile),
                  ),
                  _EditableRow(
                    icon: Icons.phone_outlined,
                    label: 'Telefone',
                    value: (profile.phone ?? '').isEmpty ? 'Não informado' : profile.phone!,
                    onEdit: () => _editField(
                      context,
                      title: 'Telefone',
                      label: 'Telefone',
                      initial: profile.phone ?? '',
                      keyboardType: TextInputType.phone,
                      required: false,
                      validator: Validators.phone,
                      save: (v) => Repos.profile.update(phone: v),
                    ),
                  ),
                  _EditableRow(
                    icon: Icons.work_outline,
                    label: 'Cargo ou função',
                    value: (profile.jobTitle ?? '').isEmpty ? 'Não informado' : profile.jobTitle!,
                    onEdit: () => _editField(
                      context,
                      title: 'Cargo ou função',
                      label: 'Cargo ou função',
                      initial: profile.jobTitle ?? '',
                      required: false,
                      validator: (v) => (v ?? '').length > 80 ? 'Máximo de 80 caracteres.' : null,
                      save: (v) => Repos.profile.update(jobTitle: v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _PermissionsCard(session: session),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Segurança e Notificações',
              child: Column(
                children: [
                  _EditableRow(
                    icon: Icons.lock_outline,
                    label: 'Senha',
                    value: '••••••••••',
                    hint: 'Pede a senha atual antes de alterar',
                    onEdit: () => Navigator.pushNamed(context, AppRoutes.changePassword),
                  ),
                  _EditableRow(
                    icon: Icons.notifications_none,
                    label: 'Preferências de notificação',
                    value: session.prefs.enabled ? 'Ativadas' : 'Desativadas',
                    valueColor: session.prefs.enabled ? AppColors.safe : AppColors.textSecondary,
                    onEdit: () => Navigator.pushNamed(context, AppRoutes.notifications),
                  ),
                ],
              ),
            ),
            if (session.canManageEmployees) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'Administração',
                child: _EditableRow(
                  icon: Icons.groups_outlined,
                  label: 'Funcionários e permissões',
                  value: session.canChangeRoles
                      ? 'Funções e acesso às áreas'
                      : 'Acesso dos funcionários às áreas',
                  editIcon: Icons.chevron_right,
                  onEdit: () => Navigator.pushNamed(context, AppRoutes.employees),
                ),
              ),
            ],
            const SizedBox(height: 14),
            AccentCard(
              accent: AppColors.critical,
              padding: EdgeInsets.zero,
              onTap: () => _signOut(context),
              child: const ListTile(
                leading: Icon(Icons.logout, color: AppColors.critical),
                title: Text('Sair da conta',
                    style: TextStyle(color: AppColors.critical, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Permissões do usuário (somente leitura; definidas por administradores).
class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final role = session.role;
    return SectionCard(
      title: 'Minhas Permissões',
      icon: Icons.admin_panel_settings_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(label: 'Função no sistema', value: role.label),
          if (role.managesAllAreas)
            const InfoRow(label: 'Áreas', value: 'Gestão de todas as áreas')
          else
            AsyncLoader<List<Area>>(
              load: Repos.areas.fetchAll,
              builder: (context, areas, _) {
                final mine = [
                  for (final a in areas)
                    if (session.areaLevels.containsKey(a.id)) (a.name, session.areaLevels[a.id]!),
                ];
                if (mine.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Você ainda não foi vinculado a nenhuma área. Áreas não restritas '
                      'podem ser visualizadas; para agir nelas, peça acesso a um administrador.',
                      style: AppText.caption,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final (name, level) in mine)
                      InfoRow(
                        label: name,
                        value: level.label,
                        valueColor: level == AccessLevel.gestao
                            ? AppColors.primary
                            : level == AccessLevel.operacao
                                ? AppColors.safe
                                : AppColors.textSecondary,
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 4),
          const Text('As permissões são definidas por administradores e supervisores.',
              style: AppText.caption),
        ],
      ),
    );
  }
}

/// Linha de informação com botão próprio de edição.
class _EditableRow extends StatelessWidget {
  const _EditableRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onEdit,
    this.valueColor,
    this.hint,
    this.editIcon = Icons.edit_outlined,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onEdit;
  final Color? valueColor;
  final String? hint;
  final IconData editIcon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(value, style: AppText.bodySecondary.copyWith(color: valueColor)),
                  if (hint != null) Text(hint!, style: AppText.small),
                ],
              ),
            ),
            if (onEdit != null)
              Icon(editIcon, size: 20, color: AppColors.slate, semanticLabel: 'Editar $label'),
          ],
        ),
      ),
    );
  }
}
