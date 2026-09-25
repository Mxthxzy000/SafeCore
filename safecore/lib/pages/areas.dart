import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AreasPage extends StatefulWidget {
  const AreasPage({super.key});

  @override
  State<AreasPage> createState() => _AreasPageState();
}

class _AreasPageState extends State<AreasPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _factoryPlan;

  Future<void> _pickFactoryPlan() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 1600,
    );

    if (!mounted || pickedFile == null) {
      return;
    }

    setState(() {
      _factoryPlan = pickedFile;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Planta da fábrica carregada com sucesso.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAreaDetails(_AreaData area) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    area.name,
                    style: const TextStyle(
                      color: Color(0xFF1F2A37),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: area.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      area.status,
                      style: TextStyle(
                        color: area.statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoRow(icon: Icons.access_time_rounded, text: area.lastEvent),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.sensors_rounded, text: area.sensors),
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.shield_rounded, text: area.riskLevel),
              const SizedBox(height: 20),
              const Text(
                'Última ação:',
                style: TextStyle(
                  color: Color(0xFF1F2A37),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Inspeção automatizada foi concluída e sem ocorrências críticas registradas.',
                style: TextStyle(
                  color: Color(0xFF5E6C82),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Fluxo de ${area.name} foi aberto.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F5EC8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Abrir monitoramento',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final areas = [
      _AreaData(
        name: 'Portaria',
        status: 'Normal',
        statusColor: const Color(0xFF2EAE7A),
        lastEvent: 'Último acesso autorizado às 08:40',
        sensors: '4 sensores ativos',
        riskLevel: 'Baixo risco',
      ),
      _AreaData(
        name: 'Cozinha',
        status: 'Alerta',
        statusColor: const Color(0xFFE4A93A),
        lastEvent: 'Temperatura elevada há 12 min',
        sensors: '3 sensores ativos',
        riskLevel: 'Monitoramento ativo',
      ),
      _AreaData(
        name: 'Estacionamento',
        status: 'Crítico',
        statusColor: const Color(0xFFD94A4A),
        lastEvent: 'Sensor de fumaça acionado',
        sensors: '2 sensores ativos',
        riskLevel: 'Intervenção necessária',
      ),
      _AreaData(
        name: 'Laboratório',
        status: 'Normal',
        statusColor: const Color(0xFF2EAE7A),
        lastEvent: 'Uso estável e sem incidentes',
        sensors: '5 sensores ativos',
        riskLevel: 'Conformidade OK',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final mapPanel = Container(
              height: isDesktop ? 260 : 220,
              padding: const EdgeInsets.all(18),
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
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mapa das áreas',
                        style: TextStyle(
                          color: Color(0xFF1F2A37),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Mapa atualizado com sincronização automática.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('Atualizar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE1E7F0)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: _FactoryMapPainter()),
                          ),
                          Positioned(
                            left: 40,
                            top: 32,
                            child: _MapMarker(
                              label: 'Portaria',
                              color: const Color(0xFF2EAE7A),
                            ),
                          ),
                          Positioned(
                            left: 170,
                            top: 76,
                            child: _MapMarker(
                              label: 'Cozinha',
                              color: const Color(0xFFE4A93A),
                            ),
                          ),
                          Positioned(
                            left: 150,
                            top: 132,
                            child: _MapMarker(
                              label: 'Estacionamento',
                              color: const Color(0xFFD94A4A),
                            ),
                          ),
                          Positioned(
                            left: 260,
                            top: 40,
                            child: _MapMarker(
                              label: 'Laboratório',
                              color: const Color(0xFF2EAE7A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );

            final plantPanel = Container(
              height: isDesktop ? 260 : 260,
              padding: const EdgeInsets.all(18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Planta da fábrica',
                        style: TextStyle(
                          color: Color(0xFF1F2A37),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickFactoryPlan,
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Enviar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE1E7F0)),
                      ),
                      child: _factoryPlan != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                File(_factoryPlan!.path),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            )
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.maps_home_work_rounded,
                                    size: 42,
                                    color: Color(0xFF0F5EC8),
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Nenhuma planta carregada',
                                    style: TextStyle(
                                      color: Color(0xFF5E6C82),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Adicione a planta da fábrica para visualizar o layout operacional.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF7A8799),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            );

            return Padding(
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 28 : 20,
                isDesktop ? 24 : 18,
                isDesktop ? 28 : 20,
                isDesktop ? 32 : 28,
              ),
              child: ListView(
                children: [
                  const Text(
                    'Áreas monitoradas',
                    style: TextStyle(
                      color: Color(0xFF1F2A37),
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Status operacional por setor da infraestrutura.',
                    style: TextStyle(color: Color(0xFF5E6C82), fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: mapPanel),
                        const SizedBox(width: 18),
                        Expanded(child: plantPanel),
                      ],
                    )
                  else
                    Column(
                      children: [
                        mapPanel,
                        const SizedBox(height: 18),
                        plantPanel,
                      ],
                    ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: areas
                        .map(
                          (area) => SizedBox(
                            width: isDesktop
                                ? (constraints.maxWidth - 28 - 14) / 2
                                : constraints.maxWidth,
                            child: _AreaCard(
                              name: area.name,
                              status: area.status,
                              statusColor: area.statusColor,
                              lastEvent: area.lastEvent,
                              sensors: area.sensors,
                              riskLevel: area.riskLevel,
                              onTap: _showAreaDetails,
                            ),
                          ),
                        )
                        .toList(),
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

class _AreaData {
  final String name;
  final String status;
  final Color statusColor;
  final String lastEvent;
  final String sensors;
  final String riskLevel;

  _AreaData({
    required this.name,
    required this.status,
    required this.statusColor,
    required this.lastEvent,
    required this.sensors,
    required this.riskLevel,
  });
}

class _AreaCard extends StatelessWidget {
  final String name;
  final String status;
  final Color statusColor;
  final String lastEvent;
  final String sensors;
  final String riskLevel;
  final void Function(_AreaData area) onTap;

  const _AreaCard({
    required this.name,
    required this.status,
    required this.statusColor,
    required this.lastEvent,
    required this.sensors,
    required this.riskLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final areaData = _AreaData(
      name: name,
      status: status,
      statusColor: statusColor,
      lastEvent: lastEvent,
      sensors: sensors,
      riskLevel: riskLevel,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Color(0xFF1F2A37),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.access_time_rounded, text: lastEvent),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.sensors_rounded, text: sensors),
          const SizedBox(height: 8),
          _InfoRow(icon: Icons.shield_rounded, text: riskLevel),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onTap(areaData),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5EC8),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ver detalhes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final String label;
  final Color color;

  const _MapMarker({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1F2A37),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFE9F0F8);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFFD7E3F4)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (double y = 0; y <= size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final blockPaint = Paint()
      ..color = const Color(0xFFDBE6F8)
      ..style = PaintingStyle.fill;

    final blocks = [
      Rect.fromLTWH(24, 24, 120, 90),
      Rect.fromLTWH(160, 26, 150, 68),
      Rect.fromLTWH(120, 124, 190, 96),
      Rect.fromLTWH(250, 50, 110, 86),
    ];

    for (final block in blocks) {
      canvas.drawRect(block, blockPaint);
    }

    final corridorPaint = Paint()
      ..color = const Color(0xFFCED9EB)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 118, size.width, 28), corridorPaint);
    canvas.drawRect(Rect.fromLTWH(140, 0, 28, size.height), corridorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0F5EC8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF5E6C82), fontSize: 13),
          ),
        ),
      ],
    );
  }
}
