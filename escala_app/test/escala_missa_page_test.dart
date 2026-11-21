import 'dart:async';

import 'package:escala_app/data/coroinha.dart';
import 'package:escala_app/data/escalado_na_missa.dart';
import 'package:escala_app/data/missa_cadastrada.dart';
import 'package:escala_app/telas/escala_missa_page.dart';
import 'package:escala_core/escala_core.dart' hide Coroinha;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  final missa = MissaCadastrada(
    id: 'm1',
    inicio: DateTime(2026, 11, 22, 18, 0),
    localId: 'l1',
    localNome: 'Matriz',
  );

  const ana = EscaladoNaMissa(
    id: 'e1',
    coroinhaId: 'c1',
    nome: 'Ana',
    funcao: 'turiferário',
  );
  const bruno = EscaladoNaMissa(
    id: 'e2',
    coroinhaId: 'c2',
    nome: 'Bruno',
    funcao: 'cruciferário',
  );

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: EscalaMissaPage(repositorio: repo, missa: missa),
      ),
    );
    await t.pumpAndSettle();
  }

  Finder noDialogo(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  Future<void> pedirRetirada(WidgetTester t) async {
    await t.tap(find.byTooltip('Remover da escala').first);
    await t.pumpAndSettle();
  }

  // ---------- lista ----------

  testWidgets('EQ1: mostra a missa, quem está escalado e a contagem', (
    t,
  ) async {
    repo.escaladosPorMissa['m1'] = [ana, bruno];
    await montar(t);

    expect(find.text('Escala da missa'), findsOneWidget);
    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
    expect(find.text('Matriz'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('turiferário'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('cruciferário'), findsOneWidget);
    expect(find.text('2 participantes'), findsOneWidget);
  });

  testWidgets('EQ2: sem ninguém escalado, avisa', (t) async {
    await montar(t);

    expect(find.text('Nenhum coroinha escalado'), findsOneWidget);
    expect(find.text('0 participantes'), findsOneWidget);
  });

  testWidgets('EQ3: enquanto carrega, mostra um indicador de progresso', (
    t,
  ) async {
    // Sem travar a carga (o fake não tem esse recurso para escalados): o
    // indicador aparece no primeiro quadro, antes de a lista chegar.
    await t.pumpWidget(
      MaterialApp(
        home: EscalaMissaPage(repositorio: repo, missa: missa),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('EQ4: falha ao carregar avisa e permite tentar de novo', (
    t,
  ) async {
    repo.erroAoCarregarEscalados = Exception('sem rede');
    await montar(t);
    expect(
      find.text('Não foi possível carregar os escalados.'),
      findsOneWidget,
    );
    expect(find.textContaining('sem rede'), findsNothing);

    repo.erroAoCarregarEscalados = null;
    repo.escaladosPorMissa['m1'] = [ana];
    await t.tap(find.text('Tentar novamente'));
    await t.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
  });

  // ---------- retirar da escala ----------

  testWidgets('EQ5: retirar pede confirmação com o nome e ainda não retira', (
    t,
  ) async {
    repo.escaladosPorMissa['m1'] = [ana, bruno];
    await montar(t);

    await pedirRetirada(t);

    expect(find.text('Remover da escala?'), findsOneWidget);
    expect(find.text('Deseja remover Ana desta missa?'), findsOneWidget);
    expect(noDialogo(find.text('Remover')), findsOneWidget);
    expect(noDialogo(find.text('Cancelar')), findsOneWidget);
    expect(repo.escalacoesRemovidas, isEmpty);
  });

  testWidgets('EQ6: confirmar retira a pessoa e recarrega a lista', (t) async {
    repo.escaladosPorMissa['m1'] = [ana, bruno];
    repo.aoDesescalar = (id) => repo.escaladosPorMissa['m1'] = [bruno];
    await montar(t);
    await pedirRetirada(t);

    await t.tap(noDialogo(find.text('Remover')));
    await t.pumpAndSettle();

    expect(repo.escalacoesRemovidas, ['e1']);
    expect(repo.cargasEscaladosPorMissa['m1'], 2);
    expect(find.text('Ana'), findsNothing);
    expect(find.text('Bruno'), findsOneWidget);
  });

  testWidgets('EQ7: Cancelar na confirmação não retira ninguém', (t) async {
    repo.escaladosPorMissa['m1'] = [ana];
    await montar(t);
    await pedirRetirada(t);

    await t.tap(noDialogo(find.text('Cancelar')));
    await t.pumpAndSettle();

    expect(repo.escalacoesRemovidas, isEmpty);
    expect(repo.cargasEscaladosPorMissa['m1'], 1);
  });

  testWidgets(
    'EQ8: erro de regra ao retirar mostra a mensagem e mantém a lista',
    (t) async {
      repo.escaladosPorMissa['m1'] = [ana];
      repo.erroAoDesescalar = const MissaJaComecou('Esta missa já começou.');
      await montar(t);
      await pedirRetirada(t);

      await t.tap(noDialogo(find.text('Remover')));
      await t.pumpAndSettle();

      expect(find.text('Esta missa já começou.'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(repo.cargasEscaladosPorMissa['m1'], 1);
    },
  );

  testWidgets('EQ9: erro inesperado ao retirar mostra mensagem genérica', (
    t,
  ) async {
    repo.escaladosPorMissa['m1'] = [ana];
    repo.erroAoDesescalar = Exception('SocketException: sem rede');
    await montar(t);
    await pedirRetirada(t);

    await t.tap(noDialogo(find.text('Remover')));
    await t.pumpAndSettle();

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets(
    'EQ10: se só o recarregamento falhar, não diz que a retirada falhou',
    (t) async {
      repo.escaladosPorMissa['m1'] = [ana];
      await montar(t);
      repo.aoDesescalar = (id) =>
          repo.erroAoCarregarEscalados = Exception('sem rede');
      await pedirRetirada(t);

      await t.tap(noDialogo(find.text('Remover')));
      await t.pumpAndSettle();

      expect(repo.escalacoesRemovidas, ['e1']);
      expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
      expect(
        find.text('Não foi possível carregar os escalados.'),
        findsOneWidget,
      );
    },
  );

  // ---------- adicionar coroinha ----------

  Future<void> abrirAdicionar(WidgetTester t) async {
    await t.tap(find.text('Adicionar coroinha'));
    await t.pumpAndSettle();
  }

  Future<void> escolherCoroinha(WidgetTester t, String nome) async {
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text(nome).last);
    await t.pumpAndSettle();
  }

  testWidgets('EQ11: adicionar manda missa, coroinha e função e recarrega', (
    t,
  ) async {
    repo.coroinhasCadastrados = [
      const Coroinha(id: 'c1', nome: 'Ana'),
      const Coroinha(id: 'c3', nome: 'Carla'),
    ];
    repo.escaladosPorMissa['m1'] = [ana];
    repo.aoEscalar = (missaId, coroinhaId, funcao) =>
        repo.escaladosPorMissa['m1'] = [
          ana,
          EscaladoNaMissa(
            id: 'e3',
            coroinhaId: coroinhaId,
            nome: 'Carla',
            funcao: funcao,
          ),
        ];
    await montar(t);

    await abrirAdicionar(t);
    await escolherCoroinha(t, 'Carla');
    await t.enterText(find.byType(TextFormField), '  cruciferário ');
    await t.tap(noDialogo(find.text('Adicionar')));
    await t.pumpAndSettle();

    expect(repo.escalacoesCriadas, [
      (missaId: 'm1', coroinhaId: 'c3', funcao: 'cruciferário'),
    ]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Carla'), findsOneWidget);
    expect(find.text('cruciferário'), findsOneWidget);
  });

  testWidgets('EQ12: sem coroinha disponível, avisa e não abre o diálogo', (
    t,
  ) async {
    repo.coroinhasCadastrados = [const Coroinha(id: 'c1', nome: 'Ana')];
    repo.escaladosPorMissa['m1'] = [ana];
    await montar(t);

    await abrirAdicionar(t);

    expect(
      find.text('Não há coroinhas disponíveis para adicionar.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets(
      'EQ13: sem escolher coroinha, o diálogo cobra o coroinha (a função é opcional)',
      (t) async {
    repo.coroinhasCadastrados = [const Coroinha(id: 'c3', nome: 'Carla')];
    await montar(t);

    await abrirAdicionar(t);
    await t.tap(noDialogo(find.text('Adicionar')));
    await t.pumpAndSettle();

    expect(find.text('Selecione um coroinha.'), findsOneWidget);
    expect(find.text('Informe a função.'), findsNothing);
    expect(repo.escalacoesCriadas, isEmpty);
  });

  testWidgets(
      'EQ16: função em branco é enviada vazia (o banco usa "A definir")',
      (t) async {
    repo.coroinhasCadastrados = [const Coroinha(id: 'c3', nome: 'Carla')];
    await montar(t);

    await abrirAdicionar(t);
    await escolherCoroinha(t, 'Carla');
    await t.tap(noDialogo(find.text('Adicionar')));
    await t.pumpAndSettle();

    expect(repo.escalacoesCriadas, [
      (missaId: 'm1', coroinhaId: 'c3', funcao: ''),
    ]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('EQ17: o diálogo avisa o que acontece com a função em branco',
      (t) async {
    repo.coroinhasCadastrados = [const Coroinha(id: 'c3', nome: 'Carla')];
    await montar(t);

    await abrirAdicionar(t);

    expect(
      find.text('Se ficar em branco, a função será "A definir".'),
      findsOneWidget,
    );
  });

  testWidgets('EQ14: conflito de horário mostra a mensagem do banco', (
    t,
  ) async {
    repo.coroinhasCadastrados = [const Coroinha(id: 'c3', nome: 'Carla')];
    repo.erroAoEscalar = const ConflitoDeHorario(
      'Esse coroinha já está escalado em uma missa com horário próximo.',
    );
    await montar(t);

    await abrirAdicionar(t);
    // Abrir o diálogo já consulta a lista (para tirar quem está escalado).
    final cargasAoAbrir = repo.cargasEscaladosPorMissa['m1'];
    await escolherCoroinha(t, 'Carla');
    await t.enterText(find.byType(TextFormField), 'turiferário');
    await t.tap(noDialogo(find.text('Adicionar')));
    await t.pumpAndSettle();

    expect(
      find.text(
        'Esse coroinha já está escalado em uma missa com horário próximo.',
      ),
      findsOneWidget,
    );
    expect(
      repo.cargasEscaladosPorMissa['m1'],
      cargasAoAbrir,
    ); // não recarregou // não recarregou
  });

  testWidgets(
    'EQ15: enquanto escala, o botão Adicionar coroinha fica bloqueado',
    (t) async {
      repo.coroinhasCadastrados = [const Coroinha(id: 'c3', nome: 'Carla')];
      repo.travarEscalar = Completer<void>();
      await montar(t);

      await abrirAdicionar(t);
      await escolherCoroinha(t, 'Carla');
      await t.enterText(find.byType(TextFormField), 'turiferário');
      await t.tap(noDialogo(find.text('Adicionar')));
      await t.pump();

      final botao = t.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(botao.onPressed, isNull);

      repo.travarEscalar!.complete();
      await t.pumpAndSettle();
    },
  );
}
