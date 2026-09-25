import 'package:flutter/material.dart';

class AdministracaoPage extends StatefulWidget {
  const AdministracaoPage({super.key});

  @override
  State<AdministracaoPage> createState() => _AdministracaoPageState();
}

class _AdministracaoPageState extends State<AdministracaoPage> {
  @override
  Widget build(BuildContext context) {
    final adminCards = [
      _AdminCard(
        title: 'Usuários',
        subtitle: '12 colaboradores ativos',
        icon: Icons.group_outlined,
        color: const Color(0xFF0F5EC8),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gerenciamento de usuários aberto.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      _AdminCard(
        title: 'Permissões',
        subtitle: '5 regras em vigência',
        icon: Icons.security_outlined,
        color: const Color(0xFF2EAE7A),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuração de permissões carregada.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      _AdminCard(
        title: 'Manutenções',
        subtitle: '3 agendamentos pendentes',
        icon: Icons.build_circle_outlined,
        color: const Color(0xFFE4A93A),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agenda de manutenções atualizada.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
      _AdminCard(
        title: 'Auditoria',
        subtitle: 'Relatórios consolidados',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFF6F5EF5),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Relatório de auditoria gerado.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    ];

    final actions = [
      _ActionItem(title: 'Liberar acesso', icon: Icons.lock_open_rounded),
      _ActionItem(title: 'Revisar alarmes', icon: Icons.notification_important_outlined),
      _ActionItem(title: 'Gerar relatório', icon: Icons.print_outlined),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 360;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Administração',
                    style: TextStyle(
                      color: Color(0xFF1F2A37),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Controle operacional e governança da solução SafeCore.',
                    style: TextStyle(
                      color: Color(0xFF5E6C82),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isCompact ? 2 : 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: isCompact ? 1.2 : 1.5,
                    children: adminCards,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ações rápidas',
                    style: TextStyle(
                      color: Color(0xFF1F2A37),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
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
                    child: Column(
                      children: actions
                          .map(
                            (action) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ação: ${action.title} iniciada.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAF2FF),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        action.icon,
                                        color: const Color(0xFF0F5EC8),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        action.title,
                                        style: const TextStyle(
                                          color: Color(0xFF1F2A37),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF73839C),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
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

class _AdminCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2A37),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
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
    );
  }
}

class _ActionItem {
  final String title;
  final IconData icon;

  const _ActionItem({required this.title, required this.icon});
}
