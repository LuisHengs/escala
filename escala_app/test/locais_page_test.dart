import 'dart:async';

import 'package:escala_app/data/local.dart';
import 'package:escala_app/telas/locais_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(home: LocaisPage(repositorio: repo)));
    await t.pumpAndSettle();
  }

  Future<void> adicionar(WidgetTester t, String nome) async {
    await t.enterText(find.byType(TextField), nome);
    await t.tap(find.text('Adicionar local'));
    await t.pumpAndSettle();
  }

  String textoDoCampo(WidgetTester t) =>
      t.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('LO1: lista os locais cadastrados', (t) async {
    repo.locaisCadastrados = [
      const Local(id: 'l1', nome: 'Matriz'),
      const Local(id: 'l2', nome: 'Capela'),
    ];
    await montar(t);

    expect(find.text('Locais'), findsOneWidget); // título
    expect(find.text('Matriz'), findsOneWidget);
    expect(find.text('Capela'), findsOneWidget);
  });

  testWidgets('LO2: sem locais, avisa que não há nenhum', (t) async {
    await montar(t);

    expect(find.text('Nenhum local cadastrado.'), findsOneWidget);
  });

  testWidgets(
    'LO3: adicionar chama o repositório, limpa o campo e recarrega a lista',
    (t) async {
      repo.aoCriarLocal = (nome) =>
          repo.locaisCadastrados = [Local(id: 'l9', nome: nome)];
      await montar(t);
      expect(repo.cargasLocais, 1);

      await adicionar(t, '  Capela  ');

      expect(repo.locaisCriados, ['Capela']); // sem espaços nas pontas
      expect(repo.cargasLocais, 2);
      expect(find.text('Capela'), findsOneWidget); // agora só na lista
      expect(textoDoCampo(t), isEmpty);
    },
  );

  testWidgets('LO4: nome em branco não chama o repositório e avisa', (t) async {
    await montar(t);

    await adicionar(t, '   ');

    expect(repo.locaisCriados, isEmpty);
    expect(find.text('Informe o nome do local.'), findsOneWidget);
  });

  testWidgets(
    'LO5: erro de regra mostra a mensagem e mantém o que foi digitado',
    (t) async {
      repo.erroAoCriarLocal = const LocalDuplicado(
        'Já existe um local com esse nome.',
      );
      await montar(t);

      await adicionar(t, 'Matriz');

      expect(find.text('Já existe um local com esse nome.'), findsOneWidget);
      expect(textoDoCampo(t), 'Matriz');
    },
  );

  testWidgets('LO6: erro inesperado mostra uma mensagem genérica', (t) async {
    repo.erroAoCriarLocal = Exception('SocketException: sem rede');
    await montar(t);

    await adicionar(t, 'Matriz');

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets('LO7: enquanto adiciona, o botão fica bloqueado', (t) async {
    repo.travarCriarLocal = Completer<void>();
    await montar(t);

    await t.enterText(find.byType(TextField), 'Matriz');
    await t.tap(find.text('Adicionar local'));
    await t.pump();

    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(repo.locaisCriados, ['Matriz']);

    repo.travarCriarLocal!.complete();
    await t.pumpAndSettle();
    expect(
      t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('LO8: falha ao carregar avisa e permite tentar de novo', (
    t,
  ) async {
    repo.erroAoCarregarLocais = Exception('sem rede');
    await montar(t);
    expect(find.text('Não foi possível carregar os locais.'), findsOneWidget);
    expect(find.textContaining('sem rede'), findsNothing);

    repo.erroAoCarregarLocais = null;
    repo.locaisCadastrados = [const Local(id: 'l1', nome: 'Matriz')];
    await t.tap(find.text('Tentar de novo'));
    await t.pumpAndSettle();

    expect(find.text('Matriz'), findsOneWidget);
  });

  testWidgets(
    'LO9: [guarda] se só a recarga falhar, não diz que a criação falhou',
    (t) async {
      repo.aoCriarLocal = (_) =>
          repo.erroAoCarregarLocais = Exception('sem rede');
      await montar(t);

      await adicionar(t, 'Matriz');

      expect(repo.locaisCriados, ['Matriz']); // criou, uma única vez
      expect(find.text('Não foi possível carregar os locais.'), findsOneWidget);
      expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
    },
  );
}
