import 'package:escala_app/data/item_escala.dart';
import 'package:escala_app/data/mensagens.dart';
import 'package:escala_app/telas/minha_escala_page.dart';
import 'package:escala_app/telas/missas_abertas_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  // Uma hora fixa: a mensagem do dia depende da data.
  final agora = DateTime(2026, 11, 28, 10);

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  // Missa futura em relação ao "agora" acima, ainda pendente.
  ItemEscala item(String id, DateTime inicio) => ItemEscala(
    escalacaoId: id,
    missaId: 'm$id',
    inicio: inicio,
    local: 'Matriz',
    funcao: 'turiferário',
    status: StatusPresenca.pendente,
  );

  Future<void> montar(WidgetTester t) async {
    await t.pumpWidget(
      MaterialApp(
        home: MinhaEscalaPage(repositorio: repo, agora: () => agora),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('MV1: sem missas, mostra a frase de sempre e a mensagem do dia', (
    t,
  ) async {
    await montar(t);

    final mensagem = mensagemDoDia(agora);
    expect(find.text('Você não tem missas escaladas.'), findsOneWidget);
    expect(find.textContaining(mensagem.texto), findsOneWidget);
    expect(find.textContaining(mensagem.fonte), findsOneWidget);
  });

  testWidgets('MV2: sem missas, o botão leva às missas abertas', (t) async {
    await montar(t);

    await t.tap(find.text('Ver missas abertas'));
    await t.pumpAndSettle();

    expect(find.byType(MissasAbertasPage), findsOneWidget);
    expect(repo.cargasMissasAbertas, 1);
  });

  testWidgets('MV3: [guarda] se a carga falhar, não mostra a mensagem do dia', (
    t,
  ) async {
    repo.erroAoCarregar = Exception('sem rede');
    await montar(t);

    expect(
      find.text('Não foi possível carregar a sua escala.'),
      findsOneWidget,
    );
    expect(find.textContaining(mensagemDoDia(agora).texto), findsNothing);
    expect(find.text('Ver missas abertas'), findsNothing);
  });

  testWidgets('MV4: com missas, a mensagem do dia aparece abaixo da missa', (
    t,
  ) async {
    repo.escala = [item('e1', DateTime(2026, 12, 6, 18))];
    await montar(t);

    final mensagem = mensagemDoDia(agora);
    expect(find.textContaining(mensagem.texto), findsOneWidget);
    expect(find.textContaining(mensagem.fonte), findsOneWidget);
    final abaixo =
        t.getTopLeft(find.textContaining(mensagem.texto)).dy >
        t.getTopLeft(find.text('Confirmar presença')).dy;
    expect(abaixo, isTrue);
  });

  testWidgets('MV5: [guarda] com missas, não aparece o botão do estado vazio', (
    t,
  ) async {
    repo.escala = [item('e1', DateTime(2026, 12, 6, 18))];
    await montar(t);

    expect(find.text('Ver missas abertas'), findsNothing);
    expect(find.text('Você não tem missas escaladas.'), findsNothing);
  });

  testWidgets('MV6: com várias missas, a mensagem fica no fim da lista', (
    t,
  ) async {
    repo.escala = [
      for (var i = 0; i < 8; i++) item('e$i', DateTime(2026, 12, 6 + i, 18)),
    ];
    await montar(t);

    final mensagem = mensagemDoDia(agora);
    await t.scrollUntilVisible(
      find.textContaining(mensagem.texto),
      300,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );

    expect(find.textContaining(mensagem.texto), findsOneWidget);
    final abaixo =
        t.getTopLeft(find.textContaining(mensagem.texto)).dy >
        t.getTopLeft(find.text('Confirmar presença').last).dy;
    expect(abaixo, isTrue); // depois do último cartão visível
  });
}
