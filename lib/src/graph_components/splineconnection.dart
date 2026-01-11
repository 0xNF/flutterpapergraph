import 'package:flutter/material.dart';

class SplineEdge extends StatefulWidget {
  final Offset start;
  final Offset end;
  final List<Widget> animatedWidgets;

  const SplineEdge({
    super.key,
    required this.start,
    required this.end,
    this.animatedWidgets = const [],
  });

  @override
  State<SplineEdge> createState() => _SplineEdgeState();
}

class _SplineEdgeState extends State<SplineEdge> with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Offset _cubicBezier(Offset start, Offset end, double t) {
    // Control points for a smooth curve
    final cp1 = Offset(start.dx + (end.dx - start.dx) * 0.2, start.dy - 100);
    final cp2 = Offset(start.dx + (end.dx - start.dx) * 0.8, end.dy - 100);

    final mt = 1 - t;
    final mt2 = mt * mt;
    final mt3 = mt2 * mt;
    final t2 = t * t;
    final t3 = t2 * t;

    return Offset(
      mt3 * start.dx + 3 * mt2 * t * cp1.dx + 3 * mt * t2 * cp2.dx + t3 * end.dx,
      mt3 * start.dy + 3 * mt2 * t * cp1.dy + 3 * mt * t2 * cp2.dy + t3 * end.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SplinePainter(
        start: widget.start,
        end: widget.end,
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            children: [
              ...widget.animatedWidgets.map((widget) {
                final progress = _animationController.value;
                final position = _cubicBezier(
                  this.widget.start,
                  this.widget.end,
                  progress,
                );

                return Positioned(
                  left: position.dx - 12,
                  top: position.dy - 12,
                  child: widget,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _SplinePainter extends CustomPainter {
  final Offset start;
  final Offset end;

  _SplinePainter({
    required this.start,
    required this.end,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(start.dx, start.dy);

    final cp1 = Offset(start.dx + (end.dx - start.dx) * 0.2, start.dy - 100);
    final cp2 = Offset(start.dx + (end.dx - start.dx) * 0.8, end.dy - 100);

    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SplinePainter oldDelegate) => false;
}
