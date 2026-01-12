// models/graph_config.dart

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

class GraphConfig {
  final bool usePaper;
  final PaperSettings paperSettings;
  final EdgeSettings edgeSettings;
  final NodeSettings nodeSettings;
  final StepSettings stepSettings;

  const GraphConfig({
    this.usePaper = false,
    this.paperSettings = const PaperSettings(),
    this.edgeSettings = const EdgeSettings(),
    this.nodeSettings = const NodeSettings(),
    this.stepSettings = const StepSettings(),
  });

  GraphConfig copyWith({
    bool? usePaper,
    PaperSettings? paperSettings,
    EdgeSettings? edgeSettings,
    NodeSettings? nodeSettings,
    StepSettings? stepSettings,
  }) {
    return GraphConfig(
      usePaper: usePaper ?? this.usePaper,
      paperSettings: paperSettings ?? this.paperSettings,
      edgeSettings: edgeSettings ?? this.edgeSettings,
      nodeSettings: nodeSettings ?? this.nodeSettings,
      stepSettings: stepSettings ?? this.stepSettings,
    );
  }
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
  final Duration timeoutDuration;

  const StepSettings({
    this.processingDuration = const Duration(seconds: 2),
    this.travelDuration = const Duration(seconds: 2),
    this.timeoutDuration = const Duration(seconds: 10),
  });

  StepSettings copyWith({
    Duration? processingDuration,
    Duration? travelDuration,
    Duration? timeoutDuration,
  }) {
    return StepSettings(
      processingDuration: processingDuration ?? this.processingDuration,
      travelDuration: travelDuration ?? this.travelDuration,
      timeoutDuration: timeoutDuration ?? this.timeoutDuration,
    );
  }
}

class InheritedGraphConfigSettings extends InheritedWidget {
  final StepSettings stepSettings;
  final ValueChanged<StepSettings> onSettingsChanged;
  final ControlSettings controlSettings;
  final ValueChanged<ControlSettings> onControlSettingsChanged;

  const InheritedGraphConfigSettings({
    super.key,
    required this.stepSettings,
    required this.onSettingsChanged,
    required this.controlSettings,
    required this.onControlSettingsChanged,
    required super.child,
  });

  static InheritedGraphConfigSettings? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedGraphConfigSettings>();
  }

  static InheritedGraphConfigSettings of(BuildContext context) {
    final InheritedGraphConfigSettings? result = maybeOf(context);
    assert(result != null, 'No InheritedStepSettings found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(InheritedGraphConfigSettings oldWidget) {
    return stepSettings.processingDuration != oldWidget.stepSettings.processingDuration || stepSettings.travelDuration != oldWidget.stepSettings.travelDuration;
  }
}

/// An individual graphs properties superceed these ons. If the Grpah says "No Reset", then reset won't be shown. This is merely the base permissions.
class ControlSettings {
  final bool showTitle;
  final bool canChangeGraph;
  final bool showAutoRepeat;
  final bool showReset;
  final bool showBottomAppBar;
  final bool showStateManager;
  final bool showDebugger;
  final bool showFloatingControls;
  final bool showTopAppBar;
  final bool showDebugSettings;

  const ControlSettings({
    required this.showAutoRepeat,
    required this.showReset,
    required this.showBottomAppBar,
    required this.showStateManager,
    required this.showDebugger,
    required this.showTitle,
    required this.canChangeGraph,
    required this.showTopAppBar,
    required this.showFloatingControls,
    required this.showDebugSettings,
  });
}
