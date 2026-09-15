import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/inicial/tela_inicial_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Trava em retrato só no mobile (evita layout quebrado ao girar o aparelho).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
  runApp(const AdedanhaApp());
}

/// App raiz do Adedanha Offline.
class AdedanhaApp extends StatelessWidget {
  const AdedanhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adedanha Offline',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.claro(),
      home: const TelaInicial(),
    );
  }
}
