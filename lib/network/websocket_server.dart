import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/categorias.dart';

/// Representa um jogador conectado ao host.
class JogadorConectado {
  final String id;
  final WebSocket socket;
  String nome;
  String avatarId;
  int pontuacaoTotal;

  // Marca o host (conexão loopback) pra exibir "(Guia)" na lista.
  bool ehHost;

  JogadorConectado({
    required this.id,
    required this.socket,
    required this.nome,
    required this.avatarId,
    this.pontuacaoTotal = 0,
    this.ehHost = false,
  });
}

/// Servidor local do host. Recebe conexões WebSocket dos convidados
/// na mesma rede Wi-Fi e fala o protocolo de mensagens JSON do Adedanha Offline.
class HostServer {
  HttpServer? _server;
  final Map<String, JogadorConectado> _jogadores = {};

  // Respostas da rodada atual: jogadorId -> {categoria: texto}.
  final Map<String, Map<String, String>> respostasRecebidas = {};

  // Resultado da pontuação por categoria (índice = posição da categoria).
  final List<List<Map<String, dynamic>>> itensRevelados = [];

  // Votos de invalidação: categoriaIndex -> jogadorIdAlvo -> votantes.
  final Map<int, Map<String, Set<String>>> votosInvalidacao = {};

  // Letra da rodada atual e índice do item sendo revelado.
  String _letraRodada = '';
  int _indiceRevelacao = 0;

  // Rodada atual, total de rodadas e duração de cada rodada.
  int _rodadaAtual = 1;
  int _numRodadas = 1;
  int _duracaoSegundos = 300;

  /// Callback chamado quando uma mensagem de um jogador chega,
  /// já decodificada. As telas escutam aqui pra reagir (submit_answers, etc).
  void Function(String jogadorId, Map<String, dynamic> mensagem)? onMensagem;

  Future<void> iniciar({int porta = 8080}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, porta);
    print('Host rodando em ${_server!.address.address}:$porta');

