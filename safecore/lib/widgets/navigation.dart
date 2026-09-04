import 'package:flutter/material.dart';

class NavigationBar extends StatefulWidget {
  @override
  State<NavigationBar> createState() => _NavigationBarState();
}

class _NavigationBarState extends State<NavigationBar>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late List<AnimationController> _controllers;

  final List<String> _labels = [
    'Painel',
    'Áreas',
    'Alertas',
    'Relatórios',
    'Perfil'
  ];

  final List<IconData> _icons = [
    Icons.desktop_mac,
    Icons.share,
    Icons.notifications,
    Icons.inventory_2,
    Icons.person
  ];

  final List<Widget> _pages = [
    Center(child: Text('Painel')),
    Center(child: Text('Áreas')),
    Center(child: Text('Alertas')),
    Center(child: Text('Relatórios')),
    Center(child: Text('Perfil')),
  ];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _icons.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 300),
        vsync: this,
      ),
    );
    _controllers[0].forward();
  }

  void _onItemTapped(int index) {
    _controllers[_selectedIndex].reverse();
    _controllers[index].forward();
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            _icons.length,
            (index) => _buildNavItem(index),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.3).animate(
        CurvedAnimation(parent: _controllers[index], curve: Curves.easeInOut),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: GestureDetector(
              onTap: () => _onItemTapped(index),
              child: Column(
                children: [
                  Icon(
                    _icons[index],
                    color: _selectedIndex == index
                        ? Colors.blue
                        : Colors.grey,
                    size: 28,
                  ),
                  SizedBox(height: 4),
                  AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    height: _selectedIndex == index ? 3 : 0,
                    width: 30,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Text(
            _labels[index],
            style: TextStyle(
              fontSize: 12,
              color: _selectedIndex == index
                  ? Colors.blue
                  : Colors.grey,
              fontWeight: _selectedIndex == index
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}