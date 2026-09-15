import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config_sala/config_sala_screen.dart';
import '../lobby/lobby_screen.dart';

/// Tela inicial: escolhe entre criar uma sala (host) ou entrar numa (convidado).
class TelaInicial extends StatelessWidget {
  const TelaInicial({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Adedanha Offline',
              style: TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfigSalaScreen()),
              ),
              child: const Text('Criar sala'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LobbyScreen(ehHost: false),
                ),
              ),
              child: const Text('Entrar em uma sala'),
            ),
            const SizedBox(height: 12),
            // Sai do app (Android; iOS ignora por diretrizes da Apple).
            OutlinedButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}
