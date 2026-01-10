import 'dart:math';
import 'package:flutter/material.dart';

class InheritedPaperSettings extends InheritedWidget {
  final PaperSettings paperSettings;

  const InheritedPaperSettings({
    super.key,
    required this.paperSettings,
    required super.child,
  });

  @override
  bool updateShouldNotify(InheritedPaperSettings oldWidget) => oldWidget.hashCode != hashCode;

  static PaperSettings of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<InheritedPaperSettings>();
    assert(result != null, 'No InheritedPaperSettings found in context');
    return result!.paperSettings;
  }
}

class PaperSettings {
  final Duration frameDuration;
  final NodePaperSettings nodeSettings;
  final EdgePaperSettings edgeSettings;
  final ArrowPaperSettings arrowSettings;

  const PaperSettings({
    this.nodeSettings = const NodePaperSettings(),
    this.edgeSettings = const EdgePaperSettings(),
    this.frameDuration = const Duration(milliseconds: 500),
    this.arrowSettings = const ArrowPaperSettings(),
  });

  int newSeed([int initialzer = 0]) {
    return DateTime.now().microsecondsSinceEpoch + initialzer;
  }
}

class EdgePaperSettings {
  final double segmentlength;
  final double noiseAmount;

  const EdgePaperSettings({
    this.segmentlength = 3.0,
    this.noiseAmount = 0.3,
  });
}

class NodePaperSettings {
  final Duration borderFrameDuration;

  const NodePaperSettings({
    this.borderFrameDuration = const Duration(milliseconds: 500),
  });
}

class ArrowPaperSettings {
  final double segmentLength;
  final double noiseAmount;
  final double sizeVariationAsPercent;
  final double originJitter;
  final double startJitter;

  const ArrowPaperSettings({
    this.segmentLength = 2.0,
    this.noiseAmount = 0.4,
    this.sizeVariationAsPercent = 0.15,
    this.originJitter = 1.5,
    this.startJitter = 0.8,
  });
}

class GraphSettings {
  const GraphSettings();
}

class EdgeSettings {
  final Color idleColor;
  final Color disabledColor;
  final Color errorColor;
  final Color inProgressColor;
  final ArrowSettings arrowSettings;
  final double strokeWidth;

  const EdgeSettings({
    this.idleColor = const Color(0xFF64B5F6),
    this.inProgressColor = const Color(0xFF64B5F6),
    this.disabledColor = const Color(0xFF303030),
    this.errorColor = Colors.red,
    this.arrowSettings = const ArrowSettings(),
    this.strokeWidth = 2.5,
  });
}

class ArrowSettings {
  final Color color;
  final double size;
  final double angle;
  final PaintingStyle paintingStyle;
  final double strokeWidth;

  const ArrowSettings({
    this.color = const Color(0xFF64B5F6),
    this.size = 24,
    this.angle = pi / 6,
    this.paintingStyle = PaintingStyle.fill,
    this.strokeWidth = 2.5,
  });
}

class NodeSettings {
  final TextStyle floatingTextStyle;
  final Duration floatingTextDurationDefault;

  const NodeSettings({
    this.floatingTextDurationDefault = const Duration(milliseconds: 1500),
    this.floatingTextStyle = const TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold),
  });
}

class StepSettings {
  final Duration processingDuration;
  final Duration travelDuration;

  const StepSettings({required this.processingDuration, required this.travelDuration});
}
