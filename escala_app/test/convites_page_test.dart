import 'dart:async';

import 'package:escala_app/telas/convites_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;
  late List<String> copiados;

  setUp(() {
    repo = FakeEscalaRepository();
    copiados = [];
  });
  tearDown(() => repo.fechar());

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: ConvitesPage(
          repositorio: repo,
          copiar: (texto) async => copiados.add(texto),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> gerar(WidgetTester t) async {
    await t.tap(find.text('Gerar convite'));
    await t.pumpAndSettle();
  }

  testWidgets(
    'CV1: mostra a opção "menor de idade" marcada e o botão Gerar convite',
    (t) async {
      await montar(t);

      final opcao = t.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(opcao.value, isTrue);
      expect(
        find.text('Menor de idade (exige o nome do responsável)'),
        findsOneWidget,
      );
      expect(find.text('Gerar convite'), findsOneWidget);
    },
  );

  testWidgets(
    'CV2: gerar com a opção marcada pede um convite que exige responsável',
    (t) async {
      await montar(t);
      await gerar(t);

      expect(repo.convitesGerados, [true]);
    },
  );

  testWidgets(
    'CV3: desmarcar a opção pede um convite de adulto (sem responsável)',
    (t) async {
      await montar(t);

      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await gerar(t);

      expect(repo.convitesGerados, [false]);
    },
  );

  testWidgets(
    'CV4: o código gerado aparece, com o aviso de que só aparece agora',
    (t) async {
      await montar(t);
      await gerar(t);

      expect(find.text('ABCD2345'), findsOneWidget);
      expect(
        find.text('Este código só aparece agora e vale por 7 dias.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CV5: Copiar código manda o código para a área de transferência',
    (t) async {
      await montar(t);
      await gerar(t);

      await t.tap(find.text('Copiar código'));
      await t.pumpAndSettle();

      expect(copiados, ['ABCD2345']);
      expect(find.text('Código copiado.'), findsOneWidget);
    },
  );

  testWidgets('CV6: erro de regra mostra a mensagem e nenhum código', (
    t,
  ) async {
    repo.erroAoGerarConvite = const PermissaoNegada(
      'Você não tem permissão para fazer isso.',
    );
    await montar(t);
    await gerar(t);

    expect(
      find.text('Você não tem permissão para fazer isso.'),
      findsOneWidget,
    );
    expect(find.text('ABCD2345'), findsNothing);
    expect(find.text('Copiar código'), findsNothing);
  });

  testWidgets('CV7: erro inesperado mostra uma mensagem genérica', (t) async {
    repo.erroAoGerarConvite = Exception('SocketException: sem rede');
    await montar(t);
    await gerar(t);

    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
    expect(find.textContaining('Socket'), findsNothing);
  });

  testWidgets('CV8: enquanto gera, bloqueia o botão e mostra progresso', (
    t,
  ) async {
    repo.travarGeracao = Completer<void>();
    await montar(t);

    await t.tap(find.text('Gerar convite'));
    await t.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    repo.travarGeracao!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('CV9: gerar outro convite substitui o código anterior', (
    t,
  ) async {
    await montar(t);
    await gerar(t);
    expect(find.text('ABCD2345'), findsOneWidget);

    repo.codigoGerado = 'WXYZ6789';
    await gerar(t);

    expect(find.text('WXYZ6789'), findsOneWidget);
    expect(find.text('ABCD2345'), findsNothing);
  });
}
