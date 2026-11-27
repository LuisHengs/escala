import 'dart:io';

import 'package:escala_core/escala_core.dart';
import 'package:test/test.dart';

void main() {
  // Cada código que o banco devolve e o tipo de exceção que ele deve virar.
  final casos = <String, Matcher>{
    // Escala e trocas (já existiam no dominio.dart)
    'NAO_AUTORIZADO': isA<PermissaoNegada>(),
    'CONFLITO_DE_HORARIO': isA<ConflitoDeHorario>(),
    'JA_ESCALADO_NA_MISSA': isA<JaEscaladoNaMissa>(),
    'MISSA_JA_COMECOU': isA<MissaJaComecou>(),
    'TROCA_JA_RESOLVIDA': isA<TrocaJaResolvida>(),
    'SUBSTITUTO_INVALIDO': isA<SubstitutoInvalido>(),
    'TROCA_JA_ABERTA': isA<TrocaJaAberta>(),
    'ESCALACAO_NAO_ENCONTRADA': isA<EscalacaoNaoEncontrada>(),
    'TROCA_NAO_ENCONTRADA': isA<TrocaNaoEncontrada>(),
    // Validações ao escalar
    'COROINHA_INEXISTENTE': isA<CoroinhaInexistente>(),
    'COROINHA_INATIVO': isA<CoroinhaInativo>(),
    'MISSA_INEXISTENTE': isA<MissaInexistente>(),
    // Convites
    'CONVITE_INVALIDO': isA<ConviteInvalido>(),
    'CONVITE_USADO': isA<ConviteUsado>(),
    'CONVITE_EXPIRADO': isA<ConviteExpirado>(),
    'JA_TEM_PERFIL': isA<JaTemPerfil>(),
    'NOME_INVALIDO': isA<NomeInvalido>(),
    'RESPONSAVEL_OBRIGATORIO': isA<ResponsavelObrigatorio>(),
    // Cadastro de locais e missas
    'LOCAL_DUPLICADO': isA<LocalDuplicado>(),
    'HORARIO_INVALIDO': isA<HorarioInvalido>(),
    'HORARIO_NO_PASSADO': isA<HorarioNoPassado>(),
    'LOCAL_EM_USO': isA<LocalEmUso>(),
    'LOCAL_INEXISTENTE': isA<LocalInexistente>(),
    // Gestão de membros e da escala
    'VALOR_INVALIDO': isA<ValorInvalido>(),
    'PERFIL_INEXISTENTE': isA<PerfilInexistente>(),
    'PAPEL_INVALIDO': isA<PapelInvalido>(),
    'TEM_ESCALACOES_FUTURAS': isA<TemEscalacoesFuturas>(),
    'MISSA_COM_ESCALADOS': isA<MissaComEscalados>(),
    'ULTIMO_ADMIN': isA<UltimoAdmin>(),
    // Escala livre
    'ESCALA_NAO_LIVRE': isA<EscalaNaoLivre>(),
    'SAIDA_NAO_PERMITIDA': isA<SaidaNaoPermitida>(),
  };

  group('traduzirErroDoBanco: cada código vira a exceção certa', () {
    casos.forEach((codigo, tipo) {
      test(codigo, () => expect(traduzirErroDoBanco(codigo), tipo));
    });
  });

  group('traduzirErroDoBanco: robustez', () {
    test('ignora espaços nas pontas do código', () {
      expect(
          traduzirErroDoBanco('  NAO_AUTORIZADO \n'), isA<PermissaoNegada>());
    });

    test('código desconhecido vira ErroDesconhecido e guarda o código original',
        () {
      expect(
        traduzirErroDoBanco('ALGO_QUE_NINGUEM_PREVIU'),
        isA<ErroDesconhecido>()
            .having((e) => e.codigo, 'codigo', 'ALGO_QUE_NINGUEM_PREVIU'),
      );
    });

    test('texto vazio vira ErroDesconhecido (nunca estoura)', () {
      expect(traduzirErroDoBanco(''), isA<ErroDesconhecido>());
    });

    test(
        'erro técnico do Postgres vira ErroDesconhecido, sem exibir o texto cru',
        () {
      final erro = traduzirErroDoBanco(
          'new row violates row-level security policy for table "escalacoes"');
      expect(erro, isA<ErroDesconhecido>());
    });
  });

  // Teste de CONTRATO: lê as migrations do banco e confere que todo código
  // levantado lá ("raise exception 'ALGUM_CODIGO'") tem tradução aqui.
  // Quando uma migration nova criar um código novo, este teste falha e
  // lembra de atualizar o Dart.
  final pasta = Directory('../supabase/migrations');
  group('contrato com o banco', () {
    test('todo código levantado nas migrations tem tradução', () {
      final regex = RegExp(r"raise exception\s+'([A-Z][A-Z_]+)'");
      final codigos = <String>{};
      for (final arquivo in pasta
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.sql'))) {
        for (final m in regex.allMatches(arquivo.readAsStringSync())) {
          codigos.add(m.group(1)!);
        }
      }

      expect(codigos, isNotEmpty,
          reason: 'Nenhum código encontrado: a pasta está certa?');
      final semTraducao = codigos
          .where((c) => traduzirErroDoBanco(c) is ErroDesconhecido)
          .toList()
        ..sort();
      expect(semTraducao, isEmpty,
          reason: 'Códigos do banco SEM tradução no Dart: $semTraducao');
    },
        skip: pasta.existsSync()
            ? false
            : 'Pasta ../supabase/migrations não encontrada ao lado do pacote');
  });
}
