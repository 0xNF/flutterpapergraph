import 'dart:ui' show VoidCallback;

import 'package:oauthclient/models/graph/connection.dart';

class AnimatedLabel {
  final String id;
  final String text;
  final ConnectionId connectionId;
  final Duration duration;
  final VoidCallback? onComplete;

  AnimatedLabel({
    required this.id,
    required this.text,
    required this.connectionId,
    required this.duration,
    this.onComplete,
  });
}
