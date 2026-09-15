import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../network/websocket_client.dart';
import '../../network/websocket_server.dart';
import '../inicial/tela_inicial_screen.dart';
import '../lobby/lobby_screen.dart';

/// Tela de placar final. Mostra a pontuação ordenada e permite compartilhar
/// uma imagem do placar no WhatsApp.
class PlacarFinalScreen extends StatefulWidget {
  final List<Map<String, dynamic>> jogadoresFinais;
  final bool ehHost;
  final HostServer? hostServer;
  final HostClient? hostClient;

  const PlacarFinalScreen({
    super.key,
    required this.jogadoresFinais,
    required this.ehHost,
    this.hostServer,
    this.hostClient,
  });

  @override
  State<PlacarFinalScreen> createState() => _PlacarFinalScreenState();
}

class _PlacarFinalScreenState extends State<PlacarFinalScreen> {
  final GlobalKey _chaveRepaint = GlobalKey();
  int _contagemCompartilhamentos = 0;

  @override
  void initState() {
    super.initState();
    _carregarContagem();
    // Escuta round_start pra "Jogar novamente" (host reinicia a partida).
    widget.hostClient?.onMensagem = _handleMensagem;
  }

  /// Reage ao voltar_lobby: o host pediu "Jogar novamente", todos voltam
  /// pro lobby (conexões mantidas, com a lista atual de jogadores).
  void _handleMensagem(Map<String, dynamic> mensagem) {
    if (!mounted) return;
    if (mensagem['tipo'] == 'voltar_lobby') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            ehHost: widget.ehHost,
            nomeHost: widget.hostServer?.nomeDoHost ?? 'Host',
            numRodadas: widget.hostServer?.numRodadas ?? 3,
            duracaoRodadaMinutos:
                widget.hostServer?.duracaoRodadaMinutos ?? 5,
            serverExistente: widget.hostServer,
            clientExistente: widget.hostClient,
            jogadoresIniciais: (mensagem['jogadores'] as List)
                .map((j) => Map<String, dynamic>.from(j as Map))
                .toList(),
          ),
        ),
      );
    }
  }

  Future<void> _carregarContagem() async {
    final prefs = await SharedPreferences.getInstance();
    _contagemCompartilhamentos =
        prefs.getInt('contagem_compartilhamentos') ?? 0;
  }

  /// Captura o placar como PNG, salva em arquivo temporário e compartilha.
  Future<void> _compartilhar() async {
    // Incrementa e salva o contador.
    _contagemCompartilhamentos++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('contagem_compartilhamentos', _contagemCompartilhamentos);

    // Captura o RepaintBoundary como PNG.
    if (!mounted) return;
    final boundary = _chaveRepaint.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Salva em arquivo temporário.
    final dir = await getTemporaryDirectory();
    final arquivo = File('${dir.path}/placar.png');
    await arquivo.writeAsBytes(bytes);

    // Compartilha o arquivo com um texto de acompanhamento.
    await SharePlus.instance.share(
      ShareParams(
        text: 'Esse foi o resultado da nossa partida de '
            'Adedanha Offline dia ${_formatarData()}!',
        files: [XFile(arquivo.path)],
      ),
    );

    if (!mounted) return;
    if (_contagemCompartilhamentos >= 5) {
      _mostrarConvidePagarCafe();
    }
  }

  /// Convite pra "pagar um café" (sem pagamento real ainda).
  void _mostrarConvidePagarCafe() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gostou do jogo?'),
        content: const Text('Que tal pagar um café pro desenvolvedor?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Se já passou de 5, pede avaliação na loja em vez disso.
              if (_contagemCompartilhamentos > 5) {
                _mostrarPedidoAvaliacao();
              }
            },
            child: const Text('Agora não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ok, quero ajudar!'),
          ),
        ],
      ),
    );
  }

  /// Pedido de avaliação na loja (placeholder).
  void _mostrarPedidoAvaliacao() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avalie o Adedanha'),
        content: const Text('Que tal deixar uma avaliação na loja?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  /// Data de hoje sem horário (dd/mm/aaaa).
  String _formatarData() {
    final agora = DateTime.now();
    final dd = agora.day.toString().padLeft(2, '0');
    final mm = agora.month.toString().padLeft(2, '0');
    return '$dd/$mm/${agora.year}';
  }

  /// Desconecta e volta pra tela inicial (nova partida ou menu).
  void _sairParaMenu() {
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
    final jogadores = widget.jogadoresFinais;
    return Scaffold(
      appBar: AppBar(title: const Text('Placar final')),
      body: Column(
        children: [
          Expanded(
            child: RepaintBoundary(
              key: _chaveRepaint,
              child: Container(
                color: Colors.white, // fundo sólido (imagem não sai escura)
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Adedanha', style: TextStyle(fontSize: 24)),
                    Text(_formatarData()),
                    const SizedBox(height: 16),
                    ...List.generate(jogadores.length, (i) {
                      final jogador = jogadores[i];
                      final primeiro = i == 0;
                      return ListTile(
                        leading: Text('${i + 1}º'),
                        title: Text(
                          jogador['nome'] as String? ?? '',
                          style: TextStyle(
                            fontSize: primeiro ? 22 : 16,
                            fontWeight:
                                primeiro ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        trailing: Text('${jogador['pontuacao_total'] ?? 0} pts'),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: _compartilhar,
                  icon: const Icon(Icons.share),
                  label: const Text('Compartilhar'),
                ),
                const SizedBox(height: 12),
                // "Jogar novamente" só pro host (Guia): leva todos pro lobby.
                if (widget.ehHost) ...[
                  ElevatedButton(
                    onPressed: () => widget.hostServer?.voltarAoLobby(),
                    child: const Text('Jogar novamente'),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: _sairParaMenu,
                  child: const Text('Voltar ao Menu'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
