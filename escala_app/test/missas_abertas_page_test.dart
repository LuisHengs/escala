import 'dart:async';

import 'package:escala_app/data/missa_cadastrada.dart';
import 'package:escala_app/telas/missas_abertas_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  final domingo = MissaCadastrada(
    id: 'm1',
    inicio: DateTime(2026, 11, 22, 18, 0),
    localId: 'l1',
    localNome: 'Matriz',
    escalaLivre: true,
  );
  final quarta = MissaCadastrada(
    id: 'm2',
    inicio: DateTime(2026, 11, 25, 19, 30),
    localId: 'l2',
    localNome: 'Capela',
    escalaLivre: true,
  );

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(home: MissasAbertasPage(repositorio: repo)));
    await t.pumpAndSettle();
  }

  Future<void> entrarNaPrimeira(WidgetTester t) async {
    await t.tap(find.text('Entrar na escala').first);
    await t.pumpAndSettle();
  }

  // ---------- lista ----------

  testWidgets('AB1: lista as missas abertas com horário, local e o botão', (
    t,
  ) async {
    repo.missasAbertasCadastradas = [domingo, quarta];
    await montar(t);

    expect(find.text('Missas abertas'), findsOneWidget); // título
    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
    expect(find.text('Matriz'), findsOneWidget);
    expect(find.text('qua 25/11 às 19:30'), findsOneWidget);
    expect(find.text('Capela'), findsOneWidget);
    expect(find.text('Entrar na escala'), findsNWidgets(2));
  });

  testWidgets('AB2: sem missas abertas, avisa', (t) async {
    await montar(t);

    expect(find.text('Nenhuma missa aberta no momento.'), findsOneWidget);
  });

  testWidgets('AB3: enquanto carrega, mostra um indicador de progresso', (
    t,
  ) async {
    repo.travarCargaMissasAbertas = Completer<void>();
    await t.pumpWidget(MaterialApp(home: MissasAbertasPage(repositorio: repo)));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.travarCargaMissasAbertas!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('AB4: falha ao carregar avisa e permite tentar de novo', (
    t,
  ) async {
    repo.erroAoCarregarMissasAbertas = Exception('sem rede');
    await montar(t);
    expect(
      find.text('Não foi possível carregar as missas abertas.'),
      findsOneWidget,
    );
    expect(find.textContaining('sem rede'), findsNothing);

    repo.erroAoCarregarMissasAbertas = null;
    repo.missasAbertasCadastradas = [domingo];
    await t.tap(find.text('Tentar de novo'));
    await t.pumpAndSettle();

    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
  });

  // ---------- entrar na escala ----------

  testWidgets('AB5: entrar manda a missa, avisa e a missa some da lista', (
    t,
  ) async {
    repo.missasAbertasCadastradas = [domingo, quarta];
    repo.aoEntrarNaEscala = (id) => repo.missasAbertasCadastradas = repo
        .missasAbertasCadastradas
        .where((m) => m.id != id)
        .toList();
    await montar(t);

    await entrarNaPrimeira(t);

    expect(repo.entradasNaEscala, ['m1']);
    expect(find.text('Você entrou na escala.'), findsOneWidget);
    expect(repo.cargasMissasAbertas, 2);
    expect(find.text('dom 22/11 às 18:00'), findsNothing);
    expect(find.text('qua 25/11 às 19:30'), findsOneWidget);
  });

  testWidgets('AB6: conflito de horário mostra a mensagem e não recarrega', (
    t,
  ) async {
    repo.missasAbertasCadastradas = [domingo];
    repo.erroAoEntrarNaEscala = const ConflitoDeHorario(
      'Esse coroinha já está escalado em uma missa com horário próximo.',
    );
    await montar(t);

    await entrarNaPrimeira(t);

    expect(
      find.text(
        'Esse coroinha já está escalado em uma missa com horário próximo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Você entrou na escala.'), findsNothing);
    expect(repo.cargasMissasAbertas, 1);
  });

  testWidgets(
    'AB7: se a escala deixou de ser livre, avisa e atualiza a lista',
    (t) async {
      repo.missasAbertasCadastradas = [domingo];
      repo.erroAoEntrarNaEscala = const EscalaNaoLivre(
        'Esta missa não está com a escala livre.',
      );
      repo.aoEntrarNaEscala = null;
      await montar(t);
      // O administrador desligou a chave enquanto a tela estava aberta.
      repo.missasAbertasCadastradas = [];

      await entrarNaPrimeira(t);

      expect(
        find.text('Esta missa não está com a escala livre.'),
        findsOneWidget,
      );
      expect(repo.cargasMissasAbertas, 2);
      expect(find.text('Nenhuma missa aberta no momento.'), findsOneWidget);
    },
  );

  testWidgets('AB8: erro inesperado mostra uma mensagem genérica', (t) async {
    repo.missasAbertasCadastradas = [domingo];
    repo.erroAoEntrarNaEscala = Exception('SocketException: sem rede');
    await montar(t);

    await entrarNaPrimeira(t);

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets(
    'AB9: se só o recarregamento falhar, não diz que a entrada falhou',
    (t) async {
      repo.missasAbertasCadastradas = [domingo];
      await montar(t);
      repo.aoEntrarNaEscala = (id) =>
          repo.erroAoCarregarMissasAbertas = Exception('sem rede');

      await entrarNaPrimeira(t);

      expect(repo.entradasNaEscala, ['m1']);
      expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
      expect(
        find.text('Não foi possível carregar as missas abertas.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('AB10: enquanto entra, os botões ficam bloqueados', (t) async {
    repo.missasAbertasCadastradas = [domingo, quarta];
    repo.travarEntrarNaEscala = Completer<void>();
    await montar(t);

    await t.tap(find.text('Entrar na escala').first);
    await t.pump();

    final botoes = t.widgetList<FilledButton>(find.byType(FilledButton));
    expect(botoes.length, 2);
    expect(botoes.every((b) => b.onPressed == null), isTrue);
    expect(repo.entradasNaEscala.length, 1);

    repo.travarEntrarNaEscala!.complete();
    await t.pumpAndSettle();
  });

  testWidgets(
    'AB11: [guarda] se só a recarga falhar, mostra a falha de carga',
    (t) async {
      repo.missasAbertasCadastradas = [domingo];
      repo.aoEntrarNaEscala = (_) =>
          repo.erroAoCarregarMissasAbertas = Exception('sem sinal');
      await montar(t);

      await entrarNaPrimeira(t);

      expect(repo.entradasNaEscala, ['m1']); // entrou, uma única vez
      expect(
        find.text('Não foi possível carregar as missas abertas.'),
        findsOneWidget,
      );
      expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
    },
  );
}
