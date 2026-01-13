// authwidget.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:oauthclient/models/oauth/oauthclient.dart';
import 'package:oauthclient/painters/paper.dart';
import 'package:oauthclient/widgets/paper/jitteredtext.dart';
import 'package:oauthclient/widgets/paper/jitteredwidget.dart';
import 'package:oauthclient/widgets/paper/paper.dart';
import 'package:oauthclient/widgets/paper/paperbutton.dart';

class AuthorizeOAuthClientWidget extends StatefulWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final OAuthClient oauthClient;
  final bool usePaper;
  final PaperSettings? paperSettings;
  final Color borderColor;
  final Color backgroundColor;

  const AuthorizeOAuthClientWidget({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    required this.oauthClient,
    this.borderColor = const Color(0xFF78909C),
    this.backgroundColor = Colors.transparent,
    this.usePaper = true,
    this.paperSettings,
  });

  @override
  State<AuthorizeOAuthClientWidget> createState() => _AuthorizeOAuthClientWidgetState();
}

class _AuthorizeOAuthClientWidgetState extends State<AuthorizeOAuthClientWidget> with TickerProviderStateMixin {
  late AnimationController _drawingController;
  late AnimationController _vaporwaveController;
  late AnimationController _openingSquishController;
  late Animation<double> _openingSquishAnimation;

  double lastDrawingProgress = 0.0;
  final r = math.Random();
  late int jitterSeed;

  @override
  void initState() {
    super.initState();

    _openingSquishController = AnimationController(
      duration: const Duration(milliseconds: 75),
      vsync: this,
    );
    _openingSquishAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _openingSquishController, curve: Curves.easeInOutCubic),
    );

    if (widget.usePaper) {
      jitterSeed = widget.paperSettings?.newSeed() ?? 0;

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
          jitterSeed = (r.nextDouble() * 1000000).floor();
        }
        lastDrawingProgress = currentProgress;
      });
      _drawingController.repeat();

      _vaporwaveController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      )..repeat();
    }

    // Start opening animation immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openingSquishController.forward().then((_) => _openingSquishController.reverse());
    });
  }

  @override
  void dispose() {
    _openingSquishController.dispose();
    if (widget.usePaper) {
      _drawingController.dispose();
      _vaporwaveController.dispose();
    }
    super.dispose();
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
      constraints: BoxConstraints(maxWidth: 270),
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        backgroundColor: Colors.transparent,
        child: CustomPaint(
          foregroundPainter: HandDrawnRectanglePainter(
            color: widget.borderColor,
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
    const jitterAmount = 0.3;

    final icon = Icon(
      Icons.lock,
      size: 32,
      color: Colors.blue.shade600,
    );
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
            child: widget.usePaper
                ? AnimatedBuilder(
                    animation: _drawingController,
                    builder: (context, _) {
                      return JitteredWidget(
                        jitterAmount: jitterAmount,
                        seed: jitterSeed,
                        child: icon,
                      );
                    },
                  )
                : icon,
          ),

          // Client Name
          if (widget.usePaper) ...[
            AnimatedBuilder(
              animation: _drawingController,
              builder: (context, _) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      children: [
                        JitteredText(
                          widget.oauthClient.name,
                          jitterAmount: jitterAmount,
                          seed: jitterSeed,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        JitteredText(
                          "is requesting access\nto your",
                          jitterAmount: jitterAmount,
                          seed: jitterSeed,
                          textAlign: TextAlign.left,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[500]!,
                          ),
                        ),
                        JitteredText(
                          "instagram.com",
                          jitterAmount: jitterAmount,
                          seed: jitterSeed,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        JitteredText(
                          "account with\nthe following scopes",
                          jitterAmount: jitterAmount,
                          textAlign: TextAlign.left,
                          seed: jitterSeed,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.grey[500]!,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...widget.oauthClient.scopes.map(
                          (x) => JitteredText(
                            x,
                            style: TextStyle(color: Colors.white),
                            jitterAmount: jitterAmount,
                            seed: jitterSeed,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ] else ...[
            Text(widget.oauthClient.name),
            const SizedBox(height: 12),
          ],

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: widget.usePaper
                ? [
                    // Login Button
                    AnimatedBuilder(
                      animation: _drawingController,
                      builder: (context, _) {
                        return buildPaperButton(
                          drawingProgress: _drawingController.value,
                          label: JitteredText(
                            "Authorize",
                            jitterAmount: jitterAmount,
                            seed: jitterSeed,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: widget.onConfirm,
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
                            "Deny",
                            jitterAmount: jitterAmount,
                            seed: jitterSeed,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          onPressed: widget.onCancel,
                          backgroundColor: Colors.transparent,
                          isOutlined: true,
                        );
                      },
                    ),
                  ]
                : [
                    FilledButton(onPressed: widget.onConfirm, child: Text("Authorize")),
                    OutlinedButton(onPressed: widget.onCancel, child: Text("Deny")),
                  ],
          ),
        ],
      ),
    );

    final Widget w;

    if (widget.usePaper) {
      w = AnimatedBuilder(
        animation: _drawingController,
        builder: (context, _) {
          return _buildPaperBorder(context, innerContent);
        },
      );
    } else {
      w = _buildPaperBorder(context, innerContent);
    }

    return AnimatedBuilder(
      animation: _openingSquishController,
      builder: (context, _) {
        final squishValue = _openingSquishAnimation.value;
        final squishX = 1 + (squishValue * 0.1);
        final squishY = 1 - (squishValue * 0.3);
        return Transform.scale(
          scaleX: squishX,
          scaleY: squishY,

          child: w,
        );
      },
    );
  }
}
