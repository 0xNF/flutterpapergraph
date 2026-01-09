import 'package:flutter/material.dart';
import 'package:oauthclient/sceens/control_flow_screen.dart';
import 'package:oauthclient/widgets/paper/paper.dart';

void main() {
  runApp(const ControlFlowApp());
}

class ControlFlowApp extends StatelessWidget {
  const ControlFlowApp({super.key});

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
        child: ControlFlowScreen(
          usePaper: true,
        ),
      ),
    );
  }
}
