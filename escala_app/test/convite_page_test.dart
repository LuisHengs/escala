import 'dart:async';

import 'package:escala_app/telas/convite_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) =>
      t.pumpWidget(MaterialApp(home: ConvitePage(repositorio: repo)));

  Future<void> preencher(
    WidgetTester t, {
    String codigo = '',
    String nome = '',
    String responsavel = '',
  }) async {
    await t.enterText(
      find.widgetWithText(TextField, 'Código do convite'),
      codigo,
    );
    await t.enterText(find.widgetWithText(TextField, 'Seu nome'), nome);
    await t.enterText(
      find.widgetWithText(TextField, 'Nome do responsável'),
      responsavel,
    );
  }

  Future<void> continuar(WidgetTester t) async {
    await t.tap(find.text('Continuar'));
    await t.pumpAndSettle();
  }

  testWidgets('V1: mostra os três campos e o botão Continuar', (t) async {
    await montar(t);
    expect(find.widgetWithText(TextField, 'Código do convite'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Seu nome'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Nome do responsável'),
      findsOneWidget,
    );
    expect(find.text('Continuar'), findsOneWidget);
  });

  testWidgets('V2: envia o código, o nome e o responsável ao repositório', (
    t,
  ) async {
    await montar(t);
    await preencher(t, codigo: 'ABCD2345', nome: 'Maria', responsavel: 'José');
    await continuar(t);
    expect(repo.resgates, [
      (codigo: 'ABCD2345', nome: 'Maria', responsavel: 'José'),
    ]);
  });

  testWidgets('V3: sem código e sem nome, avisa e NÃO chama o repositório', (
    t,
  ) async {
    await montar(t);
    await continuar(t);
    expect(find.text('Informe o código do convite.'), findsOneWidget);
    expect(find.text('Informe o seu nome.'), findsOneWidget);
    expect(repo.resgates, isEmpty);
  });

  testWidgets(
    'V4: responsável em branco é enviado como nulo, não como texto vazio',
    (t) async {
      await montar(t);
      await preencher(t, codigo: 'ABCD2345', nome: 'Maria', responsavel: '   ');
      await continuar(t);
      expect(repo.resgates.single.responsavel, isNull);
    },
  );

  testWidgets('V5: erro de regra mostra a mensagem e deixa tentar de novo', (
    t,
  ) async {
    repo.erroNoResgate = const ConviteUsado('Este convite já foi usado.');
    await montar(t);
    await preencher(t, codigo: 'ABCD2345', nome: 'Maria');
    await continuar(t);

    expect(find.text('Este convite já foi usado.'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('V6: enquanto envia, bloqueia o botão e mostra progresso', (
    t,
  ) async {
    repo.travarResgate = Completer<void>();
    await montar(t);
    await preencher(t, codigo: 'ABCD2345', nome: 'Maria');
    await t.tap(find.text('Continuar'));
    await t.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    repo.travarResgate!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'V7: erro inesperado mostra uma mensagem genérica, sem texto técnico',
    (t) async {
      repo.erroNoResgate = Exception('SocketException: sem rede');
      await montar(t);
      await preencher(t, codigo: 'ABCD2345', nome: 'Maria');
      await continuar(t);

      expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
      expect(find.textContaining('Socket'), findsNothing);
    },
  );

  testWidgets('V8: a mensagem de erro some quando a pessoa tenta de novo', (
    t,
  ) async {
    repo.erroNoResgate = const ConviteExpirado('Este convite venceu.');
    await montar(t);
    await preencher(t, codigo: 'ABCD2345', nome: 'Maria');
    await continuar(t);
    expect(find.text('Este convite venceu.'), findsOneWidget);

    repo.erroNoResgate = null;
    await continuar(t);
    expect(find.text('Este convite venceu.'), findsNothing);
  });

  testWidgets('V9: Usar outra conta chama o repositório (sair)', (t) async {
    await montar(t);
    await t.tap(find.text('Usar outra conta'));
    await t.pump();
    expect(repo.chamadasSair, 1);
  });
}
