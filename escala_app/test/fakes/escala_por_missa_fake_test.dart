import 'package:escala_app/data/coroinha.dart';
import 'package:escala_app/data/escalado_na_missa.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_escala_repository.dart';

void main() {
  late FakeEscalaRepository repositorio;

  setUp(() => repositorio = FakeEscalaRepository());
  tearDown(() => repositorio.fechar());

  test('FA1: lista coroinhas ativos configurados no fake', () async {
    repositorio.coroinhasCadastrados = [const Coroinha(id: 'c1', nome: 'Ana')];

    final resultado = await repositorio.coroinhas();

    expect(resultado.single.nome, 'Ana');
    expect(repositorio.cargasCoroinhas, 1);
  });

  test('FA2: lista escalações da missa informada', () async {
    repositorio.escaladosPorMissa['m1'] = [
      const EscaladoNaMissa(
        id: 'e1',
        coroinhaId: 'c1',
        nome: 'Ana',
        funcao: 'turiferário',
      ),
    ];

    final resultado = await repositorio.escaladosDaMissa('m1');

    expect(resultado.single.id, 'e1');
    expect(repositorio.cargasEscaladosPorMissa['m1'], 1);
  });

  test('FA3: registra uma escalação', () async {
    await repositorio.escalar(
      missaId: 'm1',
      coroinhaId: 'c1',
      funcao: 'turiferário',
    );

    expect(repositorio.escalacoesCriadas.single, (
      missaId: 'm1',
      coroinhaId: 'c1',
      funcao: 'turiferário',
    ));
  });

  test('FA4: registra a retirada de uma escalação', () async {
    await repositorio.desescalar('e1');

    expect(repositorio.escalacoesRemovidas, ['e1']);
  });

  test('FA5: propaga erro ao escalar sem registrar sucesso', () async {
    repositorio.erroAoEscalar = StateError('falha');

    await expectLater(
      repositorio.escalar(
        missaId: 'm1',
        coroinhaId: 'c1',
        funcao: 'turiferário',
      ),
      throwsStateError,
    );
    expect(repositorio.escalacoesCriadas, isEmpty);
  });
}
