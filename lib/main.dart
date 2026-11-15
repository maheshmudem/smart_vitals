import 'package:flutter/material.dart';

import 'core/design_system/mirror_theme.dart';
import 'core/state/app_state.dart';
import 'features/shell/main_shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  runApp(VitalsMirrorApp(appState: appState));
}

/// Root widget for the VitalsMirror clinical & wellness screening application.
class VitalsMirrorApp extends StatelessWidget {
  final AppState appState;

  const VitalsMirrorApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          return MaterialApp(
            title: 'VitalsMirror — Clinical & Wellness Screening',
            debugShowCheckedModeBanner: false,
            theme: MirrorTheme.light(),
            darkTheme: MirrorTheme.dark(),
            themeMode: appState.themeMode,
            home: const MainShellScreen(),
          );
        },
      ),
    );
  }
}
