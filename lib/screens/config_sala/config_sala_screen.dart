import 'package:flutter/material.dart';

import '../lobby/lobby_screen.dart';

/// Tela de configuração da sala (só pro host). Define o número de rodadas
/// e a duração de cada rodada, e navega pro lobby pra criar a sala.
class ConfigSalaScreen extends StatefulWidget {
  const ConfigSalaScreen({super.key});

  @override
  State<ConfigSalaScreen> createState() => _ConfigSalaScreenState();
}

class _ConfigSalaScreenState extends State<ConfigSalaScreen> {
  int _numRodadas = 3;
  double _duracaoRodadaMinutos = 5;

  // Nome escolhido pelo host pra aparecer na lista de jogadores.
  final _nomeController = TextEditingController();

  // Opções disponíveis pro seletor de rodadas.
  static const List<int> _opcoesRodadas = [1, 3, 5];

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  /// Navega pro lobby levando a configuração escolhida.
  void _criarSala() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          ehHost: true,
          nomeHost: _nomeController.text.trim(),
          numRodadas: _numRodadas,
          duracaoRodadaMinutos: _duracaoRodadaMinutos.round(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar sala')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nome do host (obrigatório pra liberar o botão de criar sala).
            TextField(
              controller: _nomeController,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Seu nome',
                hintText: 'Como você vai aparecer na sala',
              ),
              onChanged: (_) => setState(() {}), // reavalia o botão
            ),
            const SizedBox(height: 24),
            const Text('Número de rodadas'),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: _opcoesRodadas
                  .map((r) => ButtonSegment<int>(value: r, label: Text('$r')))
                  .toList(),
              selected: {_numRodadas},
              onSelectionChanged: (selecao) {
                setState(() => _numRodadas = selecao.first);
              },
            ),
            const SizedBox(height: 24),
            Text('Duração da rodada: ${_duracaoRodadaMinutos.round()} min'),
            Slider(
              value: _duracaoRodadaMinutos,
              min: 1,
              max: 20,
              divisions: 19, // passo de 1 minuto
              label: '${_duracaoRodadaMinutos.round()} min',
              onChanged: (valor) {
                setState(() => _duracaoRodadaMinutos = valor);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              // Só habilita quando o host digitou um nome.
              onPressed:
                  _nomeController.text.trim().isEmpty ? null : _criarSala,
              child: const Text('Criar sala'),
            ),
          ],
        ),
      ),
    );
  }
}
