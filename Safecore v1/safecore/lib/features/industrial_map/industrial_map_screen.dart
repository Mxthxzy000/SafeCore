import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/area.dart';
import '../../models/enums.dart';
import '../../repositories/repositories.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/cards.dart';
import '../../shared/widgets/safecore_app_bar.dart';
import '../areas/area_visuals.dart';

/// Mapa esquemático da planta: cada área é posicionada conforme
/// map_x/map_y/map_w/map_h (cadastrados no banco) e colorida pelo status.
class IndustrialMapScreen extends StatelessWidget {
  const IndustrialMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SafeCoreAppBar(title: 'Mapa da Planta'),
      body: AsyncLoader<List<Area>>(
        load: Repos.areas.fetchAll,
        builder: (context, areas, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'Toque em uma área para ver sensores, alertas e ações. '
                'Use dois dedos para ampliar.',
                style: AppText.bodySecondary,
              ),
              const SizedBox(height: 12),
              AccentCard(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 3,
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: PlantMap(
                        areas: areas,
                        onTapArea: (a) async {
                          await Navigator.pushNamed(context, AppRoutes.areaDetail, arguments: a.id);
                          await reload();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const _Legend(),
            ],
          ),
        ),
      ),
    );
  }
}

class PlantMap extends StatelessWidget {
  const PlantMap({super.key, required this.areas, required this.onTapArea});

  final List<Area> areas;
  final ValueChanged<Area> onTapArea;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _FloorPainter())),
            for (final a in areas)
              Positioned(
                left: a.mapX * w,
                top: a.mapY * h,
                width: a.mapW * w,
                height: a.mapH * h,
                child: _AreaBlock(area: a, onTap: () => onTapArea(a)),
              ),
          ],
        );
      },
    );
  }
}

class _AreaBlock extends StatelessWidget {
  const _AreaBlock({required this.area, required this.onTap});

  final Area area;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = area.status.style;
    final pulse = area.status == AreaStatus.critica;
    return Semantics(
      button: true,
      label: '${area.name}, ${style.label}',
      child: Material(
        color: style.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          side: BorderSide(color: style.color, width: pulse ? 2.5 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(areaTypeIcon(area.type), color: AppColors.primary, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    area.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 12, color: style.color),
                      const SizedBox(width: 2),
                      Text(style.label,
                          style: TextStyle(fontSize: 10, color: style.color, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Piso da planta: grade discreta, muro externo e vias internas.
class _FloorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F9FB));
    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 0.6;
    const step = 16.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final road = Paint()..color = AppColors.lightBlue.withValues(alpha: 0.25);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.21, size.width, size.height * 0.04), road);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.535, size.width, size.height * 0.04), road);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.775, size.width, size.height * 0.04), road);
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Paint()
        ..color = AppColors.slate.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Legenda',
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        children: [
          for (final s in AreaStatus.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: s.style.background,
                    border: Border.all(color: s.style.color, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                Text(s.style.label, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
        ],
      ),
    );
  }
}
