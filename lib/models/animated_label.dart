import 'dart:ui' show VoidCallback;

import 'package:oauthclient/models/graph/edge.dart';

class AnimatedLabel {
  final String id;
  final String text;
  final EdgeLink edgeLink;
  final String? edgeId;
  final Duration duration;
  final VoidCallback? onComplete;

  AnimatedLabel({
    required this.id,
    required this.text,
    required this.edgeLink,
    required this.duration,
    this.edgeId,
    this.onComplete,
  });
}
