# 🎲 Adedanha Offline

> O clássico jogo de **Adedanha (Stop!)** para jogar em grupo, cada um no **próprio celular**, conectados pela **mesma rede Wi-Fi** — **sem internet** e **sem servidor externo**.

![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?style=flat-square&logo=dart&logoColor=white)
![Plataformas](https://img.shields.io/badge/Plataformas-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Desktop-8A2BE2?style=flat-square)
![Licença](https://img.shields.io/badge/Licença-Código%20para%20estudo-red?style=flat-square)

---

## 📖 Sobre o Projeto

O **Adedanha Offline** é um *party game* de palavras em que um aparelho atua como **host (Guia)** — rodando um servidor WebSocket local — e os demais entram como **convidados** digitando apenas o IP exibido na tela do host.

A cada rodada uma **letra é sorteada** e os jogadores preenchem o maior número possível de **categorias** começando com aquela letra. Ao fim do tempo, as respostas são reveladas e pontuadas, e o placar final pode ser **compartilhado** como imagem com texto.

### 🎯 Gênero & Mecânicas principais

- 🧩 **Gênero:** jogo de palavras casual / multiplayer local.
- 📡 **Multiplayer local via Wi-Fi** (arquitetura *host ↔ convidados*).
- 🔤 **13 categorias fixas** (Nome, Cor, Fruta, Animal, País, Cidade, Marca, Celebridade, Música, Objeto, Comida, Profissão, Filme/Série/Desenho).
- 🅰️ **Sorteio de letra** (A–Z, sem K, W e Y para simplificar).
- ⏱️ **Timer com efeito de drama** (tremor) nos últimos segundos.
- 🧮 **Pontuação:** resposta única = 10 pts · repetida = 5 pts · inválida = 0.
- 🗳️ **Invalidação por votação** (maioria estrita; ninguém invalida a própria resposta).
- 🏆 **Tela de vencedor da rodada** entre partidas.
- 📤 **Placar final** com compartilhamento de imagem + texto (WhatsApp, e-mail etc.).

### 🎯 Objetivo do desenvolvimento

Este repositório é um **projeto de portfólio** que demonstra, na prática, a construção de um aplicativo multiplayer offline com **arquitetura em camadas**, **comunicação em tempo real via WebSocket**, **tema centralizado** e **fluxo de navegação completo** — tudo com uma única base de código multiplataforma.

---

## 🛠️ Tecnologias & Arquitetura

### Stack técnica

| Camada | Tecnologia / Biblioteca |
| --- | --- |
| **Framework** | [Flutter](https://flutter.dev/) (Dart) |
| **Rede** | `dart:io` — `HttpServer` + `WebSocket` (servidor embutido no app) |
| **Descoberta de IP** | [`network_info_plus`](https://pub.dev/packages/network_info_plus) |
| **Compartilhamento** | [`share_plus`](https://pub.dev/packages/share_plus) |
| **Persistência** | [`shared_preferences`](https://pub.dev/packages/shared_preferences) |
| **Arquivos temporários** | [`path_provider`](https://pub.dev/packages/path_provider) |
| **Qualidade de código** | [`flutter_lints`](https://pub.dev/packages/flutter_lints) |

### Estrutura de pastas

```
lib/
├── main.dart                  # Bootstrap + travamento de orientação (mobile)
├── models/
│   └── categorias.dart        # Categorias fixas do jogo
├── network/
│   ├── websocket_server.dart  # Servidor do host (conexões, pontuação, rodadas)
│   └── websocket_client.dart  # Cliente dos convidados (e loopback do host)
├── screens/
│   ├── inicial/               # Tela inicial (criar/entrar/fechar)
│   ├── config_sala/           # Configuração da sala (nome, rodadas, duração)
│   ├── lobby/                 # Sala de espera (IP + lista de jogadores)
│   ├── jogo/                  # Gameplay (timer, letra, categorias)
│   ├── leitura/               # Revelação das respostas + invalidação
│   ├── entre_rodadas/         # "Fulano ganhou essa rodada" → 3-2-1
│   └── placar_final/          # Ranking + compartilhamento + jogar novamente
├── theme/
│   └── app_theme.dart         # Tema centralizado (cores, tipografia, botões)
└── widgets/                   # Widgets reutilizáveis
```

### Protocolo de comunicação

O host e os convidados trocam **mensagens JSON** com uma chave `tipo` que define o evento:

| Mensagem | Direção | Descrição |
| --- | --- | --- |
| `join_room` | Cliente → Host | Entrar na sala (nome e avatar) |
| `joined` | Host → Cliente | Confirma o id do próprio jogador |
| `room_update` | Host → Todos | Lista atualizada de jogadores |
| `round_start` | Host → Todos | Início de rodada (letra e duração) |
| `submit_answers` | Cliente → Host | Respostas enviadas ao fim do tempo |
| `reveal_item` | Host → Todos | Revelação categoria a categoria |
| `invalidar_resposta` | Cliente → Host | Voto para invalidar uma resposta |
| `round_end` | Host → Todos | Fim da rodada (vencedor + próxima) |
| `game_end` | Host → Todos | Placar final |
| `voltar_lobby` | Host → Todos | Retorno ao lobby ("jogar novamente") |

### Padrões de projeto e arquitetura

- 🧱 **Arquitetura em camadas** — separação entre `models`, `network`, `screens` e `theme`.
- 🎨 **Tema centralizado** — todos os componentes herdam estilo de um único `ThemeData`.
- 🧭 **Navegação declarativa** com `Navigator` (`push` / `pushReplacement` / `pushAndRemoveUntil`).
- 🔁 **Comunicação orientada a eventos** via callbacks (`onMensagem`, `onDesconectado`).
- 🖥️ **Servidor dentro do cliente** — o host é, ao mesmo tempo, servidor e jogador (conexão *loopback*).

---


## ⚖️ Propriedade Intelectual & Licença

© Todos os direitos reservados.

- **Código-fonte** — disponibilizado **exclusivamente para fins de estudo e portfólio**. Você pode ler, estudar e referenciar a arquitetura e as soluções técnicas, mas **não** está licenciado para uso comercial, redistribuição ou criação de trabalhos derivados sem autorização prévia por escrito.
- **Assets (artes, áudios, sprites, ícones e qualquer mídia)** — **proprietários**, com **todos os direitos reservados (All Rights Reserved)**. Nenhum asset pode ser copiado, modificado, distribuído ou reutilizado, ainda que parcialmente.

> ⚠️ Para qualquer uso além do estudo/portfólio, entre em contato com o autor antes de utilizar qualquer parte deste repositório.

---

<p align="center">
  Feito com 💙 usando <a href="https://flutter.dev">Flutter</a> — um projeto de portfólio de <strong>Adedanha Offline</strong>.
</p>
