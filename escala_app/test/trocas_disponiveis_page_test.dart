import 'dart:async';

import 'package:escala_app/data/troca_disponivel.dart';
import 'package:escala_app/telas/trocas_disponiveis_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  // A Ana pediu troca de uma missa domingo 22/11/2026 às 18:00.
  TrocaDisponivel troca({String id = 't1'}) => TrocaDisponivel(
    trocaId: id,
    inicio: DateTime(2026, 11, 22, 18, 0),
    local: 'Matriz',
    funcao: 'turiferário',
    titularNome: 'Ana',
  );

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(home: TrocasDisponiveisPage(repositorio: repo)),
    );
    await t.pumpAndSettle();
  }

  // Abre o aviso e confirma.
  Future<void> aceitar(WidgetTester t) async {
    await t.tap(find.text('Aceitar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sim, aceitar'));
    await t.pumpAndSettle();
  }

  testWidgets('TP1: enquanto carrega, mostra um indicador de progresso', (
    t,
  ) async {
    repo.travarCargaDisponiveis = Completer<void>();
    await t.pumpWidget(
      MaterialApp(home: TrocasDisponiveisPage(repositorio: repo)),
    );
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.travarCargaDisponiveis!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('TP2: mostra o horário, o local, a função e quem pediu a troca', (
    t,
  ) async {
    repo.disponiveis = [troca()];
    await montar(t);

    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
    expect(find.text('Matriz · turiferário'), findsOneWidget);
    expect(find.text('Pedido de Ana'), findsOneWidget);
    expect(find.text('Aceitar'), findsOneWidget);
  });

  testWidgets('TP3: sem trocas abertas, avisa', (t) async {
    await montar(t);
    expect(find.text('Nenhuma troca aberta no momento.'), findsOneWidget);
  });

  testWidgets('TP4: falha ao carregar avisa e permite tentar de novo', (
    t,
  ) async {
    repo.erroAoCarregarDisponiveis = Exception('sem rede');
    await montar(t);
    expect(find.text('Não foi possível carregar as trocas.'), findsOneWidget);
    expect(find.textContaining('sem rede'), findsNothing);

    repo.erroAoCarregarDisponiveis = null;
    repo.disponiveis = [troca()];
    await t.tap(find.text('Tentar de novo'));
    await t.pumpAndSettle();

    expect(find.text('Pedido de Ana'), findsOneWidget);
  });

  testWidgets(
    'TP5: tocar em Aceitar abre um aviso e ainda não chama o repositório',
    (t) async {
      repo.disponiveis = [troca()];
      await montar(t);

      await t.tap(find.text('Aceitar'));
      await t.pumpAndSettle();

      expect(find.text('Aceitar esta vaga?'), findsOneWidget);
      expect(
        find.textContaining('Você assumirá a vaga de Ana'),
        findsOneWidget,
      );
      expect(find.textContaining('já ficará confirmada'), findsOneWidget);
      expect(repo.aceites, isEmpty);
    },
  );

  testWidgets(
    'TP6: confirmar o aviso aceita a troca, avisa e recarrega a lista',
    (t) async {
      repo.disponiveis = [troca(id: 't1')];
      repo.aoAceitar = (id) => repo.disponiveis = [];
      await montar(t);

      await aceitar(t);

      expect(repo.aceites, ['t1']);
      expect(
        find.text('Troca aceita! A missa entrou na sua escala.'),
        findsOneWidget,
      );
      expect(find.text('Nenhuma troca aberta no momento.'), findsOneWidget);
      expect(repo.cargasDisponiveis, 2);
    },
  );

  testWidgets('TP7: recusar o aviso não aceita a troca', (t) async {
    repo.disponiveis = [troca()];
    await montar(t);

    await t.tap(find.text('Aceitar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Agora não'));
    await t.pumpAndSettle();

    expect(find.text('Aceitar esta vaga?'), findsNothing);
    expect(repo.aceites, isEmpty);
  });

  testWidgets(
    'TP8: conflito de horário diz "você", e mantém a troca na lista',
    (t) async {
      repo.disponiveis = [troca()];
      // A mensagem do domínio fala em "esse coroinha": a tela troca por "você".
      repo.erroAoAceitar = const ConflitoDeHorario('Esse coroinha já está...');
      await montar(t);

      await aceitar(t);

      expect(
        find.text('Você já está escalado em uma missa com horário próximo.'),
        findsOneWidget,
      );
      expect(find.text('Aceitar'), findsOneWidget);
      expect(repo.cargasDisponiveis, 1);
    },
  );

  testWidgets('TP9: já estar na missa também diz "você"', (t) async {
    repo.disponiveis = [troca()];
    repo.erroAoAceitar = const JaEscaladoNaMissa('Esse coroinha já está...');
    await montar(t);

    await aceitar(t);

    expect(find.text('Você já está escalado nesta missa.'), findsOneWidget);
  });

  testWidgets('TP10: troca que alguém já aceitou avisa e atualiza a lista', (
    t,
  ) async {
    repo.disponiveis = [troca()];
    repo.erroAoAceitar = const TrocaJaResolvida(
      'Esta troca não está mais aberta.',
    );
    await montar(t);
    repo.disponiveis = []; // outra pessoa levou a vaga

    await aceitar(t);

    expect(
      find.text('Esta troca já foi aceita por outra pessoa ou foi cancelada.'),
      findsOneWidget,
    );
    expect(repo.cargasDisponiveis, 2);
    expect(find.text('Nenhuma troca aberta no momento.'), findsOneWidget);
  });

  testWidgets('TP11: erro inesperado mostra uma mensagem genérica', (t) async {
    repo.disponiveis = [troca()];
    repo.erroAoAceitar = Exception('SocketException: sem rede');
    await montar(t);

    await aceitar(t);

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets('TP12: enquanto aceita, bloqueia o botão', (t) async {
    repo.disponiveis = [troca()];
    repo.travarAceite = Completer<void>();
    await montar(t);

    await t.tap(find.text('Aceitar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sim, aceitar'));
    await t.pump();

    final botao = t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Aceitar'),
    );
    expect(botao.onPressed, isNull);

    repo.travarAceite!.complete();
    await t.pumpAndSettle();
  });

  testWidgets(
    'TP13: [guarda] se só a recarga falhar, mostra a falha de carga',
    (t) async {
      repo.disponiveis = [troca()];
      repo.aoAceitar = (_) =>
          repo.erroAoCarregarDisponiveis = Exception('sem sinal');
      await montar(t);

      await aceitar(t);

      expect(repo.aceites, ['t1']); // aceitou, uma única vez
      expect(find.text('Não foi possível carregar as trocas.'), findsOneWidget);
      expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
    },
  );
}
