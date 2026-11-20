import 'package:escala_app/telas/admin_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(home: AdminPage(repositorio: repo)));
    await t.pumpAndSettle();
  }

  testWidgets('AD1: mostra o título e o item Convites', (t) async {
    await montar(t);

    expect(find.text('Administração'), findsOneWidget);
    expect(find.text('Convites'), findsOneWidget);
  });

  testWidgets('AD2: tocar em Convites abre a tela de convites', (t) async {
    await montar(t);

    await t.tap(find.text('Convites'));
    await t.pumpAndSettle();

    expect(find.text('Gerar convite'), findsOneWidget);
  });

  testWidgets('AD3: mostra o item Locais e tocar nele abre a tela de locais', (
    t,
  ) async {
    await montar(t);
    expect(find.text('Locais'), findsOneWidget);

    await t.tap(find.text('Locais'));
    await t.pumpAndSettle();

    expect(find.text('Adicionar local'), findsOneWidget);
  });

  testWidgets('AD4: mostra o item Missas e tocar nele abre a lista de missas', (
    t,
  ) async {
    await montar(t);
    expect(find.text('Missas'), findsOneWidget);

    await t.tap(find.text('Missas'));
    await t.pumpAndSettle();

    expect(find.text('Nenhuma missa futura cadastrada.'), findsOneWidget);
  });

  testWidgets(
  'AD5: tocar em Pendências em atraso abre a nova tela',
  (t) async {
    await montar(t);

    expect(find.text('Pendências em atraso'), findsOneWidget);

    await t.tap(find.text('Pendências em atraso'));
    await t.pumpAndSettle();

    expect(
      find.text('Nenhuma pendência em atraso.'),
      findsOneWidget,
    );
  },
);
}
