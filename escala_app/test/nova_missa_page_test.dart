import 'dart:async';

import 'package:escala_app/data/local.dart';
import 'package:escala_app/data/missa_cadastrada.dart';
import 'package:escala_app/telas/missas_page.dart';
import 'package:escala_app/telas/nova_missa_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;
  bool? resultado; // o que a tela devolveu ao fechar (true = criou a missa)

  // Domingo 06/12/2026 às 18:00.
  final domingo1800 = DateTime(2026, 12, 6, 18, 0);

  setUp(() {
    resultado = null;
    repo = FakeEscalaRepository()
      ..locaisCadastrados = [
        const Local(id: 'l1', nome: 'Matriz'),
        const Local(id: 'l2', nome: 'Capela'),
      ];
  });
  tearDown(() => repo.fechar());

  /// Abre a tela "Nova missa" por cima de uma tela qualquer, como o app faz, e
  /// guarda em [resultado] o que ela devolver ao fechar. [escolhida] é o que o
  /// seletor de data e hora devolve (nulo = a pessoa desistiu de escolher).
  Future<void> abrir(WidgetTester t, {DateTime? escolhida}) async {
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  resultado = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => NovaMissaPage(
                        repositorio: repo,
                        escolherDataHora: (_, _) async => escolhida,
                      ),
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  Future<void> escolherLocal(WidgetTester t, String nome) async {
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text(nome).last); // o item na lista que se abre
    await t.pumpAndSettle();
  }

  Future<void> escolherDataHora(WidgetTester t) async {
    await t.tap(find.text('Escolher data e hora'));
    await t.pumpAndSettle();
  }

  Future<void> salvar(WidgetTester t) async {
    await t.tap(find.text('Salvar missa'));
    await t.pumpAndSettle();
  }

  testWidgets('NM1: mostra o título, o botão de data e hora e o botão Salvar', (
    t,
  ) async {
    await abrir(t);

    expect(find.text('Nova missa'), findsOneWidget);
    expect(find.text('Escolher data e hora'), findsOneWidget);
    expect(find.text('Salvar missa'), findsOneWidget);
    expect(repo.cargasLocais, 1);
  });

  testWidgets('NM2: depois de escolher, o botão mostra o horário escolhido', (
    t,
  ) async {
    await abrir(t, escolhida: domingo1800);

    await escolherDataHora(t);

    expect(find.text('dom 06/12 às 18:00'), findsOneWidget);
  });

  testWidgets(
    'NM3: salvar sem escolher o local avisa e não chama o repositório',
    (t) async {
      await abrir(t, escolhida: domingo1800);
      await escolherDataHora(t);

      await salvar(t);

      expect(find.text('Escolha o local.'), findsOneWidget);
      expect(repo.missasCriadas, isEmpty);
    },
  );

  testWidgets(
    'NM4: salvar sem escolher a data avisa e não chama o repositório',
    (t) async {
      await abrir(t);
      await escolherLocal(t, 'Matriz');

      await salvar(t);

      expect(find.text('Escolha a data e a hora.'), findsOneWidget);
      expect(repo.missasCriadas, isEmpty);
    },
  );

  testWidgets(
    'NM5: salvar chama o repositório com o horário e o local e fecha a tela',
    (t) async {
      await abrir(t, escolhida: domingo1800);
      await escolherLocal(t, 'Capela');
      await escolherDataHora(t);

      await salvar(t);

      expect(repo.missasCriadas, [
        (inicio: domingo1800, localId: 'l2', escalaLivre: false),
      ]);
      expect(resultado, isTrue);
      expect(find.text('Nova missa'), findsNothing);
    },
  );

  testWidgets('NM6: erro de regra mostra a mensagem e mantém a tela aberta', (
    t,
  ) async {
    repo.erroAoCriarMissa = const HorarioInvalido('Informe um horário válido.');
    await abrir(t, escolhida: domingo1800);
    await escolherLocal(t, 'Matriz');
    await escolherDataHora(t);

    await salvar(t);

    expect(find.text('Informe um horário válido.'), findsOneWidget);
    expect(find.text('Nova missa'), findsOneWidget);
    expect(resultado, isNull);
  });

  testWidgets('NM7: erro inesperado mostra uma mensagem genérica', (t) async {
    repo.erroAoCriarMissa = Exception('SocketException: sem rede');
    await abrir(t, escolhida: domingo1800);
    await escolherLocal(t, 'Matriz');
    await escolherDataHora(t);

    await salvar(t);

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets('NM8: enquanto salva, o botão Salvar fica bloqueado', (t) async {
    repo.travarCriarMissa = Completer<void>();
    await abrir(t, escolhida: domingo1800);
    await escolherLocal(t, 'Matriz');
    await escolherDataHora(t);

    await t.tap(find.text('Salvar missa'));
    await t.pump();

    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(repo.missasCriadas.length, 1);

    repo.travarCriarMissa!.complete();
    await t.pumpAndSettle();
  });

  testWidgets(
    'NM9: sem nenhum local cadastrado, avisa para cadastrar um antes',
    (t) async {
      repo.locaisCadastrados = [];
      await abrir(t);

      expect(
        find.text('Cadastre um local antes de criar uma missa.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'NM10: falha ao carregar os locais avisa e permite tentar de novo',
    (t) async {
      repo.erroAoCarregarLocais = Exception('sem rede');
      await abrir(t);
      expect(find.text('Não foi possível carregar os locais.'), findsOneWidget);
      expect(find.textContaining('sem rede'), findsNothing);

      repo.erroAoCarregarLocais = null;
      await t.tap(find.text('Tentar de novo'));
      await t.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    },
  );

  testWidgets(
    'NM11: criando a partir da lista, a tela fecha e a lista de missas é recarregada',
    (t) async {
      repo.aoCriarMissa = (inicio, localId) => repo.missasCadastradas = [
        MissaCadastrada(
          id: 'm9',
          inicio: inicio,
          localId: localId,
          localNome: 'Capela',
        ),
      ];
      await t.pumpWidget(
        MaterialApp(
          home: MissasPage(
            repositorio: repo,
            escolherDataHora: (_, _) async => domingo1800,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(repo.cargasMissas, 1);

      await t.tap(find.text('Adicionar missa'));
      await t.pumpAndSettle();
      await escolherLocal(t, 'Capela');
      await escolherDataHora(t);
      await salvar(t);

      expect(find.text('Nova missa'), findsNothing);
      expect(repo.cargasMissas, 2);
      expect(find.text('dom 06/12 às 18:00'), findsOneWidget);
      expect(find.text('Capela'), findsOneWidget);
    },
  );

  testWidgets('NM12: ao editar, o seletor recebe o horário atual da missa', (
    t,
  ) async {
    final recebidos = <DateTime?>[];
    await t.pumpWidget(
      MaterialApp(
        home: NovaMissaPage(
          repositorio: repo,
          missa: MissaCadastrada(
            id: 'm1',
            inicio: DateTime(2026, 11, 22, 18, 0),
            localId: 'l1',
            localNome: 'Matriz',
          ),
          escolherDataHora: (_, atual) async {
            recebidos.add(atual);
            return null; // desistiu
          },
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('dom 22/11 às 18:00'));
    await t.pumpAndSettle();

    expect(recebidos, [DateTime(2026, 11, 22, 18, 0)]);
  });

  testWidgets('NM13: ao criar, o seletor começa sem horário', (t) async {
    final recebidos = <DateTime?>[];
    await t.pumpWidget(
      MaterialApp(
        home: NovaMissaPage(
          repositorio: repo,
          escolherDataHora: (_, atual) async {
            recebidos.add(atual);
            return null;
          },
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('Escolher data e hora'));
    await t.pumpAndSettle();

    expect(recebidos, [null]);
  });

  testWidgets('NM14: ao escolher de novo, o seletor recebe o último horário', (
    t,
  ) async {
    final recebidos = <DateTime?>[];
    await t.pumpWidget(
      MaterialApp(
        home: NovaMissaPage(
          repositorio: repo,
          escolherDataHora: (_, atual) async {
            recebidos.add(atual);
            return domingo1800;
          },
        ),
      ),
    );
    await t.pumpAndSettle();

    await t.tap(find.text('Escolher data e hora'));
    await t.pumpAndSettle();
    await t.tap(find.text('dom 06/12 às 18:00'));
    await t.pumpAndSettle();

    expect(recebidos, [null, domingo1800]);
  });
  testWidgets('NM15: o administrador pode ligar a escala livre ao criar', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: NovaMissaPage(
          repositorio: repo,
          escolherDataHora: (_, _) async => domingo1800,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Escala livre'), findsOneWidget);
    expect(
      t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );

    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Matriz').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Escolher data e hora'));
    await t.pumpAndSettle();
    await t.tap(find.byType(SwitchListTile));
    await t.pumpAndSettle();
    await t.tap(find.text('Salvar missa'));
    await t.pumpAndSettle();

    expect(repo.missasCriadas, [
      (inicio: domingo1800, localId: 'l1', escalaLivre: true),
    ]);
  });

  testWidgets(
    'NM16: ao editar, a chave começa como a missa está e vai ao salvar',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: NovaMissaPage(
            repositorio: repo,
            missa: MissaCadastrada(
              id: 'm1',
              inicio: DateTime(2026, 11, 22, 18, 0),
              localId: 'l1',
              localNome: 'Matriz',
              escalaLivre: true,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );

      await t.tap(find.byType(SwitchListTile)); // desliga
      await t.pumpAndSettle();
      await t.tap(find.text('Salvar alterações'));
      await t.pumpAndSettle();

      expect(repo.missasEditadas, [
        (
          missaId: 'm1',
          inicio: DateTime(2026, 11, 22, 18, 0),
          localId: 'l1',
          escalaLivre: false,
        ),
      ]);
    },
  );
}
