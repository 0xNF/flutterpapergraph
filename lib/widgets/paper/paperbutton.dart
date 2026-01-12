import 'package:flutter/material.dart';
import 'package:oauthclient/painters/paper.dart';
import 'package:oauthclient/widgets/paper/jitteredtext.dart';

CustomPaint buildPaperButton({
  required Widget label,
  required VoidCallback onPressed,
  required Color backgroundColor,
  required double drawingProgress,
  bool isOutlined = false,
}) {
  return CustomPaint(
    foregroundPainter: HandDrawnRectanglePainter(
      color: isOutlined ? Colors.grey[600]! : Colors.transparent,
      progress: drawingProgress,
      padding: 2.0,
    ),
    child: Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            // padding: EdgeInsets.zero,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: label,
          ),
        ),
      ),
    ),
  );
}

int _prog(double currentProgress) {
  final newSeed = (currentProgress * 3).floor();
  return newSeed;
}

CustomPaint buildPaperTextField({
  required TextEditingController controller,
  required String hintText,
  required double drawingProgress,
  Color? decorationColor,
  bool obscureText = false,
}) {
  return CustomPaint(
    foregroundPainter: HandDrawnRectanglePainter(
      progress: drawingProgress,
      padding: 4.0,
    ),
    child: Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: decorationColor, // Theme.of(context).canvasColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintStyle: TextStyle(color: Colors.grey[500]),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          hint: JitteredText(
            hintText,
            seed: _prog(drawingProgress),
            jitterAmount: 0.5,
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    ),
  );
}
