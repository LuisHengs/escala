import 'package:escala_core/escala_core.dart';
import 'package:test/test.dart';

void main() {
  const admin = Coroinha(id: 'adm', nome: 'Coordenador', papel: Papel.admin);
  const ana = Coroinha(id: 'ana', nome: 'Ana', papel: Papel.coroinha);

  // Missa base: domingo 18:00. Outras são derivadas dela.
  final base = DateTime(2026, 11, 22, 18, 0);
  Missa missaEm(DateTime inicio, String id) => Missa(id: id, inicio: inicio);
  final m1800 = missaEm(base, 'm1800');
  final m1830 = missaEm(base.add(const Duration(minutes: 30)), 'm1830');
  final m1900 = missaEm(base.add(const Duration(hours: 1)), 'm1900');

  late EscalaService service;
  setUp(() => service = EscalaService());

  Escalacao escalarComo(String coroinhaId, Missa missa,
          [String funcao = 'turiferário']) =>
      service.escalar(
        ator: admin,
        missa: missa,
        coroinhaId: coroinhaId,
        funcao: funcao,
      );

  group('Escalar (admin)', () {
    test('1. escala coroinha livre', () {
      final e = escalarComo('ana', m1800);
      expect(e.coroinhaId, 'ana');
      expect(e.missa.id, 'm1800');
    });

    test(
        '2. bloqueia missa com início a menos de 1h de outra do mesmo coroinha',
        () {
      escalarComo('ana', m1800);
      expect(
          () => escalarComo('ana', m1830), throwsA(isA<ConflitoDeHorario>()));
    });

    test('2b. [borda] diferença de exatamente 1h NÃO conflita', () {
      escalarComo('ana', m1800);
      expect(() => escalarComo('ana', m1900), returnsNormally);
    });

    test('3. bloqueia escalar o mesmo coroinha duas vezes na mesma missa', () {
      escalarComo('ana', m1800);
      expect(() => escalarComo('ana', m1800, 'cruciferário'),
          throwsA(isA<JaEscaladoNaMissa>()));
    });

    test('12a. coroinha comum não pode escalar', () {
      expect(
        () => service.escalar(
          ator: ana,
          missa: m1800,
          coroinhaId: 'ana',
          funcao: 'turiferário',
        ),
        throwsA(isA<PermissaoNegada>()),
      );
    });
  });

  group('Presença', () {
    test('4. nasce pendente; confirmar no prazo muda para confirmado', () {
      final e = escalarComo('ana', m1800);
      expect(e.status, StatusPresenca.pendente);

      final agora =
          base.subtract(const Duration(hours: 5)); // bem antes do prazo
      final confirmada = service.confirmar(
        escalacaoId: e.id,
        coroinhaId: 'ana',
        agora: agora,
      );
      expect(confirmada.status, StatusPresenca.confirmado);
      expect(confirmada.confirmadoComAtraso, isFalse);
    });

    test(
        '5. confirmar depois do prazo (2h antes) é permitido, mas marca atraso',
        () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 1)); // prazo era 16:00
      final confirmada = service.confirmar(
        escalacaoId: e.id,
        coroinhaId: 'ana',
        agora: agora,
      );
      expect(confirmada.status, StatusPresenca.confirmado);
      expect(confirmada.confirmadoComAtraso, isTrue);
    });

    test(
        '6. lista como "pendente em atraso" só quem está pendente dentro de 2h',
        () {
      final pendenteCedo = escalarComo('ana', m1800);
      final pendenteTarde = escalarComo('bia', m1900);
      final confirmado = escalarComo('carlos', m1830);
      service.confirmar(
        escalacaoId: confirmado.id,
        coroinhaId: 'carlos',
        agora: base.subtract(const Duration(hours: 5)),
      );

      // 15:30: m1800 começa em 2h30 e m1900 em 3h30 -> ainda fora do prazo.
      final fora = service.pendentesEmAtraso(DateTime(2026, 11, 22, 15, 30));
      expect(fora, isEmpty);

      // 17:00: m1800 em 1h (dentro); m1900 em exatamente 2h (borda: conta como
      // dentro); m1830 não aparece porque está confirmado.
      final dentro = service.pendentesEmAtraso(DateTime(2026, 11, 22, 17, 0));
      expect(dentro.map((e) => e.id),
          containsAll([pendenteCedo.id, pendenteTarde.id]));
      expect(dentro.map((e) => e.id), isNot(contains(confirmado.id)));
    });

    test(
        '7b. confirmar de novo NÃO recalcula: quem confirmou no prazo continua sem atraso',
        () {
      final e = escalarComo('ana', m1800);
      service.confirmar(
        escalacaoId: e.id,
        coroinhaId: 'ana',
        agora: base.subtract(const Duration(hours: 5)), // no prazo
      );

      // Segundo clique, já dentro das 2h: o relógio andou, mas a presença
      // foi dada no prazo e assim deve ficar (mesma regra do banco).
      final deNovo = service.confirmar(
        escalacaoId: e.id,
        coroinhaId: 'ana',
        agora: base.subtract(const Duration(hours: 1)),
      );
      expect(deNovo.status, StatusPresenca.confirmado);
      expect(deNovo.confirmadoComAtraso, isFalse);
    });

    test('7c. confirmar de novo mantém o atraso de quem confirmou atrasado',
        () {
      final e = escalarComo('ana', m1800);
      service.confirmar(
        escalacaoId: e.id,
        coroinhaId: 'ana',
        agora: base.subtract(const Duration(hours: 1)), // com atraso
      );

      final deNovo = service.confirmar(
        escalacaoId: e.id,
        coroinhaId: 'ana',
        agora: base.subtract(const Duration(hours: 5)), // relógio "voltou"
      );
      expect(deNovo.confirmadoComAtraso, isTrue);
    });

    test('7d. [guarda] confirmar de novo continua exigindo ser o titular', () {
      final e = escalarComo('ana', m1800);
      service.confirmar(
        escalacaoId: e.id,
        coroinhaId: 'ana',
        agora: base.subtract(const Duration(hours: 5)),
      );
      expect(
        () => service.confirmar(
          escalacaoId: e.id,
          coroinhaId: 'bia',
          agora: base.subtract(const Duration(hours: 1)),
        ),
        throwsA(isA<PermissaoNegada>()),
      );
    });
  });

  group('Troca', () {
    test('7. só o titular abre troca da própria escalação', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));

      expect(
        () => service.abrirTroca(
            coroinhaId: 'bia', escalacaoId: e.id, agora: agora),
        throwsA(isA<PermissaoNegada>()),
      );

      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);
      expect(troca.status, StatusTroca.aberta);
    });

    test('8. não abre troca de missa que já começou', () {
      final e = escalarComo('ana', m1800);
      final depoisDoInicio = base.add(const Duration(minutes: 5));
      expect(
        () => service.abrirTroca(
            coroinhaId: 'ana', escalacaoId: e.id, agora: depoisDoInicio),
        throwsA(isA<MissaJaComecou>()),
      );
    });

    test('9. substituto com conflito de horário não pode aceitar', () {
      final eAna = escalarComo('ana', m1800);
      escalarComo('bia', m1830); // bia já ocupada, conflita com 18:00
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: eAna.id, agora: agora);

      expect(
        () => service.aceitarTroca(
            trocaId: troca.id, substitutoId: 'bia', agora: agora),
        throwsA(isA<ConflitoDeHorario>()),
      );
    });

    test('10. aceitar transfere a escalação e o novo titular entra confirmado',
        () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      final aceita = service.aceitarTroca(
          trocaId: troca.id, substitutoId: 'carlos', agora: agora);

      expect(aceita.status, StatusTroca.aceita);
      expect(aceita.substitutoId, 'carlos');
      expect(e.coroinhaId, 'carlos');
      expect(e.status, StatusPresenca.confirmado);
    });

    test('11. dois aceites: só o primeiro vale', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      service.aceitarTroca(
          trocaId: troca.id, substitutoId: 'bia', agora: agora);

      expect(
        () => service.aceitarTroca(
            trocaId: troca.id, substitutoId: 'carlos', agora: agora),
        throwsA(isA<TrocaJaResolvida>()),
      );
      expect(e.coroinhaId, 'bia');
    });

    test('13. [borda] o titular não pode aceitar a própria troca', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      expect(
        () => service.aceitarTroca(
            trocaId: troca.id, substitutoId: 'ana', agora: agora),
        throwsA(isA<SubstitutoInvalido>()),
      );
    });

    test('14. não aceita troca de missa que já começou', () {
      final e = escalarComo('ana', m1800);
      final antes = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: antes);

      final depoisDoInicio = base.add(const Duration(minutes: 5));
      expect(
        () => service.aceitarTroca(
            trocaId: troca.id, substitutoId: 'bia', agora: depoisDoInicio),
        throwsA(isA<MissaJaComecou>()),
      );
      // Nada pode ter mudado.
      expect(e.coroinhaId, 'ana');
      expect(troca.status, StatusTroca.aberta);
    });

    test('15. não permite duas trocas abertas para a mesma escalação', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      service.abrirTroca(coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      expect(
        () => service.abrirTroca(
            coroinhaId: 'ana', escalacaoId: e.id, agora: agora),
        throwsA(isA<TrocaJaAberta>()),
      );
    });

    test(
        '15b. [guarda] depois que a troca é aceita, o novo titular pode abrir outra',
        () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final primeira = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);
      service.aceitarTroca(
          trocaId: primeira.id, substitutoId: 'bia', agora: agora);

      // Agora a titular é a bia, e a primeira troca já está resolvida.
      final segunda = service.abrirTroca(
          coroinhaId: 'bia', escalacaoId: e.id, agora: agora);
      expect(segunda.status, StatusTroca.aberta);
    });

    test('16. o titular cancela a própria troca aberta', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      final cancelada =
          service.cancelarTroca(trocaId: troca.id, coroinhaId: 'ana');

      expect(cancelada.status, StatusTroca.cancelada);
      expect(e.coroinhaId, 'ana'); // a escalação não muda
    });

    test('17. só o titular cancela a troca', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      expect(
        () => service.cancelarTroca(trocaId: troca.id, coroinhaId: 'bia'),
        throwsA(isA<PermissaoNegada>()),
      );
      expect(troca.status, StatusTroca.aberta);
    });

    test('18. não cancela troca que já foi aceita', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);
      service.aceitarTroca(
          trocaId: troca.id, substitutoId: 'bia', agora: agora);

      // A bia é a titular agora: tem permissão, mas a troca já foi resolvida.
      expect(
        () => service.cancelarTroca(trocaId: troca.id, coroinhaId: 'bia'),
        throwsA(isA<TrocaJaResolvida>()),
      );
      expect(e.coroinhaId, 'bia');
      expect(troca.status, StatusTroca.aceita);
    });

    test('19. troca cancelada não pode mais ser aceita', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);
      service.cancelarTroca(trocaId: troca.id, coroinhaId: 'ana');

      expect(
        () => service.aceitarTroca(
            trocaId: troca.id, substitutoId: 'bia', agora: agora),
        throwsA(isA<TrocaJaResolvida>()),
      );
      expect(e.coroinhaId, 'ana'); // continua com a titular original
    });

    test('20. depois de cancelar, o titular pode abrir uma nova troca', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final primeira = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);
      service.cancelarTroca(trocaId: primeira.id, coroinhaId: 'ana');

      final segunda = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);
      expect(segunda.status, StatusTroca.aberta);
      expect(segunda.id, isNot(primeira.id));
    });

    test('21. o admin cancela a troca aberta de outra pessoa', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      final cancelada =
          service.cancelarTrocaComoAdmin(ator: admin, trocaId: troca.id);

      expect(cancelada.status, StatusTroca.cancelada);
      expect(e.coroinhaId, 'ana'); // a escalação não muda
    });

    test('22. coroinha comum não usa o cancelamento de admin', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);

      // Mesmo sendo a titular, a ana não pode usar o caminho do admin.
      expect(
        () => service.cancelarTrocaComoAdmin(ator: ana, trocaId: troca.id),
        throwsA(isA<PermissaoNegada>()),
      );
      expect(troca.status, StatusTroca.aberta);
    });

    test('23. o admin também não cancela troca já aceita', () {
      final e = escalarComo('ana', m1800);
      final agora = base.subtract(const Duration(hours: 5));
      final troca = service.abrirTroca(
          coroinhaId: 'ana', escalacaoId: e.id, agora: agora);
      service.aceitarTroca(
          trocaId: troca.id, substitutoId: 'bia', agora: agora);

      expect(
        () => service.cancelarTrocaComoAdmin(ator: admin, trocaId: troca.id),
        throwsA(isA<TrocaJaResolvida>()),
      );
      expect(e.coroinhaId, 'bia');
      expect(troca.status, StatusTroca.aceita);
    });
  });

  group('Convite (admin)', () {
    test('12b. só o admin gera convite', () {
      expect(() => service.gerarConvite(ator: ana),
          throwsA(isA<PermissaoNegada>()));

      final convite = service.gerarConvite(ator: admin);
      expect(convite.codigo, isNotEmpty);
    });

    test('12c. o padrão é EXIGIR o responsável (erro cai do lado que protege)',
        () {
      final convite = service.gerarConvite(ator: admin);
      expect(convite.exigeResponsavel, isTrue);
    });

    test(
        '12d. o admin pode gerar um convite que dispensa o responsável (adulto)',
        () {
      final convite =
          service.gerarConvite(ator: admin, exigeResponsavel: false);
      expect(convite.exigeResponsavel, isFalse);
      expect(convite.codigo, isNotEmpty);
    });

    test(
        '12e. [guarda] coroinha comum não gera convite, nem dispensando o responsável',
        () {
      expect(
        () => service.gerarConvite(ator: ana, exigeResponsavel: false),
        throwsA(isA<PermissaoNegada>()),
      );
    });
  });

  group('Ids inexistentes', () {
    final agora = base.subtract(const Duration(hours: 5));

    test('24. confirmar escalação inexistente', () {
      expect(
        () => service.confirmar(
            escalacaoId: 'nao-existe', coroinhaId: 'ana', agora: agora),
        throwsA(isA<EscalacaoNaoEncontrada>()),
      );
    });

    test('25. abrir troca de escalação inexistente', () {
      expect(
        () => service.abrirTroca(
            coroinhaId: 'ana', escalacaoId: 'nao-existe', agora: agora),
        throwsA(isA<EscalacaoNaoEncontrada>()),
      );
    });

    test('26. aceitar troca inexistente', () {
      expect(
        () => service.aceitarTroca(
            trocaId: 'nao-existe', substitutoId: 'bia', agora: agora),
        throwsA(isA<TrocaNaoEncontrada>()),
      );
    });

    test('27. cancelar troca inexistente (titular)', () {
      expect(
        () => service.cancelarTroca(trocaId: 'nao-existe', coroinhaId: 'ana'),
        throwsA(isA<TrocaNaoEncontrada>()),
      );
    });

    test('27b. cancelar troca inexistente (admin)', () {
      expect(
        () =>
            service.cancelarTrocaComoAdmin(ator: admin, trocaId: 'nao-existe'),
        throwsA(isA<TrocaNaoEncontrada>()),
      );
    });
  });
}