    await for (final req in _server!) {
      if (WebSocketTransformer.isUpgradeRequest(req)) {
        // Conexão vinda do loopback (127.0.0.1) é o próprio host.
        final ehHost = req.connectionInfo?.remoteAddress.isLoopback ?? false;
        _handleNovaConexao(await WebSocketTransformer.upgrade(req),
            ehHost: ehHost);
      }
    }
  }

  /// Guarda a configuração da partida e limpa o estado da rodada anterior.
  void iniciarRodada({
    required String letra,
    required int numRodadas,
    required int duracaoSegundos,
  }) {
    _letraRodada = letra;
    _numRodadas = numRodadas;
    _duracaoSegundos = duracaoSegundos;
    _rodadaAtual = 1;
    respostasRecebidas.clear();
    itensRevelados.clear();
    votosInvalidacao.clear();
    _indiceRevelacao = 0;
  }

  /// Número de rodadas da partida atual (pra recriar o lobby do host).
  int get numRodadas => _numRodadas;

  /// Duração de cada rodada em minutos (pra recriar o lobby do host).
  int get duracaoRodadaMinutos => _duracaoSegundos ~/ 60;

  /// Nome do host (jogador marcado como Guia).
  String? get nomeDoHost {
    for (final j in _jogadores.values) {
      if (j.ehHost) return j.nome;
    }
    return null;
  }

  /// Manda todos de volta pro lobby, mantendo as conexões e a lista atual.
  void voltarAoLobby() {
    enviarParaTodos({
      'tipo': 'voltar_lobby',
      'jogadores': _jogadores.values
          .map((j) => {
                'id': j.id,
                'nome': j.nome,
                'avatar_id': j.avatarId,
                'eh_host': j.ehHost,
              })
          .toList(),
    });
  }

  void _handleNovaConexao(WebSocket socket, {required bool ehHost}) {
    // id temporário até o join_room chegar com o nome de verdade
    final idTemp = DateTime.now().microsecondsSinceEpoch.toString();

    socket.listen(
      (raw) => _handleMensagem(idTemp, socket, raw, ehHost),
      onDone: () => _handleDesconexao(idTemp),
    );
  }

  void _handleMensagem(String idTemp, WebSocket socket, dynamic raw,
      bool ehHost) {
    final Map<String, dynamic> msg = jsonDecode(raw as String);
    final tipo = msg['tipo'] as String;

    if (tipo == 'join_room') {
      final jogador = JogadorConectado(
        id: idTemp,
        socket: socket,
        nome: msg['nome'] as String,
        avatarId: msg['avatar_id'] as String,
        ehHost: ehHost,
      );
      _jogadores[idTemp] = jogador;
      // TODO(debug): remover depois de diagnosticar nomes duplicados.
      print('SERVER join_room: ${jogador.nome} (id=$idTemp) | '
          'total=${_jogadores.length}');
      // Informa o próprio jogador qual é o id dele (pra esconder o botão de
      // invalidar na própria resposta e pro host votar com o próprio id).
      enviarPara(idTemp, {'tipo': 'joined', 'jogador_id': idTemp});
      _broadcastRoomUpdate();
    } else if (tipo == 'submit_answers') {
      // Guarda as respostas do jogador e, quando todos mandarem, calcula.
      final respostas = (msg['respostas'] as Map).cast<String, String>();
      respostasRecebidas[idTemp] = respostas;
      if (respostasRecebidas.length == _jogadores.length) {
        _calcularPontuacaoEIniciarLeitura();
      }
    } else if (tipo == 'invalidar_resposta') {
      // Voto de invalidação: idTemp é o votante, jogador_id_alvo o dono.
      votarInvalidacao(
        msg['categoria_index'] as int,
        msg['jogador_id_alvo'] as String,
        idTemp,
      );
    }

    onMensagem?.call(idTemp, msg);
  }

  void _handleDesconexao(String jogadorId) {
    _jogadores.remove(jogadorId);
    _broadcastRoomUpdate();
  }

  void _broadcastRoomUpdate() {
    // TODO(debug): remover depois de diagnosticar nomes duplicados.
    print('SERVER room_update -> '
        '${_jogadores.values.map((j) => j.nome).toList()}');
    enviarParaTodos({
      'tipo': 'room_update',
      'jogadores': _jogadores.values
          .map((j) => {
                'id': j.id,
                'nome': j.nome,
                'avatar_id': j.avatarId,
                'eh_host': j.ehHost,
              })
          .toList(),
    });
  }

  /// Envia uma mensagem (host -> clientes) pra todo mundo conectado.
  /// Usar para: round_start, round_end, reveal_item, scoreboard_update, game_end.
  void enviarParaTodos(Map<String, dynamic> mensagem) {
    final json = jsonEncode(mensagem);
    for (final j in _jogadores.values) {
      j.socket.add(json);
    }
  }

  void enviarPara(String jogadorId, Map<String, dynamic> mensagem) {
    _jogadores[jogadorId]?.socket.add(jsonEncode(mensagem));
  }

  /// Calcula a pontuação de todas as categorias e começa a revelar.
  void _calcularPontuacaoEIniciarLeitura() {
    itensRevelados.clear();
    final letraNormalizada = _normalizar(_letraRodada);

    for (final categoria in categoriasFixas) {
      final itensCategoria = <Map<String, dynamic>>[];
      // texto normalizado -> ids dos jogadores que responderam igual.
      final jogadoresPorTexto = <String, List<String>>{};

      for (final jogador in _jogadores.values) {
        final textoBruto = respostasRecebidas[jogador.id]?[categoria] ?? '';
        final textoNormalizado = _normalizar(textoBruto);
        // Válida se não vazia e começa com a letra sorteada.
        final valida = textoNormalizado.isNotEmpty &&
            textoNormalizado.startsWith(letraNormalizada);

        if (valida) {
          jogadoresPorTexto
              .putIfAbsent(textoNormalizado, () => [])
              .add(jogador.id);
        }

        itensCategoria.add({
          'jogador_id': jogador.id,
          'nome': jogador.nome,
          'texto': textoBruto.trim(),
          'valida': valida,
          'pontos': 0,
        });
      }

      // Pontuação: texto único = 10 pts, repetido = 5 pts cada.
      for (final item in itensCategoria) {
        if (item['valida'] == true) {
          final ids = jogadoresPorTexto[_normalizar(item['texto'] as String)]!;
          item['pontos'] = ids.length == 1 ? 10 : 5;
        }
      }

      itensRevelados.add(itensCategoria);
    }

    _indiceRevelacao = 0;
    revelarItem(0);
  }

  /// Envia o reveal_item de um índice pra todo mundo, incluindo a soma
  /// parcial de pontos até a categoria atual.
  void revelarItem(int indice) {
    enviarParaTodos({
      'tipo': 'reveal_item',
      'categoria_index': indice,
      'categoria': categoriasFixas[indice],
      'respostas': itensRevelados[indice],
      'pontuacao_parcial': _pontuacaoParcialAte(indice),
    });
  }

  /// Soma dos pontos válidos de todas as categorias reveladas até [indice].
  Map<String, int> _pontuacaoParcialAte(int indice) {
    final parcial = <String, int>{};
    for (var i = 0; i <= indice && i < itensRevelados.length; i++) {
      for (final r in itensRevelados[i]) {
        if (r['valida'] == true) {
          final id = r['jogador_id'] as String;
          parcial[id] = (parcial[id] ?? 0) + (r['pontos'] as int? ?? 0);
        }
      }
    }
    return parcial;
  }

  /// Avança pra próxima categoria revelada (ou encerra a leitura).
  /// A pontuação total é recalculada só no final, pra permitir voltar.
  void avancarItem() {
    final novoIndice = _indiceRevelacao + 1;
    if (novoIndice < itensRevelados.length) {
      _indiceRevelacao = novoIndice;
      revelarItem(novoIndice);
    } else {
      // Acabou a leitura: começa outra rodada ou encerra o jogo.
      _encerrarLeitura();
    }
  }

  /// Volta pro item anterior (deixa o host re-decidir a categoria anterior).
  void voltarItem() {
    if (_indiceRevelacao > 0) {
      _indiceRevelacao--;
      revelarItem(_indiceRevelacao);
    }
  }

  /// Decide entre começar a próxima rodada ou encerrar o jogo.
  void _encerrarLeitura() {
    // Recalcula a pontuação total (seguro mesmo após voltar itens).
    _recalcularPontuacaoTotal();

    if (_rodadaAtual < _numRodadas) {
      // Ainda tem rodada: mostra o vencedor e manda o round_end.
      final vencedorNome = _vencedorDaRodada();
      _rodadaAtual++;
      _letraRodada = _sortearLetra();
      respostasRecebidas.clear();
      itensRevelados.clear();
      votosInvalidacao.clear();
      _indiceRevelacao = 0;

      enviarParaTodos({
        'tipo': 'round_end',
        'vencedor_nome': vencedorNome,
        'letra': _letraRodada,
        'duracao_segundos': _duracaoSegundos,
        'categorias': categoriasFixas,
        'rodada_atual': _rodadaAtual,
      });
    } else {
      // Última rodada: envia o placar final, do maior pro menor.
      final ordenados = _jogadores.values.toList()
        ..sort((a, b) => b.pontuacaoTotal.compareTo(a.pontuacaoTotal));
      enviarParaTodos({
        'tipo': 'game_end',
        'jogadores': ordenados
            .map((j) => {
                  'id': j.id,
                  'nome': j.nome,
                  'pontuacao_total': j.pontuacaoTotal,
                })
            .toList(),
      });
    }
  }

  /// Soma os pontos válidos de todos os itens revelados por jogador.
  void _recalcularPontuacaoTotal() {
    for (final j in _jogadores.values) {
      j.pontuacaoTotal = 0;
    }
    for (final item in itensRevelados) {
      for (final r in item) {
        if (r['valida'] == true) {
          final j = _jogadores[r['jogador_id'] as String];
          if (j != null) {
            j.pontuacaoTotal += r['pontos'] as int;
          }
        }
      }
    }
  }

  /// Nome do jogador com mais pontos na rodada (primeiro em caso de empate).
  String _vencedorDaRodada() {
    JogadorConectado? vencedor;
    for (final j in _jogadores.values) {
      if (vencedor == null || j.pontuacaoTotal > vencedor.pontuacaoTotal) {
        vencedor = j;
      }
    }
    return vencedor?.nome ?? 'Empate';
  }

  /// Sorteia uma letra de A a Z (sem K, W e Y pra simplificar).
  String _sortearLetra() {
    const letras = 'ABCDEFGHIJLMNOPQRSTUVXZ';
    return letras[Random().nextInt(letras.length)];
  }

  /// Registra um voto pra invalidar a resposta de [jogadorIdAlvo].
  /// Ninguém invalida a própria resposta; a invalidação só acontece por
  /// maioria estrita entre os demais jogadores.
  void votarInvalidacao(
      int categoriaIndex, String jogadorIdAlvo, String jogadorIdVotante) {
    // Ninguém invalida a própria resposta (nem o host).
    if (jogadorIdVotante == jogadorIdAlvo) return;

    final votosDaCategoria =
        votosInvalidacao.putIfAbsent(categoriaIndex, () => {});
    final votosDoAlvo = votosDaCategoria.putIfAbsent(jogadorIdAlvo, () => {});
    votosDoAlvo.add(jogadorIdVotante);

    // Elegíveis = total de jogadores menos o dono da resposta.
    final elegiveis = _jogadores.length - 1;
    if (elegiveis > 0 && votosDoAlvo.length > elegiveis / 2) {
      // Maioria estrita: zera os pontos e marca como inválida.
      for (final item in itensRevelados[categoriaIndex]) {
        if (item['jogador_id'] == jogadorIdAlvo) {
          item['pontos'] = 0;
          item['valida'] = false;
          break;
        }
      }
      // Reenvia o reveal_item atualizado (pontos recalculados) pra todos.
      revelarItem(categoriaIndex);
    }
  }

  /// Normaliza um texto pra comparação: minúsculas, sem acentos e trim.
  String _normalizar(String texto) => _removeAcentos(texto.toLowerCase().trim());

  /// Remove acentos de um texto já em minúsculas.
  String _removeAcentos(String texto) {
    const comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const semAcento = 'aaaaaeeeeiiiiooooouuuucn';
    final buffer = StringBuffer();
    for (final char in texto.split('')) {
      final idx = comAcento.indexOf(char);
      buffer.write(idx >= 0 ? semAcento[idx] : char);
    }
    return buffer.toString();
  }

  Future<void> parar() async {
    await _server?.close(force: true);
  }
}
