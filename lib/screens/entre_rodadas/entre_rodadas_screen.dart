import 'dart:async';

import 'package:flutter/material.dart';

import '../../network/websocket_client.dart';
import '../../network/websocket_server.dart';
import '../jogo/jogo_screen.dart';

/// Tela entre rodadas: mostra quem venceu, avisa que a próxima rodada vem
/// e faz a contagem "3-2-1 Valendo!" antes de voltar pro jogo.
class EntreRodadasScreen extends StatefulWidget {
  final String vencedorNome;
  final String letra;
  final int duracaoSegundos;
  final List<String> categorias;
  final bool ehHost;
  final HostServer? hostServer;
  final HostClient? hostClient;

  const EntreRodadasScreen({
    super.key,
    required this.vencedorNome,
    required this.letra,
    required this.duracaoSegundos,
    required this.categorias,
    required this.ehHost,
    this.hostServer,
    this.hostClient,
  });

  @override
  State<EntreRodadasScreen> createState() => _EntreRodadasScreenState();
}

class _EntreRodadasScreenState extends State<EntreRodadasScreen> {
  // 0 = vencedor, 1 = preparar, 2 = contagem, 3 = valendo.
  int _fase = 0;
  int _contagem = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iniciarSequencia();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _iniciarSequencia() {
    // 1) Vencedor por 3 segundos.
    _timer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _fase = 1);
      // 2) "Preparar..." por 2 segundos.
      _timer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() => _fase = 2);
        _iniciarContagem();
      });
    });
  }

  void _iniciarContagem() {
    _contagem = 3;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_contagem > 0) {
        setState(() => _contagem--);
      } else {
        timer.cancel();
        setState(() => _fase = 3); // "Valendo!"
        _timer = Timer(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          _irParaJogo();
        });
      }
    });
  }

  void _irParaJogo() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JogoScreen(
          letra: widget.letra,
          duracaoSegundos: widget.duracaoSegundos,
          categorias: widget.categorias,
          ehHost: widget.ehHost,
          hostServer: widget.hostServer,
          hostClient: widget.hostClient,
          pularContagem: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _conteudo(),
        ),
      ),
    );
  }

  Widget _conteudo() {
    switch (_fase) {
      case 0:
        return Column(
          key: const ValueKey('vencedor'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ganhou essa rodada', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 12),
            Text(
              widget.vencedorNome,
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 1:
        return const Text(
          'Preparar para próxima rodada',
          key: ValueKey('preparar'),
          style: TextStyle(fontSize: 28),
          textAlign: TextAlign.center,
        );
      case 2:
        return Text(
          '$_contagem',
          key: const ValueKey('contagem'),
          style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold),
        );
      default:
        return const Text(
          'Valendo!',
          key: ValueKey('valendo'),
          style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
        );
    }
  }
}
