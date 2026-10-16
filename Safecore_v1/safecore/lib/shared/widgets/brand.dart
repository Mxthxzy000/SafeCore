import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';

/// Arquivos oficiais opcionais. Se existirem em `assets/images/`, substituem
/// os desenhos vetoriais abaixo (ver assets/images/LEIA-ME.txt).
abstract final class BrandAssets {
  static const logoPath = 'assets/images/logo.png';
  static const illustrationPath = 'assets/images/industrial.png';

  static bool hasLogo = false;
  static bool hasIllustration = false;

  static Future<void> detect() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      hasLogo = assets.contains(logoPath);
      hasIllustration = assets.contains(illustrationPath);
    } catch (_) {
      hasLogo = false;
      hasIllustration = false;
    }
  }
}

/// Logo do SafeCore (escudo com capacete e selo verde) para a barra azul.
class SafeCoreLogoMark extends StatelessWidget {
  const SafeCoreLogoMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    if (BrandAssets.hasLogo) {
      return Image.asset(BrandAssets.logoPath, width: size, height: size, fit: BoxFit.contain);
    }
    return Semantics(
      label: 'Logo SafeCore',
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48;
    canvas.save();
    canvas.scale(s);

    final stroke = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Escudo
    final shield = Path()
      ..moveTo(24, 5)
      ..lineTo(39, 10.5)
      ..lineTo(39, 22)
      ..cubicTo(39, 32.5, 32.5, 40, 24, 43.5)
      ..cubicTo(15.5, 40, 9, 32.5, 9, 22)
      ..lineTo(9, 10.5)
      ..close();
    canvas.drawPath(shield, stroke);

    // Capacete de segurança
    final helmet = Path()
      ..moveTo(15, 30)
      ..cubicTo(15, 22, 19, 18.5, 24, 18.5)
      ..cubicTo(29, 18.5, 33, 22, 33, 30);
    canvas.drawPath(helmet, stroke..strokeWidth = 2.2);
    canvas.drawLine(const Offset(13, 30.5), const Offset(35, 30.5), stroke);
    canvas.drawLine(const Offset(24, 18.5), const Offset(24, 24.5), stroke);
    canvas.drawLine(const Offset(20, 33.5), const Offset(28, 33.5), stroke..strokeWidth = 1.8);

    // Selo verde com check
    final badgeCenter = const Offset(37, 9);
    canvas.drawCircle(badgeCenter, 7.2, Paint()..color = AppColors.white);
    canvas.drawCircle(badgeCenter, 6, Paint()..color = AppColors.green);
    final check = Path()
      ..moveTo(33.8, 9.2)
      ..lineTo(36.2, 11.4)
      ..lineTo(40.2, 6.8);
    canvas.drawPath(
      check,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Marca "SafeCore — Monitoramento e Segurança" usada no Login e Cadastro.
class SafeCoreWordmark extends StatelessWidget {
  const SafeCoreWordmark({super.key, this.fontSize = 30});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SafeCore — Monitoramento e Segurança',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Safe', style: TextStyle(color: AppColors.primary)),
              TextSpan(text: 'Core', style: TextStyle(color: AppColors.green)),
            ]),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'MONITORAMENTO E SEGURANÇA',
            style: TextStyle(
              fontSize: fontSize * 0.21,
              color: AppColors.green,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustração industrial em traço (fundo das telas de Login e Cadastro).
class IndustrialIllustration extends StatelessWidget {
  const IndustrialIllustration({super.key, this.opacity = 1});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final child = BrandAssets.hasIllustration
        ? Image.asset(BrandAssets.illustrationPath, fit: BoxFit.contain,
            alignment: Alignment.bottomRight)
        : CustomPaint(painter: _IndustrialPainter(), size: Size.infinite);
    return IgnorePointer(child: Opacity(opacity: opacity, child: child));
  }
}

class _IndustrialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = AppColors.slate.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // Base
    final base = h * 0.96;
    canvas.drawLine(Offset(0, base), Offset(w, base), p);

    // Tanque vertical (direita)
    final tank = Rect.fromLTWH(w * 0.70, h * 0.45, w * 0.22, h * 0.51);
    canvas.drawRRect(RRect.fromRectAndRadius(tank, const Radius.circular(10)), p);
    for (var i = 1; i <= 4; i++) {
      final y = tank.top + tank.height * i / 5;
      canvas.drawLine(Offset(tank.left, y), Offset(tank.right, y), p);
    }
    // Escada do tanque
    final lx = tank.right + 6;
    canvas.drawLine(Offset(lx, tank.top + 8), Offset(lx, base), p);
    canvas.drawLine(Offset(lx + 8, tank.top + 8), Offset(lx + 8, base), p);
    for (var y = tank.top + 16; y < base; y += 10) {
      canvas.drawLine(Offset(lx, y), Offset(lx + 8, y), p);
    }

    // Máquina central com manômetro
    final machine = Rect.fromLTWH(w * 0.30, h * 0.62, w * 0.30, h * 0.34);
    canvas.drawRRect(RRect.fromRectAndRadius(machine, const Radius.circular(6)), p);
    final gauge = Offset(machine.center.dx, machine.top + machine.height * 0.38);
    final r = machine.width * 0.17;
    canvas.drawCircle(gauge, r, p);
    canvas.drawLine(gauge, gauge + Offset(r * 0.6, -r * 0.5), p);
    for (var i = 0; i < 3; i++) {
      final x = machine.left + machine.width * (0.2 + i * 0.3);
      canvas.drawCircle(Offset(x, machine.bottom - 12), 4, p);
    }

    // Tubulações ligando máquina e tanque
    final pipeY = h * 0.55;
    final pipe = Path()
      ..moveTo(machine.right - 14, machine.top)
      ..lineTo(machine.right - 14, pipeY)
      ..lineTo(tank.left, pipeY);
    canvas.drawPath(pipe, p);
    final pipe2 = Path()
      ..moveTo(machine.right - 6, machine.top)
      ..lineTo(machine.right - 6, pipeY + 8)
      ..lineTo(tank.left, pipeY + 8);
    canvas.drawPath(pipe2, p);
    // Flanges
    for (final x in [w * 0.64, w * 0.67]) {
      canvas.drawLine(Offset(x, pipeY - 4), Offset(x, pipeY + 12), p);
    }

    // Válvula (volante) à esquerda
    final valve = Offset(w * 0.16, h * 0.70);
    canvas.drawCircle(valve, w * 0.05, p);
    canvas.drawLine(valve - Offset(w * 0.05, 0), valve + Offset(w * 0.05, 0), p);
    canvas.drawLine(valve - Offset(0, w * 0.05), valve + Offset(0, w * 0.05), p);
    canvas.drawLine(valve + Offset(0, w * 0.05), Offset(valve.dx, base), p);
    final leftPipe = Path()
      ..moveTo(0, h * 0.82)
      ..lineTo(valve.dx, h * 0.82)
      ..moveTo(valve.dx, h * 0.86)
      ..lineTo(machine.left, h * 0.86);
    canvas.drawPath(leftPipe, p);

    // Chaminé
    final chimney = Rect.fromLTWH(w * 0.44, h * 0.30, w * 0.06, h * 0.32);
    canvas.drawRect(chimney, p);
    canvas.drawLine(Offset(chimney.left - 3, chimney.top), Offset(chimney.right + 3, chimney.top), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
