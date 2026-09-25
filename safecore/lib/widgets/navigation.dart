import 'package:flutter/material.dart';

import '../pages/administracao.dart';
import '../pages/alertas.dart';
import '../pages/areas.dart';
import '../pages/painel.dart';
import '../pages/perfil.dart';
import '../pages/relatorios.dart';

class NavigationBar extends StatefulWidget {
  const NavigationBar({super.key});

  @override
  State<NavigationBar> createState() => _NavigationBarState();
}

class _NavigationBarState extends State<NavigationBar>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late final List<AnimationController> _controllers;

  final List<String> _labels = [
    'Painel',
    'Áreas',
    'Alertas',
    'Relatórios',
    'Admin',
    'Perfil',
  ];

  final List<IconData> _icons = [
    Icons.dashboard_outlined,
    Icons.location_on_outlined,
    Icons.notifications_active_outlined,
    Icons.bar_chart_rounded,
    Icons.admin_panel_settings_outlined,
    Icons.person_outline,
  ];

  final List<Widget> _pages = const [
    PainelPage(),
    AreasPage(),
    AlertasPage(),
    RelatoriosPage(),
    AdministracaoPage(),
    PerfilPage(),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _icons.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 260),
        vsync: this,
      ),
    );
    _controllers[0].forward();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      _controllers[_selectedIndex].reverse();
      _controllers[index].forward();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  backgroundColor: const Color(0xFFF8FBFF),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(
                    color: Color(0xFF0F5EC8),
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: Color(0xFF7A8799),
                  ),
                  destinations: [
                    for (int i = 0; i < _labels.length; i++)
                      NavigationRailDestination(
                        icon: Icon(_icons[i]),
                        label: Text(_labels[i]),
                      ),
                  ],
                ),
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: _pages[_selectedIndex],
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    _icons.length,
                    (index) => _buildNavItem(index),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;

    return AnimatedBuilder(
      animation: _controllers[index],
      builder: (context, child) {
        return Transform.scale(
          scale: 1 + (_controllers[index].value * 0.12),
          child: GestureDetector(
            onTap: () => _onItemTapped(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0F5EC8).withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _icons[index],
                    color: isSelected
                        ? const Color(0xFF0F5EC8)
                        : const Color(0xFF7A8799),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _labels[index],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? const Color(0xFF0F5EC8)
                          : const Color(0xFF7A8799),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}