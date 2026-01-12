// loginwidget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:oauthclient/painters/paper.dart';
import 'package:oauthclient/widgets/paper/jitteredtext.dart';
import 'package:oauthclient/widgets/paper/paper.dart';
import 'package:oauthclient/widgets/paper/paperbutton.dart';

class LoginWidget extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String siteName;
  final bool usePaper;
  final PaperSettings? paperSettings;

  const LoginWidget({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    required this.siteName,
    this.usePaper = true,
    this.paperSettings,
  });

  @override
  State<LoginWidget> createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> with TickerProviderStateMixin {
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late AnimationController _drawingController;
  late AnimationController _vaporwaveController;
  late AnimationController _textEntryController;

  double lastDrawingProgress = 0.0;
  final r = math.Random();
  late int labelSeed;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();

    _textEntryController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    if (widget.usePaper) {
      labelSeed = widget.paperSettings?.newSeed() ?? 0;

      // Drawing animation controller - only needed for paper style
      _drawingController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      );

      _drawingController.addListener(() {
        final currentProgress = _drawingController.value;

        // Update labelSeed at the same cadence as HandDrawnRectangle
        // HandDrawnRectangle uses (progress * 3).floor() as its seed base
        final newSeed = (currentProgress * 3).floor();

        // Only update if the seed value changed
        if ((lastDrawingProgress * 3).floor() != newSeed) {
          labelSeed = (r.nextDouble() * 100).floor();
        }
        lastDrawingProgress = currentProgress;
      });
      _drawingController.repeat();

      _vaporwaveController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat();

      // Start text entry animation after initState completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTextEntryAnimation();
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _textEntryController.dispose();
    if (widget.usePaper) {
      _drawingController.dispose();
      _vaporwaveController.dispose();
    }
    super.dispose();
  }

  void _startTextEntryAnimation() {
    final usernameText = "demo@example.com";
    final passwordText = "password123";
    final totalChars = usernameText.length + passwordText.length;

    _textEntryController.addListener(() {
      final progress = _textEntryController.value;
      final charIndex = (progress * totalChars).floor();

      if (charIndex <= usernameText.length) {
        _usernameController.text = usernameText.substring(0, charIndex);
      } else {
        _usernameController.text = usernameText;
        final passwordChars = charIndex - usernameText.length;
        _passwordController.text = passwordText.substring(0, passwordChars);
      }
    });

    _textEntryController.forward();
  }

  Widget _buildPaperBorder(BuildContext context, Widget child) {
    const radius = 25.0;

    if (!widget.usePaper) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
    }

    final drawingProgress = _drawingController.value;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 260),
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        backgroundColor: Colors.transparent,
        child: CustomPaint(
          foregroundPainter: HandDrawnRectanglePainter(
            color: Colors.blueGrey[400]!,
            progress: drawingProgress,
          ),
          child: Container(
            margin: EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Theme.of(context).canvasColor,
              borderRadius: BorderRadius.circular(15),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final innerContent = Container(
      constraints: const BoxConstraints(
        maxWidth: 320,
        minWidth: 280,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo Icon - Top Centered
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            child: Icon(
              Icons.photo_camera_front,
              size: 32,
              color: Colors.blue.shade600,
            ),
          ),

          // Site Name
          AnimatedBuilder(
            animation: _drawingController,
            builder: (context, _) {
              return JitteredText(
                widget.siteName,
                jitterAmount: 0.5,
                seed: labelSeed,
                // seed: math.Random((_drawingController.value * 3).floor()).nextDouble().toInt(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey[500]!,
                ),
              );
            },
          ),

          // Username Field
          AnimatedBuilder(
            animation: _drawingController,
            builder: (context, _) {
              return buildPaperTextField(decorationColor: Theme.of(context).canvasColor, drawingProgress: _drawingController.value, controller: _usernameController, hintText: "Email");
            },
          ),

          AnimatedBuilder(
            animation: _drawingController,
            builder: (context, _) {
              return buildPaperTextField(decorationColor: Theme.of(context).canvasColor, drawingProgress: _drawingController.value, controller: _passwordController, hintText: "Password", obscureText: true);
            },
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Login Button
              AnimatedBuilder(
                animation: _drawingController,
                builder: (context, _) {
                  return buildPaperButton(
                    drawingProgress: _drawingController.value,
                    label: JitteredText(
                      "Login",
                      jitterAmount: 0.5,
                      seed: labelSeed,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onConfirm();
                    },
                    backgroundColor: Colors.blue.shade600,
                    isOutlined: true,
                  );
                },
              ),

              // Cancel Button
              AnimatedBuilder(
                animation: _drawingController,
                builder: (context, _) {
                  return buildPaperButton(
                    drawingProgress: _drawingController.value,
                    label: JitteredText(
                      "Cancel",
                      jitterAmount: 0.5,
                      seed: labelSeed,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onConfirm();
                    },

                    backgroundColor: Colors.transparent,
                    isOutlined: true,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.usePaper) {
      return AnimatedBuilder(
        animation: _drawingController,
        builder: (context, _) {
          return _buildPaperBorder(context, innerContent);
        },
      );
    } else {
      return _buildPaperBorder(context, innerContent);
    }
  }
}
