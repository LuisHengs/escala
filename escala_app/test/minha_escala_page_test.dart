import 'dart:async';

import 'package:escala_app/data/item_escala.dart';
import 'package:escala_app/telas/minha_escala_page.dart';
import 'package:escala_core/escala_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repo;

  setUp(() => repo = FakeEscalaRepository());
  tearDown(() => repo.fechar());

  // Uma missa domingo 22/11/2026 às 18:00: o prazo para confirmar é 16:00.
  // Com troca: true, a escalação tem a troca "t1" aberta.
  ItemEscala item({
    String id = 'e1',
    StatusPresenca status = StatusPresenca.pendente,
    bool atraso = false,
    bool troca = false,
    bool auto = false,
  }) => ItemEscala(
    escalacaoId: id,
    missaId: 'm1',
    inicio: DateTime(2026, 11, 22, 18, 0),
    local: 'Matriz',
    funcao: 'turiferário',
    status: status,
    confirmadoComAtraso: atraso,
    trocaAbertaId: troca ? 't1' : null,
    autoEscalada: auto,
  );

  Future<void> montar(
    WidgetTester t, {
    DateTime? agora,
    bool administrador = false,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: MinhaEscalaPage(
          repositorio: repo,
          agora: () => agora ?? DateTime(2026, 11, 22, 10, 0),
          administrador: administrador,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  // ---------- carregar e mostrar ----------

  testWidgets('P1: enquanto carrega, mostra um indicador de progresso', (
    t,
  ) async {
    repo.travarCarga = Completer<void>();
    await t.pumpWidget(MaterialApp(home: MinhaEscalaPage(repositorio: repo)));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repo.travarCarga!.complete();
    await t.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('P2: mostra o horário, o local e a função de cada missa', (
    t,
  ) async {
    repo.escala = [item()];
    await montar(t);

    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
    expect(find.text('Matriz · turiferário'), findsOneWidget);
  });

  testWidgets('P3: pendente tem o botão Confirmar; confirmado não tem', (
    t,
  ) async {
    repo.escala = [
      item(id: 'a'),
      item(id: 'b', status: StatusPresenca.confirmado),
    ];
    await montar(t);

    expect(find.text('Confirmar presença'), findsOneWidget);
    expect(find.text('Confirmado'), findsOneWidget);
  });

  testWidgets('P4: confirmado com atraso aparece como tal', (t) async {
    repo.escala = [item(status: StatusPresenca.confirmado, atraso: true)];
    await montar(t);

    expect(find.text('Confirmado (com atraso)'), findsOneWidget);
  });

  testWidgets('P5: confirmar chama o repositório e recarrega a lista', (
    t,
  ) async {
    repo.escala = [item(id: 'e1')];
    repo.aoConfirmar = (id) =>
        repo.escala = [item(id: id, status: StatusPresenca.confirmado)];
    await montar(t);
    expect(repo.cargas, 1);

    await t.tap(find.text('Confirmar presença'));
    await t.pumpAndSettle();

    expect(repo.confirmacoes, ['e1']);
    expect(repo.cargas, 2);
    expect(find.text('Confirmado'), findsOneWidget);
    expect(find.text('Confirmar presença'), findsNothing);
    // O recarregamento não pode ter falhado em silêncio.
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('P6: sem missas, avisa que não há escala', (t) async {
    await montar(t);
    expect(find.text('Você não tem missas escaladas.'), findsOneWidget);
  });

  testWidgets('P7: erro ao confirmar mostra a mensagem e mantém o botão', (
    t,
  ) async {
    repo.escala = [item()];
    repo.erroAoConfirmar = const PermissaoNegada(
      'Você não tem permissão para fazer isso.',
    );
    await montar(t);

    await t.tap(find.text('Confirmar presença'));
    await t.pumpAndSettle();

    expect(
      find.text('Você não tem permissão para fazer isso.'),
      findsOneWidget,
    );
    expect(find.text('Confirmar presença'), findsOneWidget);
  });

  testWidgets('P8: falha ao carregar avisa e permite tentar de novo', (
    t,
  ) async {
    repo.erroAoCarregar = Exception('sem rede');
    await montar(t);
    expect(
      find.text('Não foi possível carregar a sua escala.'),
      findsOneWidget,
    );
    expect(find.textContaining('sem rede'), findsNothing);

    repo.erroAoCarregar = null;
    repo.escala = [item()];
    await t.tap(find.text('Tentar de novo'));
    await t.pumpAndSettle();

    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
  });

  testWidgets('P9: troca aberta aparece como etiqueta', (t) async {
    repo.escala = [item(troca: true)];
    await montar(t);

    expect(find.text('Troca aberta'), findsOneWidget);
  });

  // ---------- prazo ----------

  testWidgets('P10: antes do prazo, mostra até quando dá para confirmar', (
    t,
  ) async {
    repo.escala = [item()];
    await montar(t, agora: DateTime(2026, 11, 22, 15, 59));

    expect(find.text('Confirme até dom 22/11 às 16:00'), findsOneWidget);
  });

  testWidgets('P11: depois do prazo, avisa que ainda dá para confirmar', (
    t,
  ) async {
    repo.escala = [item()];
    await montar(t, agora: DateTime(2026, 11, 22, 17, 0));

    expect(
      find.text('O prazo passou, mas você ainda pode confirmar.'),
      findsOneWidget,
    );
    expect(find.text('Confirmar presença'), findsOneWidget);
  });

  testWidgets('P12: no instante exato do prazo, já conta como passou', (
    t,
  ) async {
    repo.escala = [item()];
    await montar(t, agora: DateTime(2026, 11, 22, 16, 0));

    expect(
      find.text('O prazo passou, mas você ainda pode confirmar.'),
      findsOneWidget,
    );
  });

  testWidgets('P13: Sair chama o repositório', (t) async {
    await montar(t);
    await t.tap(find.text('Sair'));
    await t.pump();

    expect(repo.chamadasSair, 1);
  });

  // ---------- pedir e cancelar troca ----------

  testWidgets('P14: sem troca aberta, mostra o botão Pedir troca', (t) async {
    repo.escala = [item()];
    await montar(t);

    expect(find.text('Pedir troca'), findsOneWidget);
    expect(find.text('Cancelar pedido de troca'), findsNothing);
  });

  testWidgets(
    'P15: tocar em Pedir troca abre um aviso e ainda não chama o repositório',
    (t) async {
      repo.escala = [item()];
      await montar(t);

      await t.tap(find.text('Pedir troca'));
      await t.pumpAndSettle();

      expect(find.text('Pedir troca?'), findsOneWidget);
      expect(find.textContaining('Todos os coroinhas'), findsOneWidget);
      expect(repo.trocasAbertas, isEmpty);
    },
  );

  testWidgets('P16: confirmar o aviso abre a troca e recarrega a lista', (
    t,
  ) async {
    repo.escala = [item(id: 'e1')];
    repo.aoAbrirTroca = (id) => repo.escala = [item(id: id, troca: true)];
    await montar(t);

    await t.tap(find.text('Pedir troca'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sim, pedir troca'));
    await t.pumpAndSettle();

    expect(repo.trocasAbertas, ['e1']);
    expect(find.text('Troca aberta'), findsOneWidget);
    expect(find.text('Cancelar pedido de troca'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('P17: recusar o aviso não pede a troca', (t) async {
    repo.escala = [item()];
    await montar(t);

    await t.tap(find.text('Pedir troca'));
    await t.pumpAndSettle();
    await t.tap(find.text('Agora não'));
    await t.pumpAndSettle();

    expect(find.text('Pedir troca?'), findsNothing);
    expect(repo.trocasAbertas, isEmpty);
  });

  testWidgets(
    'P18: com troca aberta, mostra Cancelar pedido e some o Pedir troca',
    (t) async {
      repo.escala = [item(troca: true)];
      await montar(t);

      expect(find.text('Cancelar pedido de troca'), findsOneWidget);
      expect(find.text('Pedir troca'), findsNothing);
    },
  );

  testWidgets(
    'P19: cancelar o pedido chama o repositório com o id da troca e recarrega',
    (t) async {
      repo.escala = [item(troca: true)];
      repo.aoCancelarTroca = (id) => repo.escala = [item()];
      await montar(t);

      await t.tap(find.text('Cancelar pedido de troca'));
      await t.pumpAndSettle();

      expect(repo.trocasCanceladas, ['t1']);
      expect(find.text('Pedir troca'), findsOneWidget);
      expect(find.text('Troca aberta'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('P20: erro ao pedir a troca mostra a mensagem e mantém o botão', (
    t,
  ) async {
    repo.escala = [item()];
    repo.erroAoAbrirTroca = const MissaJaComecou('Esta missa já começou.');
    await montar(t);

    await t.tap(find.text('Pedir troca'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sim, pedir troca'));
    await t.pumpAndSettle();

    expect(find.text('Esta missa já começou.'), findsOneWidget);
    expect(find.text('Pedir troca'), findsOneWidget);
  });

  // ---------- ir para as trocas dos outros ----------

  testWidgets('P22: o botão Trocas abertas leva à lista de trocas dos outros', (
    t,
  ) async {
    await montar(t);

    await t.tap(find.text('Trocas abertas'));
    await t.pumpAndSettle();

    expect(find.text('Nenhuma troca aberta no momento.'), findsOneWidget);
  });

  testWidgets('P23: ao voltar da lista de trocas, a escala é recarregada', (
    t,
  ) async {
    await montar(t);
    expect(repo.cargas, 1);

    await t.tap(find.text('Trocas abertas'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();

    expect(repo.cargas, 2);
  });

  // ---------- missas abertas (escala livre) ----------

  testWidgets('P27: o botão Missas abertas leva à lista de missas abertas', (
    t,
  ) async {
    await montar(t);

    await t.tap(find.text('Missas abertas'));
    await t.pumpAndSettle();

    expect(find.text('Nenhuma missa aberta no momento.'), findsOneWidget);
  });

  testWidgets('P28: ao voltar das missas abertas, a escala é recarregada', (
    t,
  ) async {
    await montar(t);
    expect(repo.cargas, 1);

    await t.tap(find.text('Missas abertas'));
    await t.pumpAndSettle();
    await t.pageBack();
    await t.pumpAndSettle();

    expect(repo.cargas, 2);
  });

  // ---------- sair da escala que a própria pessoa escolheu ----------

  Finder noDialogo(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  testWidgets('P29: escalada por conta própria: aviso e botão Sair da escala', (
    t,
  ) async {
    repo.escala = [item(auto: true)];
    await montar(t);

    expect(find.text('Você se escalou'), findsOneWidget);
    expect(find.text('Sair da escala'), findsOneWidget);
  });

  testWidgets('P30: escalada pelo administrador: sem o botão Sair da escala', (
    t,
  ) async {
    repo.escala = [item()];
    await montar(t);

    expect(find.text('Você se escalou'), findsNothing);
    expect(find.text('Sair da escala'), findsNothing);
    expect(find.text('Pedir troca'), findsOneWidget);
  });

  testWidgets('P31: Sair da escala pede confirmação e ainda não sai', (
    t,
  ) async {
    repo.escala = [item(auto: true)];
    await montar(t);

    await t.tap(find.text('Sair da escala'));
    await t.pumpAndSettle();

    expect(find.text('Sair da escala?'), findsOneWidget);
    expect(noDialogo(find.text('Sim, sair')), findsOneWidget);
    expect(noDialogo(find.text('Agora não')), findsOneWidget);
    expect(repo.saidasDaEscala, isEmpty);
  });

  testWidgets('P32: confirmar sai da escala com o id da missa e recarrega', (
    t,
  ) async {
    repo.escala = [item(auto: true)];
    repo.aoSairDaEscala = (id) => repo.escala = [];
    await montar(t);

    await t.tap(find.text('Sair da escala'));
    await t.pumpAndSettle();
    await t.tap(noDialogo(find.text('Sim, sair')));
    await t.pumpAndSettle();

    expect(repo.saidasDaEscala, ['m1']);
    expect(repo.cargas, 2);
    expect(find.text('Você não tem missas escaladas.'), findsOneWidget);
  });

  testWidgets('P33: Agora não na confirmação não sai de nada', (t) async {
    repo.escala = [item(auto: true)];
    await montar(t);

    await t.tap(find.text('Sair da escala'));
    await t.pumpAndSettle();
    await t.tap(noDialogo(find.text('Agora não')));
    await t.pumpAndSettle();

    expect(repo.saidasDaEscala, isEmpty);
    expect(repo.cargas, 1);
  });

  testWidgets('P34: erro de regra ao sair mostra a mensagem e mantém a missa', (
    t,
  ) async {
    repo.escala = [item(auto: true)];
    repo.erroAoSairDaEscala = const MissaJaComecou('Esta missa já começou.');
    await montar(t);

    await t.tap(find.text('Sair da escala'));
    await t.pumpAndSettle();
    await t.tap(noDialogo(find.text('Sim, sair')));
    await t.pumpAndSettle();

    expect(find.text('Esta missa já começou.'), findsOneWidget);
    expect(find.text('dom 22/11 às 18:00'), findsOneWidget);
    expect(repo.cargas, 1);
  });

  testWidgets('P35: [guarda] se só a recarga falhar, mostra a falha de carga', (
    t,
  ) async {
    repo.escala = [item(id: 'e1')];
    repo.aoConfirmar = (_) => repo.erroAoCarregar = Exception('sem sinal');
    await montar(t);

    await t.tap(find.text('Confirmar presença'));
    await t.pumpAndSettle();

    expect(repo.confirmacoes, ['e1']); // confirmou, uma única vez
    expect(
      find.text('Não foi possível carregar a sua escala.'),
      findsOneWidget,
    );
    expect(find.text('Algo deu errado. Tente de novo.'), findsNothing);
  });

  // ---------- área do administrador ----------

  testWidgets('P24: o administrador vê o botão Administração', (t) async {
    await montar(t, administrador: true);

    expect(find.text('Administração'), findsOneWidget);
  });

  testWidgets('P25: quem não é administrador não vê o botão', (t) async {
    await montar(t);

    expect(find.text('Administração'), findsNothing);
  });

  testWidgets('P26: o botão Administração abre a área de administração', (
    t,
  ) async {
    await montar(t, administrador: true);

    await t.tap(find.text('Administração'));
    await t.pumpAndSettle();

    expect(find.text('Convites'), findsOneWidget);
  });

  testWidgets(
    'P21: erro ao cancelar o pedido mostra a mensagem e mantém o botão',
    (t) async {
      repo.escala = [item(troca: true)];
      repo.erroAoCancelarTroca = const TrocaJaResolvida(
        'Esta troca não está mais aberta.',
      );
      await montar(t);

      await t.tap(find.text('Cancelar pedido de troca'));
      await t.pumpAndSettle();

      expect(find.text('Esta troca não está mais aberta.'), findsOneWidget);
      expect(find.text('Cancelar pedido de troca'), findsOneWidget);
    },
  );
}
