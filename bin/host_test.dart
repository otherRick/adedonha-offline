import 'dart:io';

void main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('Servidor rodando em ${server.address.address}:8080');
  await for (var req in server) {
    if (WebSocketTransformer.isUpgradeRequest(req)) {
      final socket = await WebSocketTransformer.upgrade(req);
      print('Cliente conectado');
      socket.listen((data) {
        print('Recebido: $data');
        socket.add('Echo: $data');
      });
    }
  }
}
