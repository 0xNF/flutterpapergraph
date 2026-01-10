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

  void _updateStepSettings(StepSettings newSettings) {
    setState(() {
      _stepSettings = newSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control Flow Animation',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: InheritedPaperSettings(
        paperSettings: PaperSettings(),
        child: InheritedStepSettings(
          stepSettings: _stepSettings,
          onSettingsChanged: _updateStepSettings,
          child: ControlFlowScreen(
            usePaper: true,
          ),
        ),
      ),
    );
  }
}
