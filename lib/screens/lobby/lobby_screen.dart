import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../models/categorias.dart';
import '../../network/websocket_client.dart';
import '../../network/websocket_server.dart';
import '../jogo/jogo_screen.dart';

/// Tela de lobby. O host sobe o servidor e mostra IP/porta pros convidados;
/// o convidado digita IP e nome pra entrar. Ambos veem a lista de jogadores.
class LobbyScreen extends StatefulWidget {
  final bool ehHost;
  final String nomeHost;
  final int numRodadas;
  final int duracaoRodadaMinutos;

  // Usados ao voltar do fim do jogo ("Jogar novamente") pra reaproveitar
  // as conexões e a lista de jogadores já existentes.
  final HostServer? serverExistente;
  final HostClient? clientExistente;
  final List<Map<String, dynamic>> jogadoresIniciais;

  const LobbyScreen({
    super.key,
    required this.ehHost,
    this.nomeHost = 'Host',
    this.numRodadas = 3,
    this.duracaoRodadaMinutos = 5,
    this.serverExistente,
    this.clientExistente,
    this.jogadoresIniciais = const [],
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  static const int _porta = 8080;

  // Configuração da sala vinda da ConfigSalaScreen.
  late final int _numRodadas = widget.numRodadas;
  late final int _duracaoRodadaMinutos = widget.duracaoRodadaMinutos;

  HostServer? _server; // só no host
  HostClient? _client; // host (conectado em si mesmo) e convidado

  // Marca que estamos indo pro jogo, pra não parar o servidor no dispose.
  bool _indoParaJogo = false;

  String _ipLocal = '';
  List<Map<String, dynamic>> _jogadores = [];

  // Estado de conexão do convidado (evita entrar várias vezes na sala).
  bool _conectado = false;
  bool _conectando = false;

  final _ipController = TextEditingController();
  final _nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Voltou do fim do jogo: reaproveita servidor/conexão e a lista atual.
    if (widget.serverExistente != null || widget.clientExistente != null) {
      _server = widget.serverExistente;
      _client = widget.clientExistente;
      _configurarCallbacks();
      _jogadores = List<Map<String, dynamic>>.from(widget.jogadoresIniciais);
      _conectado = true;
      if (widget.ehHost) {
        _buscarIp();
      }
      return;
    }

    if (widget.ehHost) {
      _iniciarHost();
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _nomeController.dispose();
    final server = _server;
    // Indo pro jogo, o servidor continua vivo (a JogoScreen assume o uso).
    if (server != null && !_indoParaJogo) {
      unawaited(server.parar());
    }
    super.dispose();
  }

  /// Host: sobe o servidor, conecta em si mesmo (loopback) e busca o IP.
  Future<void> _iniciarHost() async {
    _server = HostServer();
    // iniciar() fica preso no loop de conexões, então não aguardamos.
    unawaited(_server!.iniciar(porta: _porta));

    // Pequena espera pra garantir que o servidor já está escutando.
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // Conecta o host em si mesmo (loopback) ANTES de tudo: garante que ele
    // sempre apareça como jogador, sem depender da descoberta do IP.
    try {
      await _conectarComoCliente(ip: '127.0.0.1', nome: widget.nomeHost);
    } catch (e) {
      debugPrint('Host não conseguiu conectar em si mesmo: $e');
    }

    _buscarIp();
  }

  /// Busca o IP do Wi-Fi só pra exibir pros convidados (não bloqueia nada).
  Future<void> _buscarIp() async {
    String ip = '';
    try {
      ip = await NetworkInfo().getWifiIP() ?? '';
    } catch (e) {
      debugPrint('Não foi possível obter o IP do Wi-Fi: $e');
    }
    if (mounted) {
      setState(() => _ipLocal = ip.isEmpty ? 'IP não encontrado' : ip);
    }
  }

  /// Cria o HostClient, liga os callbacks e entra na sala.
  Future<void> _conectarComoCliente({
    required String ip,
    required String nome,
    int? porta,
  }) async {
    _client = HostClient(ip: ip, porta: porta ?? _porta);
    _configurarCallbacks();
    await _client!.entrarNaSala(nome, 'avatar_1');
  }

  /// Liga os callbacks de mensagem/desconexão no client atual.
  void _configurarCallbacks() {
    _client?.onMensagem = _handleMensagem;
    _client?.onDesconectado = () {
      if (mounted) {
        setState(() {
          _jogadores = [];
          _conectado = false;
        });
      }
    };
  }

  /// Ação do botão Conectar (convidado).
  Future<void> _conectar() async {
    // Evita que o mesmo jogador entre várias vezes na sala.
    if (_conectando || _conectado) return;

    final entrada = _ipController.text.trim();
    final nome = _nomeController.text.trim();
    if (entrada.isEmpty || nome.isEmpty) return;

    // Aceita "IP" ou "IP:porta". Se o usuário colar o endereço com a porta,
    // usa a porta informada em vez de duplicar a padrão (ex.: 192.168.0.10:8080).
    var ip = entrada;
    var porta = _porta;
    final indiceDoisPontos = entrada.lastIndexOf(':');
    if (indiceDoisPontos > 0 && indiceDoisPontos < entrada.length - 1) {
      final possivelPorta = int.tryParse(
        entrada.substring(indiceDoisPontos + 1),
      );
      if (possivelPorta != null &&
          possivelPorta >= 1 &&
          possivelPorta <= 65535) {
        ip = entrada.substring(0, indiceDoisPontos);
        porta = possivelPorta;
      }
    }

    setState(() => _conectando = true);
    try {
      await _conectarComoCliente(ip: ip, nome: nome, porta: porta);
      if (mounted) {
        setState(() => _conectado = true);
      }
    } catch (e) {
      _mostrarErro('Não foi possível conectar: $e');
    } finally {
      if (mounted) {
        setState(() => _conectando = false);
      }
    }
  }

  /// Desconecta o convidado da sala e volta pro estado inicial do formulário.
  void _desconectar() {
    _client?.desconectar();
    if (mounted) {
      setState(() {
        _conectado = false;
        _jogadores = [];
      });
    }
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Ação do botão "Iniciar partida" (só host): sorteia a letra, avisa os
  /// clientes e navega o próprio host pro jogo.
  void _iniciarPartida() {
    final letra = _sortearLetra();
    final duracaoSegundos = _duracaoRodadaMinutos * 60;

    // Guarda letra, número de rodadas e duração no servidor.
    _server?.iniciarRodada(
      letra: letra,
      numRodadas: _numRodadas,
      duracaoSegundos: duracaoSegundos,
    );

    _server?.enviarParaTodos({
      'tipo': 'round_start',
      'letra': letra,
      'duracao_segundos': duracaoSegundos,
      'categorias': categoriasFixas,
      'rodada_atual': 1,
    });

    _irParaJogo(
      letra: letra,
      duracaoSegundos: duracaoSegundos,
      categorias: categoriasFixas,
    );
  }

  /// Sorteia uma letra de A a Z (sem K, W e Y pra simplificar).
  String _sortearLetra() {
    const letras = 'ABCDEFGHIJLMNOPQRSTUVXZ';
    return letras[Random().nextInt(letras.length)];
  }

  /// Navega pro jogo levando os dados da rodada e as instâncias de rede.
  void _irParaJogo({
    required String letra,
    required int duracaoSegundos,
    required List<String> categorias,
  }) {
    _indoParaJogo = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => JogoScreen(
          letra: letra,
          duracaoSegundos: duracaoSegundos,
          categorias: categorias,
          ehHost: widget.ehHost,
          hostServer: _server,
          hostClient: _client,
        ),
      ),
    );
  }

  /// Reage às mensagens do host (room_update e round_start).
  void _handleMensagem(Map<String, dynamic> mensagem) {
    // TODO(debug): remover depois de diagnosticar os bugs do lobby.
    print('LOBBY onMensagem: $mensagem');
    if (!mounted) return;

    final tipo = mensagem['tipo'];
    if (tipo == 'room_update') {
      // TODO: duplicação de jogador ainda ocorre em alguns casos (investigar depois)
      final jogadores = (mensagem['jogadores'] as List)
          .map((j) => Map<String, dynamic>.from(j as Map))
          .toList()
        ..sort((a, b) {
          // Host (Guia) sempre primeiro na lista.
          final aEhHost = a['eh_host'] == true;
          final bEhHost = b['eh_host'] == true;
          if (aEhHost == bEhHost) return 0;
          return aEhHost ? -1 : 1;
        });
      setState(() => _jogadores = jogadores);
    } else if (tipo == 'round_start' && !widget.ehHost) {
      // Convidado: entra no jogo com os dados recebidos do host.
      _irParaJogo(
        letra: mensagem['letra'] as String,
        duracaoSegundos: mensagem['duracao_segundos'] as int,
        categorias: (mensagem['categorias'] as List)
            .map((c) => c as String)
            .toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.ehHost ? 'Sala (host)' : 'Entrar na sala')),
      body: Column(
        children: [
          if (widget.ehHost) _buildInfoHost() else _buildFormConvidado(),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Jogadores', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _jogadores.length,
              itemBuilder: (context, i) {
                final jogador = _jogadores[i];
                final ehHost = jogador['eh_host'] == true;
                return ListTile(
                  leading: const Icon(Icons.person), // placeholder de avatar
                  title: Text(
                    // Host ganha o rótulo "(Guia)" pra se destacar na lista.
                    ehHost
                        ? '${jogador['nome'] as String? ?? ''} (Guia)'
                        : (jogador['nome'] as String? ?? ''),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoHost() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('IP para os convidados:'),
          const SizedBox(height: 8),
          Text(_ipLocal, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text('Porta: $_porta', style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _iniciarPartida,
            child: const Text('Iniciar partida'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormConvidado() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_conectado,
            decoration: const InputDecoration(
              labelText: 'IP do host',
              hintText: 'Ex.: 192.168.0.10 (a porta é automática)',
            ),
          ),
          // Espaçamento entre os campos pra não ficarem colados.
          const SizedBox(height: 16),
          TextField(
            controller: _nomeController,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_conectado,
            decoration: const InputDecoration(labelText: 'Seu nome'),
          ),
          const SizedBox(height: 12),
          if (!_conectado)
            ElevatedButton(
              onPressed: _conectando ? null : _conectar,
              child: _conectando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Conectar'),
            )
          else
            // Link sublinhado pra desconectar (some o botão de conectar).
            TextButton(
              onPressed: _desconectar,
              child: const Text(
                'desconectar',
                style: TextStyle(decoration: TextDecoration.underline),
              ),
            ),
        ],
      ),
    );
  }
}

