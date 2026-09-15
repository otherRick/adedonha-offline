// Teste de fumaça (smoke test) da aplicação.
//
// Verifica apenas que o app raiz monta a tela inicial corretamente.

import 'package:flutter_test/flutter_test.dart';

import 'package:adedanhaoffline/main.dart';

void main() {
  testWidgets('AdedanhaApp renderiza a tela inicial', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AdedanhaApp());

    expect(find.text('Adedanha Offline'), findsOneWidget);
    expect(find.text('Criar sala'), findsOneWidget);
    expect(find.text('Entrar em uma sala'), findsOneWidget);
  });
}
