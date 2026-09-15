import 'package:flutter/material.dart';

import '../../models/categorias.dart';
import '../../network/websocket_client.dart';
import '../../network/websocket_server.dart';
import '../entre_rodadas/entre_rodadas_screen.dart';
import '../jogo/jogo_screen.dart';
import '../placar_final/placar_final_screen.dart';

/// Tela de leitura das respostas. Mostra categoria por categoria o que cada
/// jogador respondeu, com pontos e a opção de invalidar.
class LeituraScreen extends StatefulWidget {
  final bool ehHost;
  final HostServer? hostServer;
  final HostClient? hostClient;

  const LeituraScreen({
    super.key,
    required this.ehHost,
    this.hostServer,
    this.hostClient,
  });

  @override
  State<LeituraScreen> createState() => _LeituraScreenState();
}

class _LeituraScreenState extends State<LeituraScreen> {
  String _categoria = '';
  int _categoriaIndex = 0;
  List<Map<String, dynamic>> _respostas = [];

  // Soma parcial de pontos por jogador (até a categoria revelada).
  Map<String, int> _pontuacaoParcial = {};

  @override
  void initState() {
    super.initState();
    // Escuta reveal_item, round_start e game_end vindos do host.
    widget.hostClient?.onMensagem = _handleMensagem;
  }

  void _handleMensagem(Map<String, dynamic> mensagem) {
    if (!mounted) return;

    final tipo = mensagem['tipo'];
    if (tipo == 'reveal_item') {
      setState(() {
        _categoriaIndex = mensagem['categoria_index'] as int;
        _categoria = mensagem['categoria'] as String;
        _respostas = (mensagem['respostas'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        // Soma parcial de pontos até a categoria atual.
        _pontuacaoParcial = (mensagem['pontuacao_parcial'] as Map? ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt()));
      });
    } else if (tipo == 'round_start') {
      // Nova rodada: volta pro jogo com os novos dados.
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
    } else if (tipo == 'round_end') {
      // Entre rodadas: mostra quem venceu e depois volta pro jogo.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EntreRodadasScreen(
            vencedorNome: mensagem['vencedor_nome'] as String,
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

  /// Vota pra invalidar a resposta de outro jogador.
  void _invalidar(String jogadorIdAlvo) {
    if (widget.ehHost) {
      // Host tem acesso direto ao servidor: vota com o próprio id (sem rede).
      final votanteId = widget.hostClient?.meuId;
      if (votanteId != null) {
        widget.hostServer?.votarInvalidacao(
            _categoriaIndex, jogadorIdAlvo, votanteId);
      }
    } else {
      widget.hostClient?.enviar({
        'tipo': 'invalidar_resposta',
        'categoria_index': _categoriaIndex,
        'jogador_id_alvo': jogadorIdAlvo,
      });
    }
  }

  /// Emoji ilustrativo de cada categoria (fallback genérico se não mapeada).
  String _emojiDaCategoria(String categoria) {
    const emojis = {
      'Nome': '👤',
      'Cor': '🎨',
      'Fruta': '🍎',
      'Animal': '🐾',
      'País': '🌍',
      'Cidade': '🏙️',
      'Marca': '🏷️',
      'Celebridade': '⭐',
      'Música': '🎵',
      'Objeto': '📦',
      'Comida': '🍽️',
      'Profissão': '👷',
      'Filme/Série/Desenho': '🎬',
    };
    return emojis[categoria] ?? '📝';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leitura das respostas')),
      body: Column(
        children: [
          // Subheader da categoria: emoji de um lado, nome + posição do outro.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _categoria.isEmpty ? '⏳' : _emojiDaCategoria(_categoria),
                  style: const TextStyle(fontSize: 32),
                ),
                Text(
                  _categoria.isEmpty
                      ? 'Aguardando...'
                      : '$_categoria (${_categoriaIndex + 1}/${categoriasFixas.length})',
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
          ),
          const Divider(),
          // Lista de respostas da categoria atual.
          Expanded(
            child: _respostas.isEmpty
                ? const Center(child: Text('Aguardando revelação...'))
                : ListView.builder(
                    itemCount: _respostas.length,
                    itemBuilder: (context, i) {
                      final resposta = _respostas[i];
                      final valida = resposta['valida'] == true;
                      final pontos = resposta['pontos'] as int? ?? 0;
                      final jogadorId = resposta['jogador_id'] as String;
                      final parcial = _pontuacaoParcial[jogadorId] ?? 0;
                      // Esconde o botão de invalidar na própria resposta.
                      final ehMinha = jogadorId == widget.hostClient?.meuId;
                      return ListTile(
                        leading: const Icon(Icons.person), // avatar placeholder
                        title: Text(
                          '${resposta['nome'] ?? ''} — $parcial pts até agora',
                        ),
                        subtitle: Text(
                            '${resposta['texto'] ?? ''} ($pontos pts)'),
                        // Cor diferente pra resposta inválida (0 pontos).
                        textColor: valida ? null : Colors.red,
                        trailing: ehMinha
                            ? null
                            : TextButton(
                                onPressed: () => _invalidar(jogadorId),
                                child: const Text('invalidar'),
                              ),
                      );
                    },
                  ),
          ),
          // Botões de voltar/avançar item (só o host controla a leitura).
          if (widget.ehHost)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      // Só habilita se não estiver no primeiro item.
                      onPressed: _categoriaIndex > 0
                          ? () => widget.hostServer?.voltarItem()
                          : null,
                      child: const Text('Voltar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.hostServer?.avancarItem(),
                      child: const Text('Próximo item'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
