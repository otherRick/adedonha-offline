import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../network/websocket_client.dart';
import '../../network/websocket_server.dart';
import '../inicial/tela_inicial_screen.dart';
import '../leitura/leitura_screen.dart';
import '../placar_final/placar_final_screen.dart';

/// Tela do jogo. Mostra a contagem regressiva, o timer da rodada e uma
/// categoria por vez pra cada jogador digitar as respostas.
class JogoScreen extends StatefulWidget {
  final String letra;
  final int duracaoSegundos;
  final List<String> categorias;
  final bool ehHost;
  final HostServer? hostServer;
  final HostClient? hostClient;

  // Se true, pula a contagem inicial (veio da tela entre rodadas).
  final bool pularContagem;

  const JogoScreen({
    super.key,
    required this.letra,
    required this.duracaoSegundos,
    required this.categorias,
    required this.ehHost,
    this.hostServer,
    this.hostClient,
    this.pularContagem = false,
  });

  @override
  State<JogoScreen> createState() => _JogoScreenState();
}

class _JogoScreenState extends State<JogoScreen>
    with SingleTickerProviderStateMixin {
  // Contagem regressiva inicial ("3, 2, 1").
  int _contagem = 3;

  // Controller do tremor (drama) quando o tempo está acabando.
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  // Tempo restante da rodada em segundos.
  late int _segundosRestantes = widget.duracaoSegundos;

  // Índice da categoria sendo respondida agora.
  int _indiceCategoria = 0;

  // Respostas salvas: categoria -> texto digitado.
  final Map<String, String> _respostas = {};

  final _respostaController = TextEditingController();

  // Foco do campo de resposta: mantém o teclado aberto a cada categoria.
  final FocusNode _focusNode = FocusNode();

  Timer? _contagemTimer;
  Timer? _rodadaTimer;

  @override
  void initState() {
    super.initState();
    // Escuta round_start (nova rodada) e game_end (fim do jogo).
    widget.hostClient?.onMensagem = _handleMensagem;
    if (widget.pularContagem) {
      // Veio da tela entre rodadas (que já fez o "3-2-1 Valendo!").
      _contagem = 0;
      _iniciarRodada();
    } else {
      _iniciarContagem();
    }
  }

  @override
  void dispose() {
    _contagemTimer?.cancel();
    _rodadaTimer?.cancel();
    _shakeController.dispose();
    _respostaController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Mostra "3, 2, 1" por 3 segundos antes de liberar o jogo.
  void _iniciarContagem() {
    _contagemTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_contagem > 1) {
        setState(() => _contagem--);
      } else {
        timer.cancel();
        setState(() => _contagem = 0);
        _iniciarRodada();
      }
    });
  }

  /// Inicia o timer regressivo da rodada.
  void _iniciarRodada() {
    _rodadaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 1) {
        setState(() => _segundosRestantes--);
        _atualizarTremor();
      } else {
        timer.cancel();
        _shakeController.stop();
        _finalizarRodada();
      }
    });
  }

  /// Liga o tremor (drama) quando faltam poucos segundos.
  void _atualizarTremor() {
    if (_segundosRestantes <= 5 && !_shakeController.isAnimating) {
      _shakeController.repeat(reverse: true);
    }
  }

  /// Salva a resposta atual e navega pra categoria [novoIndice],
  /// restaurando o valor já digitado (se houver).
  void _irParaCategoria(int novoIndice) {
    // Salva o texto atual antes de trocar de categoria.
    final categoriaAtual = widget.categorias[_indiceCategoria];
    _respostas[categoriaAtual] = _respostaController.text.trim();

    setState(() => _indiceCategoria = novoIndice);

    // Restaura o valor já digitado pra nova categoria (senão limpa).
    final novaCategoria = widget.categorias[novoIndice];
    _respostaController.text = _respostas[novaCategoria] ?? '';
    _respostaController.selection = TextSelection.collapsed(
      offset: _respostaController.text.length,
    );

    // Re-foca após o rebuild pra reabrir o teclado automaticamente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  /// Avança pra próxima categoria; no fim, volta pro início (cicla).
  void _proximaCategoria() {
    final proximo = (_indiceCategoria + 1) % widget.categorias.length;
    _irParaCategoria(proximo);
  }

  /// Volta pra categoria anterior; no início, vai pro fim (cicla).
  void _voltarCategoria() {
    final anterior = (_indiceCategoria - 1 + widget.categorias.length) %
        widget.categorias.length;
    _irParaCategoria(anterior);
  }

  /// Timer chegou a 0: salva a resposta atual, envia e vai pra leitura.
  void _finalizarRodada() {
    final categoria = widget.categorias[_indiceCategoria];
    _respostas[categoria] = _respostaController.text.trim();

    // Todo mundo envia as respostas pro servidor (o host manda via loopback).
    widget.hostClient?.enviar({'tipo': 'submit_answers', 'respostas': _respostas});

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LeituraScreen(
          ehHost: widget.ehHost,
          hostServer: widget.hostServer,
          hostClient: widget.hostClient,
        ),
      ),
    );
  }

  /// Reage a mensagens do host enquanto o jogador está na tela de jogo.
  void _handleMensagem(Map<String, dynamic> mensagem) {
    if (!mounted) return;

    final tipo = mensagem['tipo'];
    if (tipo == 'round_start') {
      // Nova rodada chegou: recomeça o jogo com os novos dados.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => JogoScreen(
            letra: mensagem['letra'] as String,
            duracaoSegundos: mensagem['duracao_segundos'] as int,
            categorias: (mensagem['categorias'] as List)
                .map((c) => c as String)
                .toList(),
            ehHost: widget.ehHost,
            hostServer: widget.hostServer,
            hostClient: widget.hostClient,
          ),
        ),
      );
    } else if (tipo == 'game_end') {
      // Fim do jogo: vai pro placar final.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PlacarFinalScreen(
            jogadoresFinais: (mensagem['jogadores'] as List)
                .map((j) => Map<String, dynamic>.from(j as Map))
                .toList(),
            ehHost: widget.ehHost,
            hostServer: widget.hostServer,
            hostClient: widget.hostClient,
          ),
        ),
      );
    }
  }

  /// Formata segundos como mm:ss.
  String _formatarTempo(int totalSegundos) {
    final minutos = totalSegundos ~/ 60;
    final segundos = totalSegundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:'
        '${segundos.toString().padLeft(2, '0')}';
  }

  /// Abre o menu de configurações com as opções de sair.
  void _abrirConfiguracoes() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Configurações'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair da partida'),
              onTap: () {
                Navigator.pop(sheetContext);
                _sair();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Fechar o jogo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _fecharJogo();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Fecha o aplicativo por completo (Android; iOS ignora por diretrizes).
  void _fecharJogo() {
    SystemNavigator.pop();
  }

  /// Desconecta do host e volta pra tela inicial.
  void _sair() {
    widget.hostClient?.desconectar();
    // Encerra o servidor sem esperar (não bloqueia a volta pra tela inicial).
    final server = widget.hostServer;
    if (server != null) {
      unawaited(server.parar());
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TelaInicial()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Contagem regressiva em tela cheia antes do jogo.
    if (_contagem > 0) {
      return Scaffold(
        body: Center(
          child: Text('$_contagem', style: const TextStyle(fontSize: 120)),
        ),
      );
    }

    // Sem AppBar: o header customizado fica dentro do próprio corpo.
    return Scaffold(
      body: _buildCorpo(),
    );
  }

  Widget _buildCorpo() {
    final categoriaAtual = widget.categorias[_indiceCategoria];
    // A navegação é cíclica: a "próxima" no fim é a primeira categoria.
    final proximaCategoria =
        widget.categorias[(_indiceCategoria + 1) % widget.categorias.length];

    return Column(
      children: [
        // Header customizado "in-game" (sem AppBar): timer + letra + avatar.
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timer com tremor e cor vermelha quando o tempo está acabando.
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final deslocamento =
                      math.sin(_shakeController.value * math.pi * 8) * 6;
                  return Transform.translate(
                    offset: Offset(deslocamento, 0),
                    child: child,
                  );
                },
                child: Text(
                  _formatarTempo(_segundosRestantes),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: _segundosRestantes <= 5
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _segundosRestantes <= 5 ? Colors.red : null,
                  ),
                ),
              ),
              Text(widget.letra, style: const TextStyle(fontSize: 48)),
              // Avatar clicável: abre o menu de configurações.
              InkWell(
                onTap: _abrirConfiguracoes,
                customBorder: const CircleBorder(),
                child: const CircleAvatar(
                  radius: 24,
                  child: Icon(Icons.person), // placeholder de avatar
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        // Corpo: categoria atual + campo de resposta.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(categoriaAtual, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 12),
                TextField(
                  controller: _respostaController,
                  focusNode: _focusNode,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _proximaCategoria(),
                  decoration: InputDecoration(
                    hintText: 'Resposta pra $categoriaAtual',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _voltarCategoria,
                        child: const Text('Voltar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _proximaCategoria,
                        child: const Text('Próxima'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Próxima categoria (discreta) — cicla de volta no fim.
                Text(
                  'Próxima: $proximaCategoria',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}


