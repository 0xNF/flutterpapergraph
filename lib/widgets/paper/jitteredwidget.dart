import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:oauthclient/widgets/paper/jitteredtext.dart';

/// A widget that applies the same hand-drawn jitter effect to any child widget.
class JitteredWidget extends StatelessWidget {
  final Widget child;
  final int seed;
  final double jitterAmount;

  const JitteredWidget({
    super.key,
    required this.child,
    this.seed = 0,
    this.jitterAmount = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final random = math.Random(seed);
        final jitter = calculateJitter(random, jitterAmount);

        return Transform.translate(
          offset: jitter.offset,
          child: Transform.rotate(
            angle: jitter.angle,
            child: child,
          ),
        );
      },
    );
  }
}
