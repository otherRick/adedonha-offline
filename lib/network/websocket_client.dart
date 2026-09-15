import 'dart:convert';
import 'dart:io';

/// Cliente que conecta no HostServer do Adedanha Offline e fala o mesmo
/// protocolo de mensagens JSON (chave "tipo") com o host.
class HostClient {
  final String ip;
  final int porta;
  WebSocket? _socket;

  /// Id do próprio jogador, informado pelo host após o join_room.
  String? meuId;

  /// Callback chamado quando uma mensagem do host chega, já decodificada.
  /// As telas escutam aqui pra reagir (room_update, round_start, etc).
  void Function(Map<String, dynamic> mensagem)? onMensagem;

  /// Callback chamado quando a conexão cai.
  /// Sem reconexão automática - isso fica pra v2.
  void Function()? onDesconectado;

  HostClient({required this.ip, required this.porta});

  /// Conecta no host e, assim que o socket abre, entra na sala
  /// enviando o join_room com nome e avatar.
  Future<void> entrarNaSala(String nome, String avatarId) async {
    _socket = await WebSocket.connect('ws://$ip:$porta');
    print('Conectado em $ip:$porta');

    _socket!.listen(
      _handleMensagem,
      onDone: _handleDesconexao,
      onError: (_) => _handleDesconexao(),
    );

    enviar({'tipo': 'join_room', 'nome': nome, 'avatar_id': avatarId});
  }

  /// Envia uma mensagem genérica pro host (jsonEncode + socket.add).
  /// Usar para: submit_answers, invalidar_resposta.
  void enviar(Map<String, dynamic> mensagem) {
    _socket?.add(jsonEncode(mensagem));
  }

  /// Fecha a conexão com o host (usado ao sair da partida).
  void desconectar() {
    _socket?.close();
    _socket = null;
  }

  void _handleMensagem(dynamic raw) {
    final Map<String, dynamic> msg = jsonDecode(raw as String);
    // Mensagem interna com o id do próprio jogador (não vai pras telas).
    if (msg['tipo'] == 'joined') {
      meuId = msg['jogador_id'] as String;
      return;
    }
    onMensagem?.call(msg);
  }

  void _handleDesconexao() {
    onDesconectado?.call();
  }
}

