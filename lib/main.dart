// main.dart
import 'package:flutter/material.dart';
import 'package:oauthclient/sceens/control_flow_screen.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

void main() {
  runApp(const ControlFlowApp());
}

class ControlFlowApp extends StatefulWidget {
  const ControlFlowApp({super.key});

  @override
  State<ControlFlowApp> createState() => _ControlFlowAppState();
}

class _ControlFlowAppState extends State<ControlFlowApp> {
  StepSettings _stepSettings = const StepSettings(
    processingDuration: Duration(seconds: 2),
    travelDuration: Duration(seconds: 2),
    timeoutDuration: Duration(seconds: 10),
  );

  String _appTitle = 'Control Flow Animation';

  void _updateStepSettings(StepSettings newSettings) {
    setState(() {
      _stepSettings = newSettings;
    });
  }

  void _updateTitle(String newTitle) {
    setState(() {
      _appTitle = newTitle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appTitle,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: InheritedAppTitle(
        onTitleChanged: _updateTitle,
        title: _appTitle,
        child: InheritedPaperSettings(
          paperSettings: PaperSettings(),
          child: InheritedStepSettings(
            stepSettings: _stepSettings,
            onSettingsChanged: _updateStepSettings,
            child: ControlFlowScreen(
              usePaper: true,
            ),
          ),
        ),
      ),
    );
  }
}

class InheritedAppTitle extends InheritedWidget {
  final String title;
  final ValueChanged<String> onTitleChanged;

  const InheritedAppTitle({
    super.key,
    required this.title,
    required this.onTitleChanged,
    required super.child,
  });

  static InheritedAppTitle? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<InheritedAppTitle>();
  }

  static InheritedAppTitle of(BuildContext context) {
    final InheritedAppTitle? result = maybeOf(context);
    assert(result != null, 'No InheritedAppTitle found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(InheritedAppTitle oldWidget) {
    return title != oldWidget.title;
  }
}
