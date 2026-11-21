import 'dart:async';

import 'package:escala_app/data/pessoa.dart';
import 'package:escala_app/telas/pessoas_page.dart';
import 'package:escala_core/escala_core.dart' hide Coroinha;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  const ana = Pessoa(id: 'p1', nome: 'Ana', papel: 'coroinha', ativo: true);
  const bia = Pessoa(id: 'p2', nome: 'Bia', papel: 'admin', ativo: true);
  const caio = Pessoa(id: 'p3', nome: 'Caio', papel: 'coroinha', ativo: false);
  const dora = Pessoa(id: 'p4', nome: 'Dora', papel: 'admin', ativo: false);

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(MaterialApp(home: PessoasPage(repositorio: repo)));
    await t.pumpAndSettle();
  }

  Finder noDialogo(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  /// Abre o menu da linha da pessoa [nome].
  Future<void> abrirMenu(WidgetTester t, String nome) async {
    await t.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, nome),
        matching: find.byIcon(Icons.more_vert),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> escolherAcao(WidgetTester t, String nome, String acao) async {
    await abrirMenu(t, nome);
    await t.tap(find.text(acao));
    await t.pumpAndSettle();
  }

  // ---------- lista ----------

  testWidgets('PG1: lista as pessoas com o papel e a situação', (t) async {
    repo.pessoasCadastradas = [ana, bia, caio];
    await montar(t);

    expect(find.text('Pessoas'), findsOneWidget); // título
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Coroinha'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Caio'), findsOneWidget);
    expect(find.text('Coroinha · Inativo'), findsOneWidget);
  });

  testWidgets('PG2: sem ninguém cadastrado, avisa', (t) async {
    await montar(t);

    expect(find.text('Nenhuma pessoa cadastrada.'), findsOneWidget);
  });

  testWidgets('PG3: enquanto carrega, mostra um indicador de progresso', (
    t,
  ) async {
    repo.travarCargaPessoas = Completer<void>();
    await t.pumpWidget(MaterialApp(home: PessoasPage(repositorio: repo)));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.travarCargaPessoas!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('PG4: falha ao carregar avisa e permite tentar de novo', (
    t,
  ) async {
    repo.erroAoCarregarPessoas = Exception('sem rede');
    await montar(t);
    expect(find.text('Não foi possível carregar as pessoas.'), findsOneWidget);
    expect(find.textContaining('sem rede'), findsNothing);

    repo.erroAoCarregarPessoas = null;
    repo.pessoasCadastradas = [ana];
    await t.tap(find.text('Tentar de novo'));
    await t.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
  });

  // ---------- o menu de cada pessoa ----------

  testWidgets(
    'PG5: pessoa ativa e coroinha: Desativar e Tornar administrador',
    (t) async {
      repo.pessoasCadastradas = [ana];
      await montar(t);

      await abrirMenu(t, 'Ana');

      expect(find.text('Desativar'), findsOneWidget);
      expect(find.text('Tornar administrador'), findsOneWidget);
      expect(find.text('Ativar'), findsNothing);
      expect(find.text('Tornar coroinha'), findsNothing);
    },
  );

  testWidgets(
    'PG6: pessoa inativa e administradora: Ativar e Tornar coroinha',
    (t) async {
      repo.pessoasCadastradas = [dora];
      await montar(t);

      await abrirMenu(t, 'Dora');

      expect(find.text('Ativar'), findsOneWidget);
      expect(find.text('Tornar coroinha'), findsOneWidget);
      expect(find.text('Desativar'), findsNothing);
      expect(find.text('Tornar administrador'), findsNothing);
    },
  );

  // ---------- desativar e ativar ----------

  testWidgets(
    'PG7: Desativar pede confirmação com o nome e ainda não desativa',
    (t) async {
      repo.pessoasCadastradas = [ana];
      await montar(t);

      await escolherAcao(t, 'Ana', 'Desativar');

      expect(find.text('Desativar pessoa?'), findsOneWidget);
      expect(
        find.textContaining('Ana não poderá mais entrar no app'),
        findsOneWidget,
      );
      expect(noDialogo(find.text('Desativar')), findsOneWidget);
      expect(noDialogo(find.text('Cancelar')), findsOneWidget);
      expect(repo.ativosDefinidos, isEmpty);
    },
  );

  testWidgets('PG8: confirmar desativa a pessoa e recarrega a lista', (
    t,
  ) async {
    repo.pessoasCadastradas = [ana];
    repo.aoDefinirAtivo = (id, ativo) => repo.pessoasCadastradas = [
      const Pessoa(id: 'p1', nome: 'Ana', papel: 'coroinha', ativo: false),
    ];
    await montar(t);
    await escolherAcao(t, 'Ana', 'Desativar');

    await t.tap(noDialogo(find.text('Desativar')));
    await t.pumpAndSettle();

    expect(repo.ativosDefinidos, [(pessoaId: 'p1', ativo: false)]);
    expect(repo.cargasPessoas, 2);
    expect(find.text('Coroinha · Inativo'), findsOneWidget);
  });

  testWidgets('PG9: Cancelar na confirmação não desativa ninguém', (t) async {
    repo.pessoasCadastradas = [ana];
    await montar(t);
    await escolherAcao(t, 'Ana', 'Desativar');

    await t.tap(noDialogo(find.text('Cancelar')));
    await t.pumpAndSettle();

    expect(repo.ativosDefinidos, isEmpty);
    expect(repo.cargasPessoas, 1);
    expect(find.text('Desativar pessoa?'), findsNothing);
  });

  testWidgets('PG10: Ativar age direto, sem confirmação, e recarrega', (
    t,
  ) async {
    repo.pessoasCadastradas = [caio];
    await montar(t);

    await escolherAcao(t, 'Caio', 'Ativar');

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.ativosDefinidos, [(pessoaId: 'p3', ativo: true)]);
    expect(repo.cargasPessoas, 2);
  });

  // ---------- mudar o papel ----------

  testWidgets('PG11: Tornar administrador pede confirmação e então muda', (
    t,
  ) async {
    repo.pessoasCadastradas = [ana];
    await montar(t);

    await escolherAcao(t, 'Ana', 'Tornar administrador');
    expect(find.text('Alterar papel?'), findsOneWidget);
    expect(find.text('Ana passará a ser administrador.'), findsOneWidget);
    expect(repo.papeisDefinidos, isEmpty);

    await t.tap(noDialogo(find.text('Alterar')));
    await t.pumpAndSettle();

    expect(repo.papeisDefinidos, [(pessoaId: 'p1', papel: 'admin')]);
    expect(repo.cargasPessoas, 2);
  });

  testWidgets('PG12: Tornar coroinha pede confirmação e então muda', (t) async {
    repo.pessoasCadastradas = [bia];
    await montar(t);

    await escolherAcao(t, 'Bia', 'Tornar coroinha');
    expect(find.text('Bia passará a ser coroinha.'), findsOneWidget);

    await t.tap(noDialogo(find.text('Alterar')));
    await t.pumpAndSettle();

    expect(repo.papeisDefinidos, [(pessoaId: 'p2', papel: 'coroinha')]);
  });

  testWidgets('PG13: Cancelar na mudança de papel não muda nada', (t) async {
    repo.pessoasCadastradas = [ana];
    await montar(t);
    await escolherAcao(t, 'Ana', 'Tornar administrador');

    await t.tap(noDialogo(find.text('Cancelar')));
    await t.pumpAndSettle();

    expect(repo.papeisDefinidos, isEmpty);
    expect(repo.cargasPessoas, 1);
  });

  // ---------- erros ----------

  testWidgets('PG14: pessoa com missas futuras mostra a mensagem do banco', (
    t,
  ) async {
    repo.pessoasCadastradas = [ana];
    repo.erroAoDefinirAtivo = const TemEscalacoesFuturas(
      'Essa pessoa tem missas futuras. Retire-a da escala antes.',
    );
    await montar(t);
    await escolherAcao(t, 'Ana', 'Desativar');

    await t.tap(noDialogo(find.text('Desativar')));
    await t.pumpAndSettle();

    expect(
      find.text('Essa pessoa tem missas futuras. Retire-a da escala antes.'),
      findsOneWidget,
    );
    expect(find.text('Ana'), findsOneWidget);
    expect(repo.cargasPessoas, 1);
  });

  testWidgets('PG15: o último administrador não pode virar coroinha', (
    t,
  ) async {
    repo.pessoasCadastradas = [bia];
    repo.erroAoDefinirPapel = const UltimoAdmin(
      'O sistema precisa de pelo menos um administrador ativo.',
    );
    await montar(t);
    await escolherAcao(t, 'Bia', 'Tornar coroinha');

    await t.tap(noDialogo(find.text('Alterar')));
    await t.pumpAndSettle();

    expect(
      find.text('O sistema precisa de pelo menos um administrador ativo.'),
      findsOneWidget,
    );
    expect(repo.cargasPessoas, 1);
  });

  testWidgets('PG16: erro inesperado mostra uma mensagem genérica', (t) async {
    repo.pessoasCadastradas = [caio];
    repo.erroAoDefinirAtivo = Exception('SocketException: sem rede');
    await montar(t);

    await escolherAcao(t, 'Caio', 'Ativar');

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets(
    'PG17: se só o recarregamento falhar, não diz que a ação falhou',
    (t) async {
      repo.pessoasCadastradas = [caio];
      await montar(t);
      repo.aoDefinirAtivo = (id, ativo) =>
          repo.erroAoCarregarPessoas = Exception('sem rede');

      await escolherAcao(t, 'Caio', 'Ativar');

      expect(repo.ativosDefinidos, [(pessoaId: 'p3', ativo: true)]);
      expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
      expect(
        find.text('Não foi possível carregar as pessoas.'),
        findsOneWidget,
      );
    },
  );
}
