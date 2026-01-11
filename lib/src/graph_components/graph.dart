import 'package:flutter/material.dart';

enum NodeState {
  /// node is idle, not doing anything
  unselected,

  /// Node has been selected. This has been largely repurposed to mean "recently finished computation"
  selected,

  /// Currently undergoing computation
  inProgress,

  /// Node encounteed some kind of error
  error,

  /// Node cannot be used, but it is still drawn on the Graph
  disabled,
}

class NodeContents {
  final String stepTitle;
  final TextStyle textStyle;

  const NodeContents({
    required this.stepTitle,
    this.textStyle = const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
  });
}
