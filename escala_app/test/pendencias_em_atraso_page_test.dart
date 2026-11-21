import 'package:escala_app/data/pendencia_em_atraso.dart';
import 'package:escala_app/telas/pendencias_em_atraso_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(home: PendenciasEmAtrasoPage(repositorio: repo)),
    );
    await t.pumpAndSettle();
  }

  PendenciaEmAtraso criarPendencia({
    String nome = 'João da Silva',
    String funcao = 'Coroinha',
    String missaId = 'missa-1',
  }) {
    return PendenciaEmAtraso(
      escalacaoId: 'escalacao-1',
      missaId: missaId,
      inicio: DateTime(2026, 11, 21, 19),
      coroinhaId: 'coroinha-1',
      coroinhaNome: nome,
      funcao: funcao,
    );
  }

  testWidgets('PA1: mostra mensagem quando não existem pendências', (t) async {
    await montar(t);

    expect(find.text('Pendências em atraso'), findsOneWidget);
    expect(find.text('Nenhuma pendência em atraso.'), findsOneWidget);
  });

  testWidgets('PA2: mostra os dados dos coroinhas pendentes', (t) async {
    repo.pendenciasCadastradas = [
      criarPendencia(),
      criarPendencia(
        nome: 'Maria Oliveira',
        funcao: 'Cerimoniário',
        missaId: 'missa-2',
      ),
    ];

    await montar(t);

    expect(find.text('João da Silva'), findsOneWidget);
    expect(find.text('Maria Oliveira'), findsOneWidget);
    expect(find.text('Função: Coroinha'), findsOneWidget);
    expect(find.text('Função: Cerimoniário'), findsOneWidget);
    expect(find.text('Confirmação pendente'), findsNWidgets(2));
  });

  testWidgets('PA3: apresenta opção para tentar novamente quando ocorre erro', (
    t,
  ) async {
    repo.erroAoCarregarPendenciasEmAtraso = Exception('Falha simulada');

    await montar(t);

    expect(
      find.text('Não foi possível carregar as pendências.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('PA4: botão atualizar consulta novamente o repositório', (
    t,
  ) async {
    repo.pendenciasCadastradas = [criarPendencia()];

    await montar(t);

    expect(repo.cargasPendenciasEmAtraso, 1);
    expect(find.text('João da Silva'), findsOneWidget);

    repo.pendenciasCadastradas = [];

    await t.tap(find.byTooltip('Atualizar'));
    await t.pumpAndSettle();

    expect(repo.cargasPendenciasEmAtraso, 2);
    expect(find.text('Nenhuma pendência em atraso.'), findsOneWidget);
  });

  testWidgets('PA5: tentar novamente recupera uma consulta que falhou', (
    t,
  ) async {
    repo.erroAoCarregarPendenciasEmAtraso = Exception('Falha simulada');

    await montar(t);

    expect(
      find.text('Não foi possível carregar as pendências.'),
      findsOneWidget,
    );

    repo.erroAoCarregarPendenciasEmAtraso = null;
    repo.pendenciasCadastradas = [criarPendencia()];

    await t.tap(find.text('Tentar novamente'));
    await t.pumpAndSettle();

    expect(find.text('João da Silva'), findsOneWidget);
    expect(repo.cargasPendenciasEmAtraso, 2);
  });

  testWidgets(
    'PA6: [guarda] se a atualização falhar de imediato, mostra a falha de carga',
    (t) async {
      repo.pendenciasCadastradas = [criarPendencia()];
      await montar(t);
      expect(find.text('João da Silva'), findsOneWidget);

      repo.erroAoCarregarPendenciasEmAtraso = Exception('sem sinal');
      await t.tap(find.byTooltip('Atualizar'));
      await t.pumpAndSettle();

      expect(
        find.text('Não foi possível carregar as pendências.'),
        findsOneWidget,
      );
      expect(repo.cargasPendenciasEmAtraso, 2);
    },
  );
}
