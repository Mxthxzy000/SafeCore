import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/profile.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../services/session_controller.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../../shared/widgets/search_field.dart';

/// Lista de funcionários (administradores e supervisores).
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _loaderKey = GlobalKey<AsyncLoaderState<List<Profile>>>();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = SessionScope.of(context).profile?.id;
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Funcionários'),
      body: AsyncLoader<List<Profile>>(
        key: _loaderKey,
        load: Repos.permissions.fetchEmployees,
        builder: (context, people, reload) {
          final q = _query.trim().toLowerCase();
          final filtered = people
              .where((p) =>
                  q.isEmpty ||
                  p.displayName.toLowerCase().contains(q) ||
                  p.email.toLowerCase().contains(q))
              .toList();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                SearchField(hint: 'Buscar funcionário...', onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: 10),
                const Text(
                  'Toque em um funcionário para definir a função e o acesso a cada área. '
                  'Novos cadastros entram como Operador, sem privilégios administrativos.',
                  style: AppText.caption,
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  const EmptyView(message: 'Nenhum funcionário encontrado.', icon: Icons.person_search)
                else
                  for (final p in filtered) ...[
                    AccentCard(
                      accent: p.role.managesAllAreas ? AppColors.primary : AppColors.lightBlue,
                      onTap: () async {
                        await Navigator.pushNamed(context, AppRoutes.employeeDetail, arguments: p.id);
                        await reload();
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(Fmt.initials(p.displayName),
                                style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.id == me ? '${p.displayName} (você)' : p.displayName,
                                    style: AppText.itemTitle),
                                Text(p.email, style: AppText.caption),
                                if ((p.jobTitle ?? '').isNotEmpty) Text(p.jobTitle!, style: AppText.caption),
                              ],
                            ),
                          ),
                          RoleChip(role: p.role.label),
                          const Icon(Icons.chevron_right, color: AppColors.slate),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.lightBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role,
          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
    );
  }
}
