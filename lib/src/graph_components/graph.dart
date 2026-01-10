import 'package:flutter/material.dart';

enum NodeState { unselected, selected, inProgress, error, disabled }

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
