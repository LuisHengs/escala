import 'dart:async';

import 'package:escala_app/data/missa_cadastrada.dart';
import 'package:escala_app/telas/missas_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

import 'package:escala_app/data/local.dart';
import 'package:escala_core/escala_core.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(home: MissasPage(repositorio: repo)));
    await t.pumpAndSettle();
  }

  testWidgets('MP1: lista as missas com o horário e o local', (t) async {
    repo.missasCadastradas = [
      MissaCadastrada(
        id: 'm1',
        inicio: DateTime(2026, 11, 22, 18, 0),
        localId: 'l1',
        localNome: 'Matriz',
      ),
      MissaCadastrada(
        id: 'm2',
        inicio: DateTime(2026, 11, 28, 19, 0),
        localId: 'l2',
        localNome: 'Capela',
      ),
    ];
    await montar(t);

    expect(find.text('Missas'), findsOneWidget); // título
    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
    expect(find.text('Matriz'), findsOneWidget);
    expect(find.text('sáb 28/11 às 19:00'), findsOneWidget);
    expect(find.text('Capela'), findsOneWidget);
  });

  testWidgets('MP2: sem missas futuras, avisa que não há nenhuma', (t) async {
    await montar(t);

    expect(find.text('Nenhuma missa futura cadastrada.'), findsOneWidget);
  });

  testWidgets('MP3: enquanto carrega, mostra um indicador de progresso', (
    t,
  ) async {
    repo.travarCargaMissas = Completer<void>();
    await t.pumpWidget(MaterialApp(home: MissasPage(repositorio: repo)));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.travarCargaMissas!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('MP4: falha ao carregar avisa e permite tentar de novo', (
    t,
  ) async {
    repo.erroAoCarregarMissas = Exception('sem rede');
    await montar(t);
    expect(find.text('Não foi possível carregar as missas.'), findsOneWidget);
    expect(find.textContaining('sem rede'), findsNothing);

    repo.erroAoCarregarMissas = null;
    repo.missasCadastradas = [
      MissaCadastrada(
        id: 'm1',
        inicio: DateTime(2026, 11, 22, 18, 0),
        localId: 'l1',
        localNome: 'Matriz',
      ),
    ];
    await t.tap(find.text('Tentar de novo'));
    await t.pumpAndSettle();

    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
  });

  testWidgets('MP5: o botão Adicionar missa abre a tela Nova missa', (t) async {
    await montar(t);

    await t.tap(find.text('Adicionar missa'));
    await t.pumpAndSettle();

    expect(find.text('Nova missa'), findsOneWidget);
  });

  // ---------- editar e remover ----------

  final missaUm = MissaCadastrada(
    id: 'm1',
    inicio: DateTime(2026, 11, 22, 18, 0),
    localId: 'l1',
    localNome: 'Matriz',
  );

  /// Monta a lista com uma missa e locais cadastrados. [escolhida] é o que o
  /// seletor de data e hora devolve ao editar (nulo = desistiu).
  Future<void> montarComMissa(WidgetTester t, {DateTime? escolhida}) async {
    repo.locaisCadastrados = [
      const Local(id: 'l1', nome: 'Matriz'),
      const Local(id: 'l2', nome: 'Capela'),
    ];
    repo.missasCadastradas = [missaUm];
    await t.pumpWidget(
      MaterialApp(
        home: MissasPage(
          repositorio: repo,
          escolherDataHora: (_, _) async => escolhida,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> abrirMenu(WidgetTester t) async {
    await t.tap(find.byIcon(Icons.more_vert).first);
    await t.pumpAndSettle();
  }

  Future<void> abrirEdicao(WidgetTester t) async {
    await abrirMenu(t);
    await t.tap(find.text('Editar'));
    await t.pumpAndSettle();
  }

  Future<void> salvarEdicao(WidgetTester t) async {
    await t.tap(find.text('Salvar alterações'));
    await t.pumpAndSettle();
  }

  Finder botaoDoDialogo(String texto) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(texto));

  Future<void> pedirRemocao(WidgetTester t) async {
    await abrirMenu(t);
    await t.tap(find.text('Remover'));
    await t.pumpAndSettle();
  }

  testWidgets('MP6: cada missa tem um menu com Editar e Remover', (t) async {
    await montarComMissa(t);

    await abrirMenu(t);

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Remover'), findsOneWidget);
  });

  testWidgets('MP7: Editar abre a tela com o local e o horário atuais', (
    t,
  ) async {
    await montarComMissa(t);

    await abrirEdicao(t);

    expect(find.text('Editar missa'), findsOneWidget);
    expect(find.text('Matriz'), findsOneWidget); // local já escolhido
    expect(find.text('dom 22/11 às 18:00'), findsOneWidget); // horário atual
    expect(find.text('Salvar alterações'), findsOneWidget);
  });

  testWidgets(
    'MP8: salvar a edição manda id, novo horário e local e recarrega',
    (t) async {
      final novo = DateTime(2026, 11, 29, 19, 0);
      await montarComMissa(t, escolhida: novo);
      await abrirEdicao(t);

      await t.tap(find.text('dom 22/11 às 18:00')); // botão de data e hora
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await t.pumpAndSettle();
      await t.tap(find.text('Capela').last);
      await t.pumpAndSettle();
      await salvarEdicao(t);

      expect(repo.missasEditadas, [
        (missaId: 'm1', inicio: novo, localId: 'l2', escalaLivre: false),
      ]);
      expect(find.text('Editar missa'), findsNothing);
      expect(repo.cargasMissas, 2);
    },
  );

  testWidgets('MP9: salvar sem mudar nada reenvia o horário e o local atuais', (
    t,
  ) async {
    await montarComMissa(t);
    await abrirEdicao(t);

    await salvarEdicao(t);

    expect(repo.missasEditadas, [
      (
        missaId: 'm1',
        inicio: DateTime(2026, 11, 22, 18, 0),
        localId: 'l1',
        escalaLivre: false,
      ),
    ]);
  });

  testWidgets('MP10: conflito de horário mostra a mensagem e mantém a tela', (
    t,
  ) async {
    repo.erroAoEditarMissa = const ConflitoDeHorario(
      'Esse coroinha já está escalado em uma missa com horário próximo.',
    );
    await montarComMissa(t);
    await abrirEdicao(t);

    await salvarEdicao(t);

    expect(
      find.text(
        'Esse coroinha já está escalado em uma missa com horário próximo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Editar missa'), findsOneWidget);
    expect(repo.cargasMissas, 1);
  });

  testWidgets('MP11: Remover pede confirmação e ainda não remove', (t) async {
    await montarComMissa(t);

    await pedirRemocao(t);

    expect(find.text('Remover missa?'), findsOneWidget);
    expect(botaoDoDialogo('Remover'), findsOneWidget);
    expect(botaoDoDialogo('Voltar'), findsOneWidget);
    expect(repo.missasRemovidas, isEmpty);
  });

  testWidgets('MP12: confirmar remove a missa e recarrega a lista', (t) async {
    await montarComMissa(t);
    await pedirRemocao(t);

    await t.tap(botaoDoDialogo('Remover'));
    await t.pumpAndSettle();

    expect(repo.missasRemovidas, ['m1']);
    expect(repo.cargasMissas, 2);
    expect(find.text('Remover missa?'), findsNothing);
  });

  testWidgets('MP13: Voltar na confirmação não remove nada', (t) async {
    await montarComMissa(t);
    await pedirRemocao(t);

    await t.tap(botaoDoDialogo('Voltar'));
    await t.pumpAndSettle();

    expect(repo.missasRemovidas, isEmpty);
    expect(repo.cargasMissas, 1);
    expect(find.text('Remover missa?'), findsNothing);
  });

  testWidgets(
    'MP14: missa com coroinhas escalados mostra a mensagem da regra',
    (t) async {
      repo.erroAoRemoverMissa = const MissaComEscalados(
        'Esta missa tem coroinhas escalados. Retire-os antes de removê-la.',
      );
      await montarComMissa(t);
      await pedirRemocao(t);

      await t.tap(botaoDoDialogo('Remover'));
      await t.pumpAndSettle();

      expect(
        find.text(
          'Esta missa tem coroinhas escalados. Retire-os antes de removê-la.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('dom 22/11 às 18:00'),
        findsOneWidget,
      ); // continua na lista
      expect(repo.cargasMissas, 1);
    },
  );

  testWidgets('MP15: erro inesperado ao remover mostra mensagem genérica', (
    t,
  ) async {
    repo.erroAoRemoverMissa = Exception('SocketException: sem rede');
    await montarComMissa(t);
    await pedirRemocao(t);

    await t.tap(botaoDoDialogo('Remover'));
    await t.pumpAndSettle();

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets(
    'MP16: se só o recarregamento falhar, não diz que a remoção falhou',
    (t) async {
      await montarComMissa(t);
      repo.aoRemoverMissa = () =>
          repo.erroAoCarregarMissas = Exception('sem rede');
      await pedirRemocao(t);

      await t.tap(botaoDoDialogo('Remover'));
      await t.pumpAndSettle();

      expect(repo.missasRemovidas, ['m1']);
      expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
      expect(find.text('Não foi possível carregar as missas.'), findsOneWidget);
    },
  );

  final missaLivre = MissaCadastrada(
    id: 'm2',
    inicio: DateTime(2026, 11, 29, 18, 0),
    localId: 'l1',
    localNome: 'Matriz',
    escalaLivre: true,
  );

  testWidgets('MP17: a lista marca as missas com escala livre', (t) async {
    repo.locaisCadastrados = [const Local(id: 'l1', nome: 'Matriz')];
    repo.missasCadastradas = [missaUm, missaLivre];
    await t.pumpWidget(MaterialApp(home: MissasPage(repositorio: repo)));
    await t.pumpAndSettle();

    expect(find.text('Matriz · Escala livre'), findsOneWidget);
    expect(find.text('Matriz'), findsOneWidget); // a missa que não é livre
  });

  testWidgets('MP18: editar uma missa livre sem mexer na chave mantém a chave',
      (t) async {
    repo.locaisCadastrados = [const Local(id: 'l1', nome: 'Matriz')];
    repo.missasCadastradas = [missaLivre];
    await t.pumpWidget(MaterialApp(home: MissasPage(repositorio: repo)));
    await t.pumpAndSettle();
    await abrirEdicao(t);

    await salvarEdicao(t);

    expect(repo.missasEditadas, [
      (
        missaId: 'm2',
        inicio: DateTime(2026, 11, 29, 18, 0),
        localId: 'l1',
        escalaLivre: true,
      ),
    ]);
  });
}
