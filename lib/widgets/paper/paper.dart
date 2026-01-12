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
